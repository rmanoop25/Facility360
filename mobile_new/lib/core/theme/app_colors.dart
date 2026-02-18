import 'package:flutter/material.dart';

/// Urban Company-inspired color palette with semantic tokens
/// ZERO TOLERANCE: Never use Colors.* directly in widgets
class AppColors {
  AppColors._();

  // =============================================================
  // PRIMARY PALETTE - Urban Company Purple
  // =============================================================
  static const Color primary = Color(0xFF6B4EFF);
  static const Color primaryLight = Color(0xFF8B73FF);
  static const Color primaryDark = Color(0xFF4B2FDF);
  static const Color onPrimary = Colors.white;

  // =============================================================
  // SECONDARY PALETTE - Accent Orange
  // =============================================================
  static const Color secondary = Color(0xFFFF6B35);
  static const Color secondaryLight = Color(0xFFFF8B5A);
  static const Color secondaryDark = Color(0xFFE55520);
  static const Color onSecondary = Colors.white;

  // =============================================================
  // STATUS COLORS - Semantic colors for issue/assignment statuses
  // =============================================================
  static const Color statusPending = Color(0xFFFFA726);      // Orange 400
  static const Color statusAssigned = Color(0xFF42A5F5);     // Blue 400
  static const Color statusInProgress = Color(0xFF6B4EFF);   // Primary Purple
  static const Color statusOnHold = Color(0xFF78909C);       // Blue Grey 400
  static const Color statusFinished = Color(0xFF26A69A);     // Teal 400
  static const Color statusCompleted = Color(0xFF66BB6A);    // Green 400
  static const Color statusCancelled = Color(0xFFEF5350);    // Red 400

  // Status background colors (lighter versions for badges)
  static const Color statusPendingBg = Color(0xFFFFF3E0);
  static const Color statusAssignedBg = Color(0xFFE3F2FD);
  static const Color statusInProgressBg = Color(0xFFEDE7F6);
  static const Color statusOnHoldBg = Color(0xFFECEFF1);
  static const Color statusFinishedBg = Color(0xFFE0F2F1);
  static const Color statusCompletedBg = Color(0xFFE8F5E9);
  static const Color statusCancelledBg = Color(0xFFFFEBEE);

  // =============================================================
  // PRIORITY COLORS
  // =============================================================
  static const Color priorityLow = Color(0xFF66BB6A);        // Green 400
  static const Color priorityMedium = Color(0xFFFFA726);     // Orange 400
  static const Color priorityHigh = Color(0xFFEF5350);       // Red 400

  // Priority background colors
  static const Color priorityLowBg = Color(0xFFE8F5E9);
  static const Color priorityMediumBg = Color(0xFFFFF3E0);
  static const Color priorityHighBg = Color(0xFFFFEBEE);

  // =============================================================
  // SURFACE COLORS - Light Theme
  // =============================================================
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF5F5F7);

  // =============================================================
  // TEXT COLORS
  // =============================================================
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // =============================================================
  // BORDER & DIVIDER COLORS
  // =============================================================
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFF1F5F9);

  // =============================================================
  // SEMANTIC COLORS
  // =============================================================
  static const Color error = Color(0xFFEF5350);
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color success = Color(0xFF66BB6A);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFFA726);
  static const Color warningBg = Color(0xFFFFF3E0);
  static const Color info = Color(0xFF42A5F5);
  static const Color infoBg = Color(0xFFE3F2FD);

  // =============================================================
  // SYNC STATUS COLORS
  // =============================================================
  static const Color syncSynced = Color(0xFF66BB6A);
  static const Color syncPending = Color(0xFFFFA726);
  static const Color syncSyncing = Color(0xFF42A5F5);
  static const Color syncFailed = Color(0xFFEF5350);

  // =============================================================
  // NAVIGATION & UI ELEMENTS
  // =============================================================
  static const Color bottomNavBackground = Colors.white;
  static const Color bottomNavSelected = primary;
  static const Color bottomNavUnselected = Color(0xFF9CA3AF);
  static const Color appBarBackground = Colors.white;
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // =============================================================
  // DARK THEME COLORS (for future use)
  // =============================================================
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
}
