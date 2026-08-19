import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';

enum _ReportReason { spam, harassment, impersonation, other }

Future<void> showProfileActionsSheet({
  required BuildContext context,
  required String username,
  required bool isFollowedBy,
  required bool isBlocked,
  required Future<void> Function() onRemoveFollower,
  required Future<void> Function() onBlock,
  required Future<void> Function() onUnblock,
  required Future<void> Function(String reason, String details) onReport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: AppColors.secondary.withValues(alpha: 0.5),
    builder: (ctx) => _ProfileActionsSheet(
      username: username,
      isFollowedBy: isFollowedBy,
      isBlocked: isBlocked,
      onRemoveFollower: onRemoveFollower,
      onBlock: onBlock,
      onUnblock: onUnblock,
      onReport: onReport,
    ),
  );
}

class _ProfileActionsSheet extends StatelessWidget {
  const _ProfileActionsSheet({
    required this.username,
    required this.isFollowedBy,
    required this.isBlocked,
    required this.onRemoveFollower,
    required this.onBlock,
    required this.onUnblock,
    required this.onReport,
  });

  final String username;
  final bool isFollowedBy;
  final bool isBlocked;
  final Future<void> Function() onRemoveFollower;
  final Future<void> Function() onBlock;
  final Future<void> Function() onUnblock;
  final Future<void> Function(String reason, String details) onReport;

  String get _label => username.isNotEmpty ? '@$username' : 'this account';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: AppColors.card,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: AppDimens.borderThick),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedForeground.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (isFollowedBy && !isBlocked)
                _ActionRow(
                  icon: Icons.person_remove_outlined,
                  title: 'Remove follower',
                  subtitle: 'They will no longer follow you. They can follow you again later.',
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await _confirm(
                      context,
                      title: 'REMOVE FOLLOWER?',
                      body: 'Remove $_label from your followers?',
                      confirm: 'REMOVE',
                    );
                    if (ok) await onRemoveFollower();
                  },
                ),
              if (isBlocked)
                _ActionRow(
                  icon: Icons.lock_open_outlined,
                  title: 'Unblock',
                  subtitle: 'They can see your public events again and may follow you.',
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await _confirm(
                      context,
                      title: 'UNBLOCK?',
                      body: 'Unblock $_label?',
                      confirm: 'UNBLOCK',
                    );
                    if (ok) await onUnblock();
                  },
                )
              else
                _ActionRow(
                  icon: Icons.block,
                  title: 'Block',
                  subtitle:
                      'Unfollow them if you follow them. Their events leave your feed, explore, and search.',
                  destructive: true,
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await _confirm(
                      context,
                      title: 'BLOCK $_label?',
                      body:
                          'You will unfollow them. Their events will no longer appear in feed, explore, or search.',
                      confirm: 'BLOCK',
                      destructive: true,
                    );
                    if (ok) await onBlock();
                  },
                ),
              _ActionRow(
                icon: Icons.flag_outlined,
                title: 'Report',
                subtitle: 'Send a reason to the team. Serious cases can lead to a restriction.',
                destructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  await _reportFlow(context, onReport);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.secondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body(16, weight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.body(13, color: AppColors.mutedForeground, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(title, style: AppTextStyles.display(22, color: AppColors.secondary)),
      content: Text(body, style: AppTextStyles.body(15)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.destructive)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> _reportFlow(
  BuildContext context,
  Future<void> Function(String reason, String details) onReport,
) async {
  final result = await showDialog<({String reason, String details})>(
    context: context,
    builder: (ctx) => const _ReportUserDialog(),
  );
  if (result == null || !context.mounted) return;
  await onReport(result.reason, result.details);
}

class _ReportUserDialog extends StatefulWidget {
  const _ReportUserDialog();

  @override
  State<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<_ReportUserDialog> {
  _ReportReason _reason = _ReportReason.spam;
  late final TextEditingController _details;

  @override
  void initState() {
    super.initState();
    _details = TextEditingController();
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String get _apiReason => switch (_reason) {
        _ReportReason.spam => 'spam',
        _ReportReason.harassment => 'harassment',
        _ReportReason.impersonation => 'impersonation',
        _ReportReason.other => 'other',
      };

  void _submit() {
    final text = _details.text.trim();
    if (_reason == _ReportReason.other && text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue (at least 3 characters)')),
      );
      return;
    }
    Navigator.pop(context, (reason: _apiReason, details: text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border, width: AppDimens.borderThick),
        borderRadius: BorderRadius.zero,
      ),
      title: Text('REPORT ACCOUNT', style: AppTextStyles.display(22, color: AppColors.secondary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The team reviews reports. Repeat or serious cases can lead to a restriction.',
              style: AppTextStyles.body(14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            for (final option in _ReportReason.values)
              InkWell(
                onTap: () => setState(() => _reason = option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _reason == option
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _reason == option
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          switch (option) {
                            _ReportReason.spam => 'Spam or fake events',
                            _ReportReason.harassment => 'Harassment or hate',
                            _ReportReason.impersonation => 'Pretending to be someone else',
                            _ReportReason.other => 'Something else',
                          },
                          style: AppTextStyles.body(14, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: _reason == _ReportReason.other
                    ? 'Describe what happened'
                    : 'Add details (optional)',
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: _submit,
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }
}
