import 'package:flutter/material.dart';

/// Closes any open [PopupMenuButton] route without touching page routes.
///
/// Flutter's popup menu overlay does not auto-dismiss on scroll; call this from
/// scroll listeners so menus don't float over a moving list.
void dismissOpenPopupMenus(BuildContext context) {
  if (!context.mounted) return;
  final navigator = Navigator.maybeOf(context);
  if (navigator == null) return;

  navigator.popUntil((route) {
    final typeName = route.runtimeType.toString();
    final isPopupMenu = typeName.contains('PopupMenu');
    return !isPopupMenu;
  });
}
