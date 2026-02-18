import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import 'shimmer_container.dart';
import 'stat_card_shimmer.dart';
import 'issue_card_shimmer.dart';

/// Composite shimmer for Admin Dashboard Screen
///
/// Layout matches AdminHomeScreen:
/// - Welcome section (already static, no shimmer needed)
/// - 2x2 stat cards grid
/// - Quick actions section header + chips
/// - "Issues Requiring Attention" section header
/// - 5 issue cards
/// - "Recent Activity" section header
/// - Activity items
class AdminDashboardShimmer extends StatelessWidget {
  const AdminDashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Grid (2x2)
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            AdminStatCardShimmer(),
            AdminStatCardShimmer(),
            AdminStatCardShimmer(),
            AdminStatCardShimmer(),
          ],
        ),

        SizedBox(height: AppSpacing.lg),

        // Quick Actions Header
        const ShimmerContainer(width: 100, height: 18, borderRadius: 4),

        SizedBox(height: AppSpacing.md),

        // Quick Action Chips
        const _QuickActionChipsShimmer(),

        SizedBox(height: AppSpacing.xl),

        // Issues Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const ShimmerContainer(width: 160, height: 18, borderRadius: 4),
            const ShimmerContainer(width: 60, height: 14, borderRadius: 4),
          ],
        ),

        SizedBox(height: AppSpacing.md),

        // Issue cards (5)
        const _AdminIssueListShimmer(itemCount: 5),

        SizedBox(height: AppSpacing.xl),

        // Recent Activity Header
        const ShimmerContainer(width: 120, height: 18, borderRadius: 4),

        SizedBox(height: AppSpacing.md),

        // Activity items
        const _ActivityListShimmer(itemCount: 4),
      ],
    );
  }
}

/// Quick action chips shimmer
class _QuickActionChipsShimmer extends StatelessWidget {
  const _QuickActionChipsShimmer();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        ShimmerContainer(width: 120, height: 36, borderRadius: 18),
        ShimmerContainer(width: 110, height: 36, borderRadius: 18),
      ],
    );
  }
}

/// Admin issue card list shimmer
class _AdminIssueListShimmer extends StatelessWidget {
  final int itemCount;

  const _AdminIssueListShimmer({this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < itemCount - 1 ? AppSpacing.md : 0,
          ),
          child: const AdminIssueCardShimmer(),
        ),
      ),
    );
  }
}

/// Activity item shimmer
class _ActivityItemShimmer extends StatelessWidget {
  const _ActivityItemShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          // Icon container
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: AppRadius.allMd,
            ),
            child: const ShimmerContainer(
              width: 16,
              height: 16,
              borderRadius: 4,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // Text
          const Expanded(
            child: ShimmerContainer(
              width: double.infinity,
              height: 14,
              borderRadius: 4,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // Time
          const ShimmerContainer(width: 40, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Activity list shimmer
class _ActivityListShimmer extends StatelessWidget {
  final int itemCount;

  const _ActivityListShimmer({this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => const _ActivityItemShimmer(),
      ),
    );
  }
}

/// Sliver-compatible shimmer for admin stats grid only
class SliverAdminStatsShimmer extends StatelessWidget {
  const SliverAdminStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      delegate: SliverChildListDelegate(const [
        AdminStatCardShimmer(),
        AdminStatCardShimmer(),
        AdminStatCardShimmer(),
        AdminStatCardShimmer(),
      ]),
    );
  }
}

/// Sliver-compatible shimmer for admin issues list
class SliverAdminIssuesShimmer extends StatelessWidget {
  final int itemCount;

  const SliverAdminIssuesShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < itemCount - 1 ? AppSpacing.md : AppSpacing.xl,
          ),
          child: const AdminIssueCardShimmer(),
        ),
        childCount: itemCount,
      ),
    );
  }
}
