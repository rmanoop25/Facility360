import 'package:flutter/material.dart';

/// Shadow tokens for 2026 soft shadow aesthetics
/// Urban Company style: Subtle, diffused shadows for depth
class AppShadows {
  AppShadows._();

  // =============================================================
  // BASE SHADOW LEVELS
  // =============================================================

  /// No shadow
  static List<BoxShadow> get none => [];

  /// Extra small shadow - Subtle elevation (buttons, chips)
  static List<BoxShadow> get xs => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Small shadow - Light elevation (cards, inputs)
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Medium shadow - Standard elevation (floating cards)
  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Large shadow - High elevation (modals, FAB)
  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  /// Extra large shadow - Maximum elevation (bottom sheets, overlays)
  static List<BoxShadow> get xl => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  // =============================================================
  // SEMANTIC SHADOWS (Component-specific)
  // =============================================================

  /// Card shadow - Default card elevation
  static List<BoxShadow> get card => sm;

  /// Card hover shadow - When card is pressed/hovered
  static List<BoxShadow> get cardHover => md;

  /// Card elevated shadow - Prominent cards
  static List<BoxShadow> get cardElevated => md;

  /// Button shadow - Elevated buttons
  static List<BoxShadow> get button => xs;

  /// Button pressed shadow - When button is pressed
  static List<BoxShadow> get buttonPressed => none;

  /// Bottom navigation shadow
  static List<BoxShadow> get bottomNav => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];

  /// App bar shadow
  static List<BoxShadow> get appBar => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Top navigation shadow (sticky headers at top)
  static List<BoxShadow> get topNav => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  /// Bottom sheet shadow
  static List<BoxShadow> get bottomSheet => xl;

  /// Dialog shadow
  static List<BoxShadow> get dialog => lg;

  /// FAB shadow
  static List<BoxShadow> get fab => md;

  /// Dropdown shadow
  static List<BoxShadow> get dropdown => md;

  /// Input focused shadow (subtle glow)
  static List<BoxShadow> inputFocused(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 0),
    ),
  ];

  // =============================================================
  // COLORED SHADOWS (for emphasis)
  // =============================================================

  /// Primary colored shadow
  static List<BoxShadow> primaryShadow(Color primaryColor) => [
    BoxShadow(
      color: primaryColor.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Success colored shadow
  static List<BoxShadow> successShadow(Color successColor) => [
    BoxShadow(
      color: successColor.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Error colored shadow
  static List<BoxShadow> errorShadow(Color errorColor) => [
    BoxShadow(
      color: errorColor.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
