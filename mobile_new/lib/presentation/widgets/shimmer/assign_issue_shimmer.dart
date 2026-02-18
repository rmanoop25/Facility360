import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';

/// Category grid shimmer for assign issue step 1
class CategoryGridShimmer extends StatelessWidget {
  final int itemCount;

  const CategoryGridShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: AppSpacing.allLg,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => _CategoryCardShimmer(),
    );
  }
}

class _CategoryCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ShimmerContainer(width: 48, height: 48, borderRadius: 12),
          AppSpacing.vGapMd,
          const ShimmerContainer(width: 80, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Service provider list shimmer for assign issue step 2
class ServiceProviderListShimmer extends StatelessWidget {
  final int itemCount;

  const ServiceProviderListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppSpacing.allLg,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: _ServiceProviderCardShimmer(),
      ),
    );
  }
}

class _ServiceProviderCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          const ShimmerContainer(width: 56, height: 56, borderRadius: 28),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: double.infinity, height: 16, borderRadius: 4),
                AppSpacing.vGapSm,
                const ShimmerContainer(width: 120, height: 12, borderRadius: 4),
                AppSpacing.vGapXs,
                Row(
                  children: [
                    const ShimmerContainer(width: 60, height: 20, borderRadius: 10),
                    AppSpacing.gapSm,
                    const ShimmerContainer(width: 60, height: 20, borderRadius: 10),
                  ],
                ),
              ],
            ),
          ),
          const ShimmerContainer(width: 24, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Time slot shimmer for assign issue step 3
class TimeSlotShimmer extends StatelessWidget {
  const TimeSlotShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker shimmer
          const ShimmerContainer(width: 120, height: 16, borderRadius: 4),
          AppSpacing.vGapMd,
          Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                const ShimmerContainer(width: 24, height: 24, borderRadius: 4),
                AppSpacing.gapMd,
                const ShimmerContainer(width: 150, height: 16, borderRadius: 4),
              ],
            ),
          ),

          AppSpacing.vGapXl,

          // Time slots header
          const ShimmerContainer(width: 100, height: 16, borderRadius: 4),
          AppSpacing.vGapMd,

          // Time slot chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(8, (index) =>
              const ShimmerContainer(width: 90, height: 36, borderRadius: 18),
            ),
          ),
        ],
      ),
    );
  }
}
