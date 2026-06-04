import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';
import '../feed_providers.dart';

enum FeedPostReportType { eventCancelled, spam, bug }

extension on FeedPostReportType {
  String get apiValue => switch (this) {
        FeedPostReportType.eventCancelled => 'event_cancelled',
        FeedPostReportType.spam => 'spam',
        FeedPostReportType.bug => 'bug',
      };
}

Future<void> handleFeedPostReport({
  required BuildContext context,
  required WidgetRef ref,
  required String postId,
  required FeedPostReportType type,
}) async {
  if (postId.isEmpty) return;

  switch (type) {
    case FeedPostReportType.eventCancelled:
      await _showOptionalDetailsDialog(
        context: context,
        title: 'EVENT CANCELLED?',
        message: 'Let others know this event may no longer be happening. You can add an optional note.',
        confirmLabel: 'SUBMIT',
        onSubmit: (details) => _submit(context, ref, postId, type, details),
      );
    case FeedPostReportType.spam:
      await _showOptionalDetailsDialog(
        context: context,
        title: 'REPORT AS SPAM?',
        message: 'Only report if this post is misleading or unwanted. Add details if helpful.',
        confirmLabel: 'REPORT SPAM',
        onSubmit: (details) => _submit(context, ref, postId, type, details),
      );
    case FeedPostReportType.bug:
      await _showBugReportDialog(context, ref, postId);
  }
}

Future<void> _submit(
  BuildContext context,
  WidgetRef ref,
  String postId,
  FeedPostReportType type,
  String details,
) async {
  try {
    await ref.read(postsRepositoryProvider).submitReport(
          postId: postId,
          type: type.apiValue,
          details: details,
        );
    if (!context.mounted) return;
    if (type == FeedPostReportType.bug) return;
    final message = switch (type) {
      FeedPostReportType.eventCancelled => 'Thanks — cancellation reported',
      FeedPostReportType.spam => 'Thanks — spam report submitted',
      FeedPostReportType.bug => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

Future<void> _showOptionalDetailsDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function(String details) onSubmit,
}) async {
  final details = await showDialog<String>(
    context: context,
    builder: (ctx) => _OptionalDetailsReportDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    ),
  );

  if (details != null && context.mounted) {
    await onSubmit(details);
  }
}

Future<void> _showBugReportDialog(
  BuildContext context,
  WidgetRef ref,
  String postId,
) async {
  final details = await showDialog<String>(
    context: context,
    builder: (ctx) => const _BugReportDialog(),
  );

  if (details == null || !context.mounted) return;

  await _submit(context, ref, postId, FeedPostReportType.bug, details);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        borderRadius: BorderRadius.zero,
      ),
      title: Text('THANK YOU', style: AppTextStyles.display(24, color: AppColors.primary)),
      content: Text(
        'Thank you for reporting this bug. Our team will review your feedback.',
        style: AppTextStyles.body(15),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _OptionalDetailsReportDialog extends StatefulWidget {
  const _OptionalDetailsReportDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_OptionalDetailsReportDialog> createState() => _OptionalDetailsReportDialogState();
}

class _OptionalDetailsReportDialogState extends State<_OptionalDetailsReportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(widget.title, style: AppTextStyles.display(22, color: AppColors.secondary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message, style: AppTextStyles.body(14, color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(color: AppColors.border, width: AppDimens.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the bug (at least 3 characters)')),
      );
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        borderRadius: BorderRadius.zero,
      ),
      title: Text('REPORT A BUG', style: AppTextStyles.display(22, color: AppColors.secondary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell us what went wrong. This field is required.',
              style: AppTextStyles.body(14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'What happened?',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(color: AppColors.border, width: AppDimens.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }
}
