import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'core/background_tasks/notification_syncer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    });
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return const BeTherApp();
  }
}
