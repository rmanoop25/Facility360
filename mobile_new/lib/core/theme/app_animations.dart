import 'package:flutter/material.dart';

/// Animation constants for consistent micro-interactions
/// 2026 UX standard: Spring-like, responsive animations
class AppAnimations {
  AppAnimations._();

  // =============================================================
  // DURATION CONSTANTS
  // =============================================================

  /// Instant - For immediate feedback (50ms)
  static const Duration instant = Duration(milliseconds: 50);

  /// Fast - Quick transitions (150ms)
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal - Standard animations (250ms)
  static const Duration normal = Duration(milliseconds: 250);

  /// Medium - Moderate transitions (350ms)
  static const Duration medium = Duration(milliseconds: 350);

  /// Slow - Deliberate animations (500ms)
  static const Duration slow = Duration(milliseconds: 500);

  /// Page transition duration
  static const Duration pageTransition = Duration(milliseconds: 300);

  /// Modal/bottom sheet entrance
  static const Duration modalEntrance = Duration(milliseconds: 350);

  /// Modal/bottom sheet exit
  static const Duration modalExit = Duration(milliseconds: 250);

  /// List item stagger delay
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// Skeleton shimmer duration
  static const Duration shimmer = Duration(milliseconds: 1500);

  // =============================================================
  // ANIMATION CURVES (2026 standard: spring-like)
  // =============================================================

  /// Default curve - Smooth ease out
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Entrance curve - Elements appearing
  static const Curve entranceCurve = Curves.easeOutCubic;

  /// Exit curve - Elements disappearing
  static const Curve exitCurve = Curves.easeInCubic;

  /// Emphasis curve - Drawing attention
  static const Curve emphasisCurve = Curves.easeOutBack;

  /// Spring curve - Bouncy, playful
  static const Curve springCurve = Curves.elasticOut;

  /// Decelerate curve - Slowing down
  static const Curve decelerateCurve = Curves.decelerate;

  /// Linear curve - Constant speed
  static const Curve linearCurve = Curves.linear;

  // =============================================================
  // PRESS SCALE VALUES
  // =============================================================

  /// Button/card press scale (95% of original size)
  static const double pressScale = 0.95;

  /// Subtle press scale (98% of original size)
  static const double subtlePressScale = 0.98;

  /// Strong press scale (90% of original size)
  static const double strongPressScale = 0.90;

  // =============================================================
  // FADE VALUES
  // =============================================================

  /// Fully visible
  static const double opacityVisible = 1.0;

  /// Dimmed (for disabled states)
  static const double opacityDimmed = 0.5;

  /// Subtle (for hints)
  static const double opacitySubtle = 0.7;

  /// Hidden
  static const double opacityHidden = 0.0;

  // =============================================================
  // SLIDE OFFSETS (for staggered animations)
  // =============================================================

  /// Slide up offset
  static const Offset slideUp = Offset(0, 20);

  /// Slide down offset
  static const Offset slideDown = Offset(0, -20);

  /// Slide from start (left in LTR)
  static const Offset slideFromStart = Offset(-20, 0);

  /// Slide from end (right in LTR)
  static const Offset slideFromEnd = Offset(20, 0);

  // =============================================================
  // HELPER METHODS
  // =============================================================

  /// Calculate stagger delay for list items
  static Duration staggerDelayFor(int index, {int maxDelay = 10}) {
    final clampedIndex = index.clamp(0, maxDelay);
    return Duration(milliseconds: clampedIndex * staggerDelay.inMilliseconds);
  }

  /// Get page transition with slide and fade
  static Widget pageTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: entranceCurve,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: entranceCurve,
        )),
        child: child,
      ),
    );
  }
}
