import 'package:flutter/material.dart';

/// Border radius tokens for consistent rounded corners
/// Urban Company style: Softer, larger radius for modern feel
class AppRadius {
  AppRadius._();

  // =============================================================
  // BASE RADIUS VALUES
  // =============================================================

  /// No radius (sharp corners)
  static const double none = 0.0;

  /// 4px - Extra small (small badges, chips)
  static const double xs = 4.0;

  /// 8px - Small (buttons, inputs)
  static const double sm = 8.0;

  /// 12px - Medium (cards, dialogs)
  static const double md = 12.0;

  /// 16px - Large (large cards, bottom sheets)
  static const double lg = 16.0;

  /// 20px - Extra large (modals)
  static const double xl = 20.0;

  /// 24px - 2x Extra large (full modals)
  static const double xxl = 24.0;

  /// 999px - Full (pills, circular avatars)
  static const double full = 999.0;

  // =============================================================
  // SEMANTIC RADIUS VALUES
  // =============================================================

  /// Card radius (16px - Urban Company style)
  static const double card = 16.0;

  /// Button radius (12px)
  static const double button = 12.0;

  /// Input field radius (12px)
  static const double input = 12.0;

  /// Badge/chip radius (6px)
  static const double badge = 6.0;

  /// Bottom sheet radius (24px - top corners)
  static const double bottomSheet = 24.0;

  /// Dialog radius (20px)
  static const double dialog = 20.0;

  /// Avatar radius (full - circular)
  static const double avatar = full;

  /// Image radius (12px)
  static const double image = 12.0;

  /// Thumbnail radius (8px)
  static const double thumbnail = 8.0;

  // =============================================================
  // BORDER RADIUS HELPERS
  // =============================================================

  /// All corners xs (4)
  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));

  /// All corners sm (8)
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));

  /// All corners md (12)
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));

  /// All corners lg (16)
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));

  /// All corners xl (20)
  static const BorderRadius allXl = BorderRadius.all(Radius.circular(xl));

  /// All corners xxl (24)
  static const BorderRadius allXxl = BorderRadius.all(Radius.circular(xxl));

  /// All corners full (circular)
  static const BorderRadius allFull = BorderRadius.all(Radius.circular(full));

  /// Card border radius
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));

  /// Button border radius
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));

  /// Input border radius
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(input));

  /// Badge border radius
  static const BorderRadius badgeRadius = BorderRadius.all(Radius.circular(badge));

  /// Bottom sheet border radius (top only)
  static const BorderRadius bottomSheetRadius = BorderRadius.only(
    topLeft: Radius.circular(bottomSheet),
    topRight: Radius.circular(bottomSheet),
  );

  /// Dialog border radius
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(dialog));

  /// Image border radius
  static const BorderRadius imageRadius = BorderRadius.all(Radius.circular(image));

  /// Thumbnail border radius
  static const BorderRadius thumbnailRadius = BorderRadius.all(Radius.circular(thumbnail));

  // =============================================================
  // DIRECTIONAL BORDER RADIUS (RTL-safe)
  // =============================================================

  /// Top corners only lg
  static const BorderRadiusDirectional topLg = BorderRadiusDirectional.only(
    topStart: Radius.circular(lg),
    topEnd: Radius.circular(lg),
  );

  /// Bottom corners only lg
  static const BorderRadiusDirectional bottomLg = BorderRadiusDirectional.only(
    bottomStart: Radius.circular(lg),
    bottomEnd: Radius.circular(lg),
  );

  /// Start corners only lg (left in LTR, right in RTL)
  static const BorderRadiusDirectional startLg = BorderRadiusDirectional.only(
    topStart: Radius.circular(lg),
    bottomStart: Radius.circular(lg),
  );

  /// End corners only lg (right in LTR, left in RTL)
  static const BorderRadiusDirectional endLg = BorderRadiusDirectional.only(
    topEnd: Radius.circular(lg),
    bottomEnd: Radius.circular(lg),
  );
}
