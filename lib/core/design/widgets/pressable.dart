import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any child with press-down scale + optional shadow squish + haptic.
/// ponytail: one widget for all "feels stamped" interactions.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.haptic = false,
    this.scale = 0.97,
    this.shadowNormal,
    this.shadowPressed,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool haptic;
  final double scale;
  final List<BoxShadow>? shadowNormal;
  final List<BoxShadow>? shadowPressed;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 120);
  static const _curve = Curves.easeOutCubic;

  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _duration);
    _scaleAnim = Tween(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: _curve),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && widget.onTap != null;

  void _onDown(TapDownDetails _) {
    if (!_active) return;
    _ctrl.forward();
  }

  void _onUp(TapUpDetails _) => _ctrl.reverse();
  void _onCancel() => _ctrl.reverse();

  void _onTap() {
    if (!_active) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final noMotion = MediaQuery.disableAnimationsOf(context);
    if (noMotion || !_active) {
      return GestureDetector(
        onTap: _active ? _onTap : null,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _onCancel,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          final pressed = _ctrl.value > 0;
          return Transform.scale(
            scale: _scaleAnim.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: pressed
                    ? (widget.shadowPressed ?? widget.shadowNormal)
                    : widget.shadowNormal,
              ),
              position: DecorationPosition.background,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
