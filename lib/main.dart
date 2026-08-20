import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'core/analytics/analytics_tracker.dart';
import 'core/background_tasks/notification_syncer.dart';
import 'core/network/connectivity_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  // debugRepaintRainbowEnabled = true;
  runApp(const ProviderScope(child: AppBootstrap()));
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize notification syncer on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationSyncerProvider).start();
      // Kick connectivity watch early (also watched by OfflineBarrier).
      ref.read(connectivityProvider);
      _syncAnalyticsTracker();
    });
  }

  void _syncAnalyticsTracker() {
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    ref.read(analyticsTrackerProvider).start(ref.read(appRouterProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop notification syncer when app terminates
    ref.read(notificationSyncerProvider).stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately sync notifications when app resumes from background
      ref.read(notificationSyncerProvider).syncNow();
      // Re-probe: OS may have restored network while we were suspended.
      ref.read(connectivityProvider.notifier).checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider.select((s) => s.isAuthenticated), (prev, next) {
      if (next == true) {
        ref.read(analyticsTrackerProvider).start(ref.read(appRouterProvider));
      }
    });
    return const BeTherApp();
  }
}
