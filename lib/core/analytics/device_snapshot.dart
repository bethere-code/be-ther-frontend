import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceLocation {
  const DeviceLocation({
    required this.lat,
    required this.lng,
    this.accuracyM,
  });

  final double lat;
  final double lng;
  final double? accuracyM;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracyM': accuracyM,
      };
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.platform,
    required this.model,
    required this.os,
    required this.appVersion,
    required this.appBuild,
    required this.deviceId,
    this.location,
  });

  final String platform;
  final String model;
  final String os;
  final String appVersion;
  final String appBuild;
  final String deviceId;
  final DeviceLocation? location;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'model': model,
        'os': os,
        'appVersion': appVersion,
        'appBuild': appBuild,
        'deviceId': deviceId,
        if (location != null) 'location': location!.toJson(),
      };
}

/// Reads GPS only if the OS already granted location — never prompts.
Future<DeviceLocation?> readLocationIfAllowed() async {
  if (kIsWeb) return null;
  if (!(Platform.isAndroid || Platform.isIOS)) return null;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 3),
      ),
    );
    return DeviceLocation(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
    );
  } catch (_) {
    return null;
  }
}

/// Device/app identity. Pass [includeLocationIfAllowed] only on auth
/// (login / signup / logout) — not on routine API or analytics flushes.
Future<DeviceSnapshot> collectDeviceSnapshot({
  bool includeLocationIfAllowed = false,
}) async {
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

  DeviceLocation? location;
  if (includeLocationIfAllowed) {
    location = await readLocationIfAllowed();
  }

  return DeviceSnapshot(
    platform: platform,
    model: model,
    os: os,
    appVersion: pkg.version,
    appBuild: pkg.buildNumber,
    deviceId: deviceId,
    location: location,
  );
}
