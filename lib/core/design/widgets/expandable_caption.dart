import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// Collapses long captions to [trimLines] and keeps `… show more` on that
/// same last line (never wrapped underneath).
class ExpandableCaption extends StatefulWidget {
  const ExpandableCaption({
    super.key,
    required this.text,
    this.trimLines = 3,
    this.style,
    this.linkStyle,
  });

  final String text;
  final int trimLines;
  final TextStyle? style;
  final TextStyle? linkStyle;

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  // Non-breaking spaces so the control never splits across lines.
  static const _moreSuffix = '…\u00A0show\u00A0more';
  static const _lessSuffix = '\u00A0show\u00A0less';

  bool _expanded = false;
  late final TapGestureRecognizer _moreRecognizer;
  late final TapGestureRecognizer _lessRecognizer;

  @override
  void initState() {
    super.initState();
    _moreRecognizer = TapGestureRecognizer()
      ..onTap = () => setState(() => _expanded = true);
    _lessRecognizer = TapGestureRecognizer()
      ..onTap = () => setState(() => _expanded = false);
  }

  @override
  void didUpdateWidget(covariant ExpandableCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  @override
  void dispose() {
    _moreRecognizer.dispose();
    _lessRecognizer.dispose();
    super.dispose();
  }

  TextStyle _bodyStyle() =>
      widget.style ?? AppTextStyles.body(15, height: 1.4);

  TextStyle _actionStyle() =>
      widget.linkStyle ??
      AppTextStyles.body(
        15,
        color: AppColors.primary,
        weight: FontWeight.w800,
        height: 1.4,
      );

  TextPainter _layout({
    required InlineSpan span,
    required double maxWidth,
    required BuildContext context,
    int? maxLines,
  }) {
    return TextPainter(
      text: span,
      maxLines: maxLines,
      textDirection: Directionality.of(context),
      textAlign: TextAlign.start,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: maxWidth);
  }

  bool _overflows({
    required String prefix,
    required double maxWidth,
    required BuildContext context,
  }) {
    final painter = _layout(
      span: TextSpan(
        style: _bodyStyle(),
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          TextSpan(text: _moreSuffix, style: _actionStyle()),
        ],
      ),
      maxWidth: maxWidth,
      context: context,
      maxLines: widget.trimLines,
    );
    return painter.didExceedMaxLines;
  }

  /// Binary-search the longest prefix that still leaves room for the
  /// unbreakable `… show more` inside [trimLines].
  String _collapsedPrefix({
    required String text,
    required double maxWidth,
    required BuildContext context,
  }) {
    var low = 0;
    var high = text.length;
    var best = '';

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = text.substring(0, mid).trimRight();
      if (!_overflows(
        prefix: candidate,
        maxWidth: maxWidth,
        context: context,
      )) {
        best = candidate;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (best.isEmpty) return best;

    // Prefer ending on a word boundary when possible.
    final space = best.lastIndexOf(RegExp(r'\s'));
    if (space > best.length ~/ 4) {
      final wordCut = best.substring(0, space).trimRight();
      if (wordCut.isNotEmpty &&
          !_overflows(
            prefix: wordCut,
            maxWidth: maxWidth,
            context: context,
          )) {
        return wordCut;
      }
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final body = _bodyStyle();
    final action = _actionStyle();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || !maxWidth.isFinite) {
          return Text(text, style: body);
        }

        final exceeds = _layout(
          span: TextSpan(text: text, style: body),
          maxWidth: maxWidth,
          context: context,
          maxLines: widget.trimLines,
        ).didExceedMaxLines;

        if (!exceeds) {
          return Text(text, style: body);
        }

        if (_expanded) {
          return Text.rich(
            TextSpan(
              style: body,
              children: [
                TextSpan(text: text),
                TextSpan(
                  text: _lessSuffix,
                  style: action,
                  recognizer: _lessRecognizer,
                ),
              ],
            ),
          );
        }

        final prefix = _collapsedPrefix(
          text: text,
          maxWidth: maxWidth,
          context: context,
        );

        // Always one Text.rich — never a Column (that put "show more" below).
        return Text.rich(
          TextSpan(
            style: body,
            children: [
              if (prefix.isNotEmpty) TextSpan(text: prefix),
              TextSpan(
                text: _moreSuffix,
                style: action,
                recognizer: _moreRecognizer,
              ),
            ],
          ),
        );
      },
    );
  }
}
