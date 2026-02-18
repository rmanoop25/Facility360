import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'shimmer_container.dart';
import 'stat_card_shimmer.dart';
import 'issue_card_shimmer.dart';

/// Composite shimmer for Tenant Home Screen
///
/// Layout matches TenantHomeScreen:
/// - 3 stat cards in a row (Active, Pending, Completed)
/// - Section header "Recent Issues"
/// - 3 issue cards
class TenantHomeShimmer extends StatelessWidget {
  const TenantHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Row
        const StatCardsRowShimmer(),

        AppSpacing.vGapXl,

        // Section Header shimmer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const ShimmerContainer(width: 120, height: 20, borderRadius: 4),
            const ShimmerContainer(width: 60, height: 16, borderRadius: 4),
          ],
        ),

        AppSpacing.vGapMd,

        // Issue cards shimmer (3 cards)
        const IssueListShimmer(itemCount: 3),
      ],
    );
  }
}

/// Sliver-compatible version for CustomScrollView
class SliverTenantHomeShimmer extends StatelessWidget {
  const SliverTenantHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Stats Row
        const StatCardsRowShimmer(),

        AppSpacing.vGapXl,

        // Section Header shimmer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const ShimmerContainer(width: 120, height: 20, borderRadius: 4),
            const ShimmerContainer(width: 60, height: 16, borderRadius: 4),
          ],
        ),

        AppSpacing.vGapMd,

        // Issue cards shimmer (3 cards)
        const IssueListShimmer(itemCount: 3),
      ]),
    );
  }
}
