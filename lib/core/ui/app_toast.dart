import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../design/app_colors.dart';

/// Thin wrapper over [Fluttertoast] so call sites stay `AppToast.show(...)`.
/// Works on Android and iOS without a Scaffold.
abstract final class AppToast {
  static void show(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    final text = message.trim();
    if (text.isEmpty) return;

    // [context] kept for call-site compatibility; fluttertoast does not need it.
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: text,
      toastLength: duration.inMilliseconds >= 2500
          ? Toast.LENGTH_LONG
          : Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: duration.inMilliseconds >= 2500 ? 3 : 2,
      backgroundColor: AppColors.secondary,
      textColor: AppColors.secondaryForeground,
      fontSize: 14,
    );
  }

  static void hide() {
    Fluttertoast.cancel();
  }
}
