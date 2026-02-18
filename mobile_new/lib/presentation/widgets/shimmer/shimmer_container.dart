import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_animations.dart';

/// Reusable shimmer animation container widget
///
/// Use this as the base for all shimmer/skeleton loading placeholders.
/// Animation: 1500ms duration, 0.3 -> 0.6 opacity, easeInOut curve.
class ShimmerContainer extends StatefulWidget {
  /// Width of the shimmer box (use double.infinity for full width)
  final double width;

  /// Height of the shimmer box
  final double height;

  /// Border radius (default: 4)
  final double borderRadius;

  /// Optional custom border radius for asymmetric shapes
  final BorderRadiusGeometry? customBorderRadius;

  const ShimmerContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.customBorderRadius,
  });

  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.shimmer,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            borderRadius:
                widget.customBorderRadius ??
                BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A card-shaped shimmer container with consistent styling
class ShimmerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ShimmerCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardShadow,
      ),
      child: child,
    );
  }
}
