import 'package:flutter/foundation.dart';

/// Release builds (Play AAB, App Store archive, TestFlight) always use prod —
/// `--dart-define=APP_ENV=dev` is ignored there. Debug/profile builds use the
/// dev API only when started with that define.
const bool isDevBackend =
    !kReleaseMode && String.fromEnvironment('APP_ENV') == 'dev';

const String appEnvFile =
    isDevBackend ? 'assets/env/dev.env' : 'assets/env/prod.env';
