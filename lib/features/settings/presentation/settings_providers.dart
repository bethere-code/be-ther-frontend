import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Cached app version string for settings footer.
final appVersionProvider = FutureProvider<String>((ref) async {
  final pkg = await PackageInfo.fromPlatform();
  return 'BE THER \nv${pkg.version} (${pkg.buildNumber})';
});
