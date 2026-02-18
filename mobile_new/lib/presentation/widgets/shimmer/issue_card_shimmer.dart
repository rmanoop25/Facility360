import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';

/// Shimmer placeholder for issue cards (tenant home, admin dashboard)
///
/// Matches the layout of _IssueCard:
/// - Priority indicator (4px wide bar)
/// - Title text
/// - Category + time text
/// - Status badge
class IssueCardShimmer extends StatelessWidget {
  const IssueCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          // Priority indicator
          ShimmerContainer(
            width: 4,
            height: 48,
            customBorderRadius: AppRadius.allFull,
          ),
          AppSpacing.gapMd,
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const ShimmerContainer(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                AppSpacing.vGapXs,
                // Category + time
                const ShimmerContainer(width: 140, height: 12, borderRadius: 4),
              ],
            ),
          ),
          AppSpacing.gapMd,
          // Status badge
          const ShimmerContainer(width: 64, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for admin issue cards (with chevron)
class AdminIssueCardShimmer extends StatelessWidget {
  const AdminIssueCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          // Priority indicator
          ShimmerContainer(
            width: 4,
            height: 48,
            customBorderRadius: AppRadius.allSm,
          ),
          SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Title
                    const Expanded(
                      child: ShimmerContainer(
                        width: double.infinity,
                        height: 16,
                        borderRadius: 4,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Status badge
                    const ShimmerContainer(
                      width: 56,
                      height: 20,
                      borderRadius: 4,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                // Unit + time
                const ShimmerContainer(width: 120, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // Chevron
          const ShimmerContainer(width: 24, height: 24, borderRadius: 4),
        ],
      ),
    );
  }
}

/// List of issue card shimmers
class IssueListShimmer extends StatelessWidget {
  final int itemCount;

  const IssueListShimmer({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < itemCount - 1 ? AppSpacing.md : 0,
          ),
          child: const IssueCardShimmer(),
        ),
      ),
    );
  }
}
