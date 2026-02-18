import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';
import 'stat_card_shimmer.dart';

/// Composite shimmer for Service Provider Home Screen
///
/// Layout matches SPHomeScreen:
/// - 3 stat cards in a row (Today's Jobs, Pending, Completed)
/// - Active job card (optional - shown as placeholder)
/// - Section header "Today's Schedule"
/// - 3 schedule cards
class SPHomeShimmer extends StatelessWidget {
  /// Whether to show the active job card shimmer
  final bool showActiveJob;

  const SPHomeShimmer({super.key, this.showActiveJob = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Row
        const StatCardsRowShimmer(),

        AppSpacing.vGapXl,

        // Active Job Card (if shown)
        if (showActiveJob) ...[
          const ShimmerContainer(width: 80, height: 20, borderRadius: 4),
          AppSpacing.vGapMd,
          const _ActiveJobCardShimmer(),
          AppSpacing.vGapXl,
        ],

        // Section Header shimmer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const ShimmerContainer(width: 130, height: 20, borderRadius: 4),
            const ShimmerContainer(width: 60, height: 16, borderRadius: 4),
          ],
        ),

        AppSpacing.vGapMd,

        // Schedule cards shimmer (3 cards)
        const _ScheduleListShimmer(itemCount: 3),
      ],
    );
  }
}

/// Active job card shimmer
class _ActiveJobCardShimmer extends StatelessWidget {
  const _ActiveJobCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.05),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: context.colors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (status badge + timer)
          Row(
            children: [
              const ShimmerContainer(width: 90, height: 24, borderRadius: 12),
              const Spacer(),
              const ShimmerContainer(width: 80, height: 28, borderRadius: 14),
            ],
          ),

          AppSpacing.vGapMd,

          // Title
          const ShimmerContainer(
            width: double.infinity,
            height: 20,
            borderRadius: 4,
          ),

          AppSpacing.vGapXs,

          // Location row
          Row(
            children: [
              const ShimmerContainer(width: 16, height: 16, borderRadius: 4),
              const SizedBox(width: 4),
              const ShimmerContainer(width: 140, height: 14, borderRadius: 4),
            ],
          ),

          AppSpacing.vGapLg,

          // Continue button
          const ShimmerContainer(
            width: double.infinity,
            height: 44,
            borderRadius: 22,
          ),
        ],
      ),
    );
  }
}

/// Schedule card shimmer
class _ScheduleCardShimmer extends StatelessWidget {
  const _ScheduleCardShimmer();

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
          // Time slot indicator
          ShimmerContainer(
            width: 4,
            height: 60,
            customBorderRadius: AppRadius.allFull,
          ),
          AppSpacing.gapMd,
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time
                const ShimmerContainer(width: 100, height: 14, borderRadius: 4),
                AppSpacing.vGapXs,
                // Title
                const ShimmerContainer(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                AppSpacing.vGapXs,
                // Location row
                Row(
                  children: [
                    const ShimmerContainer(
                      width: 14,
                      height: 14,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 4),
                    const ShimmerContainer(
                      width: 120,
                      height: 12,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chevron
          const ShimmerContainer(width: 24, height: 24, borderRadius: 4),
        ],
      ),
    );
  }
}

/// List of schedule card shimmers
class _ScheduleListShimmer extends StatelessWidget {
  final int itemCount;

  const _ScheduleListShimmer({this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < itemCount - 1 ? AppSpacing.md : 0,
          ),
          child: const _ScheduleCardShimmer(),
        ),
      ),
    );
  }
}

/// Sliver-compatible version for CustomScrollView
class SliverSPHomeShimmer extends StatelessWidget {
  final bool showActiveJob;

  const SliverSPHomeShimmer({super.key, this.showActiveJob = false});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        SPHomeShimmer(showActiveJob: showActiveJob),
      ]),
    );
  }
}
