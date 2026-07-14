import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../app_colors.dart';
import '../app_dimens.dart';

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.muted,
      highlightColor: AppColors.card,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: AppDimens.borderThick,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.border,
                        width: AppDimens.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 15,
                          width: 100,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 60,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 30,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                color: AppColors.muted,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 22,
                width: 150,
                color: AppColors.muted,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 15,
                    width: 200,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 15,
                    width: double.infinity,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                    width: AppDimens.borderThick,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 15,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 40,
                    height: 40,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 15,
                    color: AppColors.muted,
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    color: AppColors.muted,
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
