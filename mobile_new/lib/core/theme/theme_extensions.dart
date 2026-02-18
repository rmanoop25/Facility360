import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Theme extension for semantic colors accessible via Theme.of(context)
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    // Primary
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.onPrimary,
    // Secondary
    required this.secondary,
    required this.secondaryLight,
    required this.onSecondary,
    // Status
    required this.statusPending,
    required this.statusAssigned,
    required this.statusInProgress,
    required this.statusOnHold,
    required this.statusFinished,
    required this.statusCompleted,
    required this.statusCancelled,
    // Status backgrounds
    required this.statusPendingBg,
    required this.statusAssignedBg,
    required this.statusInProgressBg,
    required this.statusOnHoldBg,
    required this.statusFinishedBg,
    required this.statusCompletedBg,
    required this.statusCancelledBg,
    // Priority
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.priorityLowBg,
    required this.priorityMediumBg,
    required this.priorityHighBg,
    // Surface
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    // Text
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    // Border
    required this.border,
    required this.borderLight,
    required this.divider,
    // Semantic
    required this.error,
    required this.errorBg,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    // Sync
    required this.syncSynced,
    required this.syncPending,
    required this.syncSyncing,
    required this.syncFailed,
  });

  // Primary
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color onPrimary;

  // Secondary
  final Color secondary;
  final Color secondaryLight;
  final Color onSecondary;

  // Status colors
  final Color statusPending;
  final Color statusAssigned;
  final Color statusInProgress;
  final Color statusOnHold;
  final Color statusFinished;
  final Color statusCompleted;
  final Color statusCancelled;

  // Status background colors
  final Color statusPendingBg;
  final Color statusAssignedBg;
  final Color statusInProgressBg;
  final Color statusOnHoldBg;
  final Color statusFinishedBg;
  final Color statusCompletedBg;
  final Color statusCancelledBg;

  // Priority colors
  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;
  final Color priorityLowBg;
  final Color priorityMediumBg;
  final Color priorityHighBg;

  // Surface colors
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color card;

  // Text colors
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Border colors
  final Color border;
  final Color borderLight;
  final Color divider;

  // Semantic colors
  final Color error;
  final Color errorBg;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color info;
  final Color infoBg;

  // Sync colors
  final Color syncSynced;
  final Color syncPending;
  final Color syncSyncing;
  final Color syncFailed;

  /// Light theme colors
  static const light = AppColorsExtension(
    // Primary
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    primaryDark: AppColors.primaryDark,
    onPrimary: AppColors.onPrimary,
    // Secondary
    secondary: AppColors.secondary,
    secondaryLight: AppColors.secondaryLight,
    onSecondary: AppColors.onSecondary,
    // Status
    statusPending: AppColors.statusPending,
    statusAssigned: AppColors.statusAssigned,
    statusInProgress: AppColors.statusInProgress,
    statusOnHold: AppColors.statusOnHold,
    statusFinished: AppColors.statusFinished,
    statusCompleted: AppColors.statusCompleted,
    statusCancelled: AppColors.statusCancelled,
    // Status backgrounds
    statusPendingBg: AppColors.statusPendingBg,
    statusAssignedBg: AppColors.statusAssignedBg,
    statusInProgressBg: AppColors.statusInProgressBg,
    statusOnHoldBg: AppColors.statusOnHoldBg,
    statusFinishedBg: AppColors.statusFinishedBg,
    statusCompletedBg: AppColors.statusCompletedBg,
    statusCancelledBg: AppColors.statusCancelledBg,
    // Priority
    priorityLow: AppColors.priorityLow,
    priorityMedium: AppColors.priorityMedium,
    priorityHigh: AppColors.priorityHigh,
    priorityLowBg: AppColors.priorityLowBg,
    priorityMediumBg: AppColors.priorityMediumBg,
    priorityHighBg: AppColors.priorityHighBg,
    // Surface
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceVariant: AppColors.surfaceVariant,
    card: AppColors.card,
    // Text
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    textDisabled: AppColors.textDisabled,
    // Border
    border: AppColors.border,
    borderLight: AppColors.borderLight,
    divider: AppColors.divider,
    // Semantic
    error: AppColors.error,
    errorBg: AppColors.errorBg,
    success: AppColors.success,
    successBg: AppColors.successBg,
    warning: AppColors.warning,
    warningBg: AppColors.warningBg,
    info: AppColors.info,
    infoBg: AppColors.infoBg,
    // Sync
    syncSynced: AppColors.syncSynced,
    syncPending: AppColors.syncPending,
    syncSyncing: AppColors.syncSyncing,
    syncFailed: AppColors.syncFailed,
  );

  /// Dark theme colors (for future use)
  static const dark = AppColorsExtension(
    // Primary (same in dark theme)
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    primaryDark: AppColors.primaryDark,
    onPrimary: AppColors.onPrimary,
    // Secondary
    secondary: AppColors.secondary,
    secondaryLight: AppColors.secondaryLight,
    onSecondary: AppColors.onSecondary,
    // Status (same in dark theme)
    statusPending: AppColors.statusPending,
    statusAssigned: AppColors.statusAssigned,
    statusInProgress: AppColors.statusInProgress,
    statusOnHold: AppColors.statusOnHold,
    statusFinished: AppColors.statusFinished,
    statusCompleted: AppColors.statusCompleted,
    statusCancelled: AppColors.statusCancelled,
    // Status backgrounds (darker versions)
    statusPendingBg: Color(0xFF3D2B00),
    statusAssignedBg: Color(0xFF002952),
    statusInProgressBg: Color(0xFF1A1040),
    statusOnHoldBg: Color(0xFF1A1A1A),
    statusFinishedBg: Color(0xFF003D33),
    statusCompletedBg: Color(0xFF003D00),
    statusCancelledBg: Color(0xFF3D0000),
    // Priority (same)
    priorityLow: AppColors.priorityLow,
    priorityMedium: AppColors.priorityMedium,
    priorityHigh: AppColors.priorityHigh,
    priorityLowBg: Color(0xFF003D00),
    priorityMediumBg: Color(0xFF3D2B00),
    priorityHighBg: Color(0xFF3D0000),
    // Surface (dark versions)
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkCard,
    card: AppColors.darkCard,
    // Text (dark versions)
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: Color(0xFF808080),
    textDisabled: Color(0xFF4D4D4D),
    // Border (dark versions)
    border: Color(0xFF3D3D3D),
    borderLight: Color(0xFF2D2D2D),
    divider: Color(0xFF2D2D2D),
    // Semantic (same)
    error: AppColors.error,
    errorBg: Color(0xFF3D0000),
    success: AppColors.success,
    successBg: Color(0xFF003D00),
    warning: AppColors.warning,
    warningBg: Color(0xFF3D2B00),
    info: AppColors.info,
    infoBg: Color(0xFF002952),
    // Sync (same)
    syncSynced: AppColors.syncSynced,
    syncPending: AppColors.syncPending,
    syncSyncing: AppColors.syncSyncing,
    syncFailed: AppColors.syncFailed,
  );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? onPrimary,
    Color? secondary,
    Color? secondaryLight,
    Color? onSecondary,
    Color? statusPending,
    Color? statusAssigned,
    Color? statusInProgress,
    Color? statusOnHold,
    Color? statusFinished,
    Color? statusCompleted,
    Color? statusCancelled,
    Color? statusPendingBg,
    Color? statusAssignedBg,
    Color? statusInProgressBg,
    Color? statusOnHoldBg,
    Color? statusFinishedBg,
    Color? statusCompletedBg,
    Color? statusCancelledBg,
    Color? priorityLow,
    Color? priorityMedium,
    Color? priorityHigh,
    Color? priorityLowBg,
    Color? priorityMediumBg,
    Color? priorityHighBg,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? border,
    Color? borderLight,
    Color? divider,
    Color? error,
    Color? errorBg,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? info,
    Color? infoBg,
    Color? syncSynced,
    Color? syncPending,
    Color? syncSyncing,
    Color? syncFailed,
  }) {
    return AppColorsExtension(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      onSecondary: onSecondary ?? this.onSecondary,
      statusPending: statusPending ?? this.statusPending,
      statusAssigned: statusAssigned ?? this.statusAssigned,
      statusInProgress: statusInProgress ?? this.statusInProgress,
      statusOnHold: statusOnHold ?? this.statusOnHold,
      statusFinished: statusFinished ?? this.statusFinished,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusCancelled: statusCancelled ?? this.statusCancelled,
      statusPendingBg: statusPendingBg ?? this.statusPendingBg,
      statusAssignedBg: statusAssignedBg ?? this.statusAssignedBg,
      statusInProgressBg: statusInProgressBg ?? this.statusInProgressBg,
      statusOnHoldBg: statusOnHoldBg ?? this.statusOnHoldBg,
      statusFinishedBg: statusFinishedBg ?? this.statusFinishedBg,
      statusCompletedBg: statusCompletedBg ?? this.statusCompletedBg,
      statusCancelledBg: statusCancelledBg ?? this.statusCancelledBg,
      priorityLow: priorityLow ?? this.priorityLow,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityLowBg: priorityLowBg ?? this.priorityLowBg,
      priorityMediumBg: priorityMediumBg ?? this.priorityMediumBg,
      priorityHighBg: priorityHighBg ?? this.priorityHighBg,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      divider: divider ?? this.divider,
      error: error ?? this.error,
      errorBg: errorBg ?? this.errorBg,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      syncSynced: syncSynced ?? this.syncSynced,
      syncPending: syncPending ?? this.syncPending,
      syncSyncing: syncSyncing ?? this.syncSyncing,
      syncFailed: syncFailed ?? this.syncFailed,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryLight: Color.lerp(secondaryLight, other.secondaryLight, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      statusPending: Color.lerp(statusPending, other.statusPending, t)!,
      statusAssigned: Color.lerp(statusAssigned, other.statusAssigned, t)!,
      statusInProgress: Color.lerp(statusInProgress, other.statusInProgress, t)!,
      statusOnHold: Color.lerp(statusOnHold, other.statusOnHold, t)!,
      statusFinished: Color.lerp(statusFinished, other.statusFinished, t)!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
      statusCancelled: Color.lerp(statusCancelled, other.statusCancelled, t)!,
      statusPendingBg: Color.lerp(statusPendingBg, other.statusPendingBg, t)!,
      statusAssignedBg: Color.lerp(statusAssignedBg, other.statusAssignedBg, t)!,
      statusInProgressBg: Color.lerp(statusInProgressBg, other.statusInProgressBg, t)!,
      statusOnHoldBg: Color.lerp(statusOnHoldBg, other.statusOnHoldBg, t)!,
      statusFinishedBg: Color.lerp(statusFinishedBg, other.statusFinishedBg, t)!,
      statusCompletedBg: Color.lerp(statusCompletedBg, other.statusCompletedBg, t)!,
      statusCancelledBg: Color.lerp(statusCancelledBg, other.statusCancelledBg, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityLowBg: Color.lerp(priorityLowBg, other.priorityLowBg, t)!,
      priorityMediumBg: Color.lerp(priorityMediumBg, other.priorityMediumBg, t)!,
      priorityHighBg: Color.lerp(priorityHighBg, other.priorityHighBg, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      syncSynced: Color.lerp(syncSynced, other.syncSynced, t)!,
      syncPending: Color.lerp(syncPending, other.syncPending, t)!,
      syncSyncing: Color.lerp(syncSyncing, other.syncSyncing, t)!,
      syncFailed: Color.lerp(syncFailed, other.syncFailed, t)!,
    );
  }
}

/// Theme extension for spacing tokens
@immutable
class AppSpacingExtension extends ThemeExtension<AppSpacingExtension> {
  const AppSpacingExtension({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
    required this.screenPaddingH,
    required this.screenPaddingV,
    required this.cardPadding,
    required this.listItemGap,
    required this.sectionGap,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double screenPaddingH;
  final double screenPaddingV;
  final double cardPadding;
  final double listItemGap;
  final double sectionGap;

  static const standard = AppSpacingExtension(
    xs: AppSpacing.xs,
    sm: AppSpacing.sm,
    md: AppSpacing.md,
    lg: AppSpacing.lg,
    xl: AppSpacing.xl,
    xxl: AppSpacing.xxl,
    xxxl: AppSpacing.xxxl,
    screenPaddingH: AppSpacing.screenPaddingH,
    screenPaddingV: AppSpacing.screenPaddingV,
    cardPadding: AppSpacing.cardPadding,
    listItemGap: AppSpacing.listItemGap,
    sectionGap: AppSpacing.sectionGap,
  );

  @override
  ThemeExtension<AppSpacingExtension> copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
    double? screenPaddingH,
    double? screenPaddingV,
    double? cardPadding,
    double? listItemGap,
    double? sectionGap,
  }) {
    return AppSpacingExtension(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      xxxl: xxxl ?? this.xxxl,
      screenPaddingH: screenPaddingH ?? this.screenPaddingH,
      screenPaddingV: screenPaddingV ?? this.screenPaddingV,
      cardPadding: cardPadding ?? this.cardPadding,
      listItemGap: listItemGap ?? this.listItemGap,
      sectionGap: sectionGap ?? this.sectionGap,
    );
  }

  @override
  ThemeExtension<AppSpacingExtension> lerp(
    covariant ThemeExtension<AppSpacingExtension>? other,
    double t,
  ) {
    if (other is! AppSpacingExtension) return this;
    return AppSpacingExtension(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
      xxxl: lerpDouble(xxxl, other.xxxl, t)!,
      screenPaddingH: lerpDouble(screenPaddingH, other.screenPaddingH, t)!,
      screenPaddingV: lerpDouble(screenPaddingV, other.screenPaddingV, t)!,
      cardPadding: lerpDouble(cardPadding, other.cardPadding, t)!,
      listItemGap: lerpDouble(listItemGap, other.listItemGap, t)!,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t)!,
    );
  }
}

double? lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
