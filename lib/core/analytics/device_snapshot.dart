import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.platform,
    required this.model,
    required this.os,
    required this.appVersion,
    required this.appBuild,
    required this.deviceId,
  });

  final String platform;
  final String model;
  final String os;
  final String appVersion;
  final String appBuild;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'model': model,
        'os': os,
        'appVersion': appVersion,
        'appBuild': appBuild,
        'deviceId': deviceId,
      };
}

Future<DeviceSnapshot> collectDeviceSnapshot() async {
  final pkg = await PackageInfo.fromPlatform();
  final plugin = DeviceInfoPlugin();
  var model = '';
  var os = '';
  var platform = defaultTargetPlatform.name.toLowerCase();
  var deviceId = '';

  if (kIsWeb) {
    platform = 'web';
    final web = await plugin.webBrowserInfo;
    model = web.browserName.name;
    os = web.platform ?? '';
  } else if (Platform.isAndroid) {
    platform = 'android';
    final info = await plugin.androidInfo;
    model = '${info.brand} ${info.model}'.trim();
    os = info.version.release;
    deviceId = info.id;
  } else if (Platform.isIOS) {
    platform = 'ios';
    final info = await plugin.iosInfo;
    model = info.utsname.machine;
    os = info.systemVersion;
    deviceId = info.identifierForVendor ?? '';
  }

  final snap = DeviceSnapshot(
    platform: platform,
    model: model,
    os: os,
    appVersion: pkg.version,
    appBuild: pkg.buildNumber,
    deviceId: deviceId,
  );
  return snap;
}
