import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';

/// A shimmer loading widget for admin grid layouts (e.g., categories)
class AdminGridShimmer extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const AdminGridShimmer({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: AppSpacing.allLg,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const _ShimmerCard(),
    );
  }
}

/// A shimmer loading widget for admin list layouts (e.g., tenants, SPs)
class AdminListShimmer extends StatelessWidget {
  final int itemCount;

  const AdminListShimmer({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppSpacing.horizontalLg,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _ShimmerListItem(),
      ),
    );
  }
}

/// A shimmer loading widget for grouped list layouts (e.g., consumables)
class AdminGroupedListShimmer extends StatelessWidget {
  final int groupCount;
  final int itemsPerGroup;

  const AdminGroupedListShimmer({
    super.key,
    this.groupCount = 3,
    this.itemsPerGroup = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppSpacing.horizontalLg,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: groupCount,
      itemBuilder: (context, groupIndex) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header shimmer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                _ShimmerBox(width: 20, height: 20),
                AppSpacing.gapSm,
                _ShimmerBox(width: 100, height: 16),
                AppSpacing.gapSm,
                _ShimmerBox(width: 24, height: 20, borderRadius: 10),
              ],
            ),
          ),
          // Items in group
          ...List.generate(
            itemsPerGroup,
            (itemIndex) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ShimmerConsumableItem(),
            ),
          ),
          AppSpacing.vGapMd,
        ],
      ),
    );
  }
}

/// Base shimmer card for grid items
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.allLg,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: 44, height: 44, borderRadius: 12),
          const Spacer(),
          _ShimmerBox(width: double.infinity, height: 16),
          AppSpacing.vGapXs,
          _ShimmerBox(width: 80, height: 12),
          AppSpacing.vGapSm,
          Row(
            children: [
              _ShimmerBox(width: 24, height: 12),
              AppSpacing.gapMd,
              _ShimmerBox(width: 24, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Base shimmer item for list layouts
class _ShimmerListItem extends StatelessWidget {
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
          _ShimmerBox(width: 48, height: 48, borderRadius: 24),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: double.infinity, height: 16),
                AppSpacing.vGapXs,
                _ShimmerBox(width: 120, height: 12),
                AppSpacing.vGapXs,
                _ShimmerBox(width: 80, height: 10),
              ],
            ),
          ),
          _ShimmerBox(width: 24, height: 24),
        ],
      ),
    );
  }
}

/// Shimmer item for consumable lists
class _ShimmerConsumableItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          _ShimmerBox(width: 40, height: 40, borderRadius: 8),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: double.infinity, height: 14),
                AppSpacing.vGapXs,
                _ShimmerBox(width: 80, height: 10),
              ],
            ),
          ),
          _ShimmerBox(width: 20, height: 20),
        ],
      ),
    );
  }
}

/// Basic shimmer box with animation
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.colors.border.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
