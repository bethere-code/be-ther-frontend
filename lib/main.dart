import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';

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

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  @override
  Widget build(BuildContext context) {
    return const BeTherApp();
  }
}
