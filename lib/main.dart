import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'core/analytics/analytics_tracker.dart';
import 'core/background_tasks/notification_syncer.dart';
import 'core/network/connectivity_controller.dart';
import 'core/push/push_service.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e, st) {
    // Hot-restart / missing native channel must not block the app.
    debugPrint('Firebase.initializeApp failed: $e\n$st');
  }

  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayLightIcons);
  await dotenv.load(fileName: 'assets/env/app.env');
  final serverClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim();
  await GoogleSignIn.instance.initialize(
    serverClientId: serverClientId == null || serverClientId.isEmpty
        ? null
        : serverClientId,
  );
  runApp(const ProviderScope(child: AppBootstrap()));
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationSyncerProvider).start();
      ref.read(connectivityProvider);
      _syncAnalyticsTracker();
      if (ref.read(authNotifierProvider).isAuthenticated) {
        unawaitedPushStart();
      }
    });
  }

  void unawaitedPushStart() {
    final push = ref.read(pushServiceProvider);
    final user = ref.read(authNotifierProvider).user;
    final id = user?['_id']?.toString() ?? user?['id']?.toString();
    push.setAnalyticsUser(id);
    push.startAfterAuth();
  }

  void _syncAnalyticsTracker() {
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    ref.read(analyticsTrackerProvider).start(ref.read(appRouterProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(notificationSyncerProvider).stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationSyncerProvider).syncNow();
      ref.read(connectivityProvider.notifier).checkNow();
      if (ref.read(authNotifierProvider).isAuthenticated) {
        ref.read(pushServiceProvider).refreshCityTopic();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider.select((s) => s.isAuthenticated), (
      prev,
      next,
    ) {
      if (next == true) {
        ref.read(analyticsTrackerProvider).start(ref.read(appRouterProvider));
        unawaitedPushStart();
      } else if (prev == true && next == false) {
        ref.read(pushServiceProvider).stopOnLogout();
      }
    });
    return const BeTherApp();
  }
}
