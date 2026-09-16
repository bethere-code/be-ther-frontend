import 'package:flutter/material.dart';

import '../app_text_styles.dart';

/// Label with cycling dots so busy CTAs feel alive (VERIFYING. / .. / ...).
class LoadingLabel extends StatefulWidget {
  const LoadingLabel({
    super.key,
    required this.text,
    required this.style,
    this.interval = const Duration(milliseconds: 420),
  });

  final String text;
  final TextStyle style;
  final Duration interval;

  @override
  State<LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<LoadingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.interval * 3)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant LoadingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _ctrl.duration = widget.interval * 3;
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final step = (_ctrl.value * 3).floor().clamp(0, 2);
        final dots = '.' * (step + 1);
        return Text('${widget.text}$dots', style: widget.style);
      },
    );
  }
}

/// Compact bouncing dots for tight buttons (e.g. Google row).
class JumpingDots extends StatefulWidget {
  const JumpingDots({
    super.key,
    required this.color,
    this.size = 6,
  });

  final Color color;
  final double size;

  @override
  State<JumpingDots> createState() => _JumpingDotsState();
}

class _JumpingDotsState extends State<JumpingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i / 3) % 1.0;
            final t = (phase < 0.5 ? phase : 1 - phase) * 2;
            final dy = -5.5 * Curves.easeOut.transform(t);
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Google / outlined busy row: label + jumping dots.
class AuthBusyRow extends StatelessWidget {
  const AuthBusyRow({
    super.key,
    required this.label,
    this.leading,
    this.style,
  });

  final String label;
  final Widget? leading;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ??
        AppTextStyles.body(
          13,
          color: const Color(0xFF1A2332),
          weight: FontWeight.w700,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 10),
        ],
        Text(label, style: textStyle),
        const SizedBox(width: 6),
        JumpingDots(color: textStyle.color ?? const Color(0xFF1A2332)),
      ],
    );
  }
}
