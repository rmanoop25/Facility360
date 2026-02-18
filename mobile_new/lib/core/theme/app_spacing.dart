import 'package:flutter/material.dart';

/// Spacing tokens for consistent spacing throughout the app
/// ZERO TOLERANCE: Never use hardcoded numbers like SizedBox(height: 16)
class AppSpacing {
  AppSpacing._();

  // =============================================================
  // BASE SPACING SCALE (4px base unit)
  // =============================================================

  /// 4px - Micro spacing (icon-text gap, tight elements)
  static const double xs = 4.0;

  /// 8px - Small gaps (between chips, small elements)
  static const double sm = 8.0;

  /// 12px - Medium gaps (form field spacing)
  static const double md = 12.0;

  /// 16px - Standard padding (card padding, screen padding)
  static const double lg = 16.0;

  /// 24px - Section gaps (between sections)
  static const double xl = 24.0;

  /// 32px - Large sections (major section dividers)
  static const double xxl = 32.0;

  /// 48px - Extra large (screen top/bottom padding)
  static const double xxxl = 48.0;

  // =============================================================
  // SEMANTIC SPACING
  // =============================================================

  /// Screen horizontal padding
  static const double screenPaddingH = 16.0;

  /// Screen vertical padding
  static const double screenPaddingV = 24.0;

  /// Card internal padding
  static const double cardPadding = 16.0;

  /// List item vertical spacing
  static const double listItemGap = 12.0;

  /// Section header spacing
  static const double sectionGap = 24.0;

  /// Button internal padding horizontal
  static const double buttonPaddingH = 24.0;

  /// Button internal padding vertical
  static const double buttonPaddingV = 14.0;

  /// Input field padding
  static const double inputPadding = 16.0;

  /// Bottom sheet top padding
  static const double bottomSheetPadding = 24.0;

  /// App bar height
  static const double appBarHeight = 56.0;

  /// Bottom navigation height
  static const double bottomNavHeight = 80.0;

  /// FAB margin from edges
  static const double fabMargin = 16.0;

  // =============================================================
  // EDGE INSETS HELPERS
  // =============================================================

  /// No padding
  static const EdgeInsets zero = EdgeInsets.zero;

  /// All sides xs (4)
  static const EdgeInsets allXs = EdgeInsets.all(xs);

  /// All sides sm (8)
  static const EdgeInsets allSm = EdgeInsets.all(sm);

  /// All sides md (12)
  static const EdgeInsets allMd = EdgeInsets.all(md);

  /// All sides lg (16)
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// All sides xl (24)
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  /// All sides xxl (32)
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);

  /// Screen padding (16 horizontal, 24 vertical)
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: screenPaddingH,
    vertical: screenPaddingV,
  );

  /// Horizontal only lg (16)
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  /// Horizontal only xl (24)
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  /// Vertical only sm (8)
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);

  /// Vertical only md (12)
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);

  /// Vertical only lg (16)
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);

  /// Card padding (16 all sides)
  static const EdgeInsets card = EdgeInsets.all(cardPadding);

  /// List item padding
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // =============================================================
  // DIRECTIONAL EDGE INSETS (RTL-safe)
  // =============================================================

  /// Start only lg (16)
  static const EdgeInsetsDirectional startLg = EdgeInsetsDirectional.only(start: lg);

  /// End only lg (16)
  static const EdgeInsetsDirectional endLg = EdgeInsetsDirectional.only(end: lg);

  /// Top only xl (24)
  static const EdgeInsetsDirectional topXl = EdgeInsetsDirectional.only(top: xl);

  /// Bottom only xl (24)
  static const EdgeInsetsDirectional bottomXl = EdgeInsetsDirectional.only(bottom: xl);

  // =============================================================
  // SIZED BOX HELPERS
  // =============================================================

  /// Horizontal gap xs (4)
  static const SizedBox gapXs = SizedBox(width: xs);

  /// Horizontal gap sm (8)
  static const SizedBox gapSm = SizedBox(width: sm);

  /// Horizontal gap md (12)
  static const SizedBox gapMd = SizedBox(width: md);

  /// Horizontal gap lg (16)
  static const SizedBox gapLg = SizedBox(width: lg);

  /// Horizontal gap xl (24)
  static const SizedBox gapXl = SizedBox(width: xl);

  /// Vertical gap xs (4)
  static const SizedBox vGapXs = SizedBox(height: xs);

  /// Vertical gap sm (8)
  static const SizedBox vGapSm = SizedBox(height: sm);

  /// Vertical gap md (12)
  static const SizedBox vGapMd = SizedBox(height: md);

  /// Vertical gap lg (16)
  static const SizedBox vGapLg = SizedBox(height: lg);

  /// Vertical gap xl (24)
  static const SizedBox vGapXl = SizedBox(height: xl);

  /// Vertical gap xxl (32)
  static const SizedBox vGapXxl = SizedBox(height: xxl);

  /// Vertical gap xxxl (48)
  static const SizedBox vGapXxxl = SizedBox(height: xxxl);
}
