import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';

/// Shimmer placeholder for dashboard stat cards
///
/// Matches the layout of _StatCard in home screens:
/// - Icon (24x24) at top
/// - Large value text
/// - Small label text
class StatCardShimmer extends StatelessWidget {
  const StatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon placeholder
          const ShimmerContainer(width: 24, height: 24, borderRadius: 6),
          AppSpacing.vGapMd,
          // Value placeholder
          const ShimmerContainer(width: 40, height: 28, borderRadius: 4),
          AppSpacing.vGapXs,
          // Label placeholder
          const ShimmerContainer(width: 60, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Admin stat card shimmer (2x2 grid style with icon in container)
class AdminStatCardShimmer extends StatelessWidget {
  const AdminStatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container placeholder
          const ShimmerContainer(width: 36, height: 36, borderRadius: 8),
          const Spacer(),
          // Value placeholder
          const ShimmerContainer(width: 48, height: 24, borderRadius: 4),
          const SizedBox(height: 4),
          // Label placeholder
          const ShimmerContainer(width: 64, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Row of 3 stat card shimmers (for tenant/SP home)
class StatCardsRowShimmer extends StatelessWidget {
  const StatCardsRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: StatCardShimmer()),
        SizedBox(width: AppSpacing.md),
        Expanded(child: StatCardShimmer()),
        SizedBox(width: AppSpacing.md),
        Expanded(child: StatCardShimmer()),
      ],
    );
  }
}
