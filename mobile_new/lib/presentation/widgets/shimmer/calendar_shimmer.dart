import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';

/// Calendar screen shimmer
class CalendarShimmer extends StatelessWidget {
  const CalendarShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerContainer(width: 24, height: 24, borderRadius: 4),
              const ShimmerContainer(width: 140, height: 20, borderRadius: 4),
              const ShimmerContainer(width: 24, height: 24, borderRadius: 4),
            ],
          ),

          AppSpacing.vGapLg,

          // Day headers (S M T W T F S)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) =>
              const ShimmerContainer(width: 32, height: 14, borderRadius: 4),
            ),
          ),

          AppSpacing.vGapMd,

          // Calendar grid (5 rows x 7 columns)
          ...List.generate(5, (row) => Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (col) =>
                const ShimmerContainer(width: 36, height: 36, borderRadius: 18),
              ),
            ),
          )),

          AppSpacing.vGapXl,

          // Events section header
          const ShimmerContainer(width: 100, height: 18, borderRadius: 4),

          AppSpacing.vGapMd,

          // Event cards
          ...List.generate(3, (index) => Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: _EventCardShimmer(),
          )),
        ],
      ),
    );
  }
}

class _EventCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          ShimmerContainer(
            width: 4,
            height: 48,
            customBorderRadius: AppRadius.allFull,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: 80, height: 12, borderRadius: 4),
                AppSpacing.vGapXs,
                const ShimmerContainer(width: double.infinity, height: 16, borderRadius: 4),
                AppSpacing.vGapXs,
                const ShimmerContainer(width: 120, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
