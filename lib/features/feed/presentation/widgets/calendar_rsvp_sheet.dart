import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_dimens.dart';
import '../../../../core/design/app_text_styles.dart';

enum CalendarRsvpChoice { interested, going, none }

/// Eye-catchy RSVP picker matching BeTher chrome.
///
/// [allowRemove] false for authors — Interested ↔ Going only (no Not interested).
Future<CalendarRsvpChoice?> showCalendarRsvpSheet({
  required BuildContext context,
  required bool alreadyOnCalendar,
  String? currentStatus,
  bool allowRemove = true,
}) {
  return showModalBottomSheet<CalendarRsvpChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: AppColors.secondary.withValues(alpha: 0.5),
    builder: (ctx) => _CalendarRsvpSheet(
      alreadyOnCalendar: alreadyOnCalendar,
      currentStatus: currentStatus,
      allowRemove: allowRemove,
    ),
  );
}

class _CalendarRsvpSheet extends StatelessWidget {
  const _CalendarRsvpSheet({
    required this.alreadyOnCalendar,
    required this.allowRemove,
    this.currentStatus,
  });

  final bool alreadyOnCalendar;
  final bool allowRemove;
  final String? currentStatus;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final ownerMode = !allowRemove;
    // Already going → offer Interested (downgrade), not another Going.
    final offerInterestedInsteadOfGoing =
        allowRemove && alreadyOnCalendar && currentStatus == 'going';

    return Material(
      color: AppColors.background,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 18),
              Text(
                alreadyOnCalendar || ownerMode
                    ? 'UPDATE STATUS'
                    : 'WILL YOU BE THERE?',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(
                  26,
                  color: AppColors.secondary,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ownerMode
                    ? 'Your event stays on your calendar — pick Interested or Going'
                    : alreadyOnCalendar
                        ? 'Change how this event shows on your calendar'
                        : 'Pick how you want this event on your calendar',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  14,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 22),
              if (ownerMode)
                Row(
                  children: [
                    Expanded(
                      child: _RsvpOptionButton(
                        label: 'INTERESTED',
                        subtitle: currentStatus == 'interested'
                            ? 'Current status'
                            : 'Might check it out',
                        icon: Icons.star_outline_rounded,
                        filled: currentStatus == 'interested',
                        accent: AppColors.primary,
                        filledForeground: AppColors.primaryForeground,
                        onTap: () => Navigator.pop(
                          context,
                          CalendarRsvpChoice.interested,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RsvpOptionButton(
                        label: 'GOING',
                        subtitle: currentStatus == 'going'
                            ? 'Current status'
                            : 'Count me in',
                        icon: Icons.celebration_outlined,
                        filled: currentStatus != 'interested',
                        accent: AppColors.secondary,
                        filledForeground: AppColors.secondaryForeground,
                        onTap: () => Navigator.pop(
                          context,
                          CalendarRsvpChoice.going,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _RsvpOptionButton(
                        label: alreadyOnCalendar
                            ? 'NOT\nINTERESTED'
                            : 'INTERESTED',
                        subtitle: alreadyOnCalendar
                            ? 'Remove from calendar'
                            : 'Might check it out',
                        icon: alreadyOnCalendar
                            ? Icons.event_busy_outlined
                            : Icons.star_outline_rounded,
                        filled: false,
                        accent: alreadyOnCalendar
                            ? AppColors.destructive
                            : AppColors.secondary,
                        onTap: () => Navigator.pop(
                          context,
                          alreadyOnCalendar
                              ? CalendarRsvpChoice.none
                              : CalendarRsvpChoice.interested,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: offerInterestedInsteadOfGoing
                          ? _RsvpOptionButton(
                              label: 'INTERESTED',
                              subtitle: 'Not sure I\'m going',
                              icon: Icons.star_outline_rounded,
                              filled: true,
                              accent: AppColors.primary,
                              filledForeground: AppColors.primaryForeground,
                              onTap: () => Navigator.pop(
                                context,
                                CalendarRsvpChoice.interested,
                              ),
                            )
                          : _RsvpOptionButton(
                              label: 'GOING',
                              subtitle: 'Count me in',
                              icon: Icons.celebration_outlined,
                              filled: true,
                              accent: AppColors.secondary,
                              filledForeground: AppColors.secondaryForeground,
                              onTap: () => Navigator.pop(
                                context,
                                CalendarRsvpChoice.going,
                              ),
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                ownerMode
                    ? 'To leave this event, delete it from your profile menu.'
                    : 'You can change your status any time in your profile by clicking on the event.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  12.5,
                  color: AppColors.mutedForeground,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RsvpOptionButton extends StatelessWidget {
  const _RsvpOptionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.filled,
    required this.accent,
    required this.onTap,
    this.filledForeground,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool filled;
  final Color accent;
  final Color? filledForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled
        ? (filledForeground ?? AppColors.accentForeground)
        : accent;
    return SizedBox(
      height: 128,
      child: Material(
        color: filled ? accent : AppColors.card,
        elevation: filled ? 2 : 0,
        shadowColor: AppColors.secondary.withValues(alpha: 0.35),
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: filled ? accent : AppColors.border,
                width: filled ? AppDimens.borderThick : AppDimens.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 26, color: fg),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.display(
                      20,
                      color: fg,
                      letterSpacing: 0.04,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      12,
                      color: filled
                          ? fg.withValues(alpha: 0.9)
                          : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
