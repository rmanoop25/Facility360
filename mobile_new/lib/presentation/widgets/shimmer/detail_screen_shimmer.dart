import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';

/// Shimmer for issue/assignment detail screens
class IssueDetailShimmer extends StatelessWidget {
  const IssueDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Title and Status
          Row(
            children: [
              const Expanded(
                child: ShimmerContainer(width: double.infinity, height: 24, borderRadius: 4),
              ),
              AppSpacing.gapMd,
              const ShimmerContainer(width: 80, height: 28, borderRadius: 14),
            ],
          ),
          AppSpacing.vGapSm,
          const ShimmerContainer(width: 120, height: 14, borderRadius: 4),

          AppSpacing.vGapXl,

          // Info Cards Row
          Row(
            children: [
              Expanded(child: _InfoCardShimmer()),
              AppSpacing.gapMd,
              Expanded(child: _InfoCardShimmer()),
            ],
          ),
          AppSpacing.vGapMd,
          Row(
            children: [
              Expanded(child: _InfoCardShimmer()),
              AppSpacing.gapMd,
              Expanded(child: _InfoCardShimmer()),
            ],
          ),

          AppSpacing.vGapXl,

          // Description Section
          const ShimmerContainer(width: 100, height: 18, borderRadius: 4),
          AppSpacing.vGapMd,
          const ShimmerContainer(width: double.infinity, height: 14, borderRadius: 4),
          AppSpacing.vGapSm,
          const ShimmerContainer(width: double.infinity, height: 14, borderRadius: 4),
          AppSpacing.vGapSm,
          const ShimmerContainer(width: 200, height: 14, borderRadius: 4),

          AppSpacing.vGapXl,

          // Images Section
          const ShimmerContainer(width: 80, height: 18, borderRadius: 4),
          AppSpacing.vGapMd,
          Row(
            children: [
              const ShimmerContainer(width: 100, height: 100, borderRadius: 8),
              AppSpacing.gapMd,
              const ShimmerContainer(width: 100, height: 100, borderRadius: 8),
              AppSpacing.gapMd,
              const ShimmerContainer(width: 100, height: 100, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Info card shimmer
class _InfoCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerContainer(width: 24, height: 24, borderRadius: 6),
          AppSpacing.vGapSm,
          const ShimmerContainer(width: 60, height: 12, borderRadius: 4),
          AppSpacing.vGapXs,
          const ShimmerContainer(width: 80, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Assignment detail shimmer (similar but with SP info)
class AssignmentDetailShimmer extends StatelessWidget {
  const AssignmentDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: ShimmerContainer(width: double.infinity, height: 24, borderRadius: 4),
              ),
              AppSpacing.gapMd,
              const ShimmerContainer(width: 80, height: 28, borderRadius: 14),
            ],
          ),
          AppSpacing.vGapSm,
          const ShimmerContainer(width: 150, height: 14, borderRadius: 4),

          AppSpacing.vGapXl,

          // Time slot card
          Container(
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                const ShimmerContainer(width: 48, height: 48, borderRadius: 24),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerContainer(width: 120, height: 16, borderRadius: 4),
                      AppSpacing.vGapXs,
                      const ShimmerContainer(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.vGapXl,

          // Location card
          Container(
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: 80, height: 14, borderRadius: 4),
                AppSpacing.vGapMd,
                const ShimmerContainer(width: double.infinity, height: 16, borderRadius: 4),
                AppSpacing.vGapSm,
                const ShimmerContainer(width: 200, height: 14, borderRadius: 4),
              ],
            ),
          ),

          AppSpacing.vGapXl,

          // Description
          const ShimmerContainer(width: 100, height: 18, borderRadius: 4),
          AppSpacing.vGapMd,
          const ShimmerContainer(width: double.infinity, height: 14, borderRadius: 4),
          AppSpacing.vGapSm,
          const ShimmerContainer(width: double.infinity, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}
