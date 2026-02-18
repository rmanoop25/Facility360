import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens following Material 3 type scale
/// Urban Company style: Clean, readable typography with good hierarchy
class AppTypography {
  AppTypography._();

  // =============================================================
  // FONT FAMILIES
  // =============================================================

  /// Primary font family for English
  static const String fontFamilyEn = 'Inter';

  /// Primary font family for Arabic
  static const String fontFamilyAr = 'Cairo';

  /// Get font family based on locale
  static String getFontFamily(String locale) {
    return locale == 'ar' ? fontFamilyAr : fontFamilyEn;
  }

  // =============================================================
  // FONT WEIGHTS
  // =============================================================

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // =============================================================
  // DISPLAY STYLES (Large headers, hero text)
  // =============================================================

  /// Display Large - 32px Bold
  static TextStyle displayLarge({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 32,
    fontWeight: bold,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Display Medium - 28px Bold
  static TextStyle displayMedium({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 28,
    fontWeight: bold,
    height: 1.25,
    letterSpacing: -0.25,
  );

  /// Display Small - 24px Bold
  static TextStyle displaySmall({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 24,
    fontWeight: bold,
    height: 1.3,
    letterSpacing: 0,
  );

  // =============================================================
  // HEADLINE STYLES (Section headers)
  // =============================================================

  /// Headline Large - 24px SemiBold
  static TextStyle headlineLarge({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 24,
    fontWeight: semiBold,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Headline Medium - 20px SemiBold
  static TextStyle headlineMedium({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 20,
    fontWeight: semiBold,
    height: 1.35,
    letterSpacing: 0,
  );

  /// Headline Small - 18px SemiBold
  static TextStyle headlineSmall({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 18,
    fontWeight: semiBold,
    height: 1.4,
    letterSpacing: 0,
  );

  // =============================================================
  // TITLE STYLES (Card titles, list items)
  // =============================================================

  /// Title Large - 18px Medium
  static TextStyle titleLarge({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 18,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Title Medium - 16px Medium
  static TextStyle titleMedium({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 16,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Title Small - 14px Medium
  static TextStyle titleSmall({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 14,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // =============================================================
  // BODY STYLES (Main content text)
  // =============================================================

  /// Body Large - 16px Regular
  static TextStyle bodyLarge({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 16,
    fontWeight: regular,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// Body Medium - 14px Regular
  static TextStyle bodyMedium({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 14,
    fontWeight: regular,
    height: 1.5,
    letterSpacing: 0.25,
  );

  /// Body Small - 12px Regular
  static TextStyle bodySmall({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 12,
    fontWeight: regular,
    height: 1.5,
    letterSpacing: 0.4,
  );

  // =============================================================
  // LABEL STYLES (Buttons, badges, captions)
  // =============================================================

  /// Label Large - 14px Medium (Buttons)
  static TextStyle labelLarge({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 14,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Label Medium - 12px Medium (Badges, tabs)
  static TextStyle labelMedium({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 12,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.5,
  );

  /// Label Small - 10px Medium (Small badges)
  static TextStyle labelSmall({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 10,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.5,
  );

  // =============================================================
  // SEMANTIC TEXT STYLES
  // =============================================================

  /// App bar title
  static TextStyle appBarTitle({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 18,
    fontWeight: semiBold,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Button text
  static TextStyle button({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 15,
    fontWeight: semiBold,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Input text
  static TextStyle input({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 16,
    fontWeight: regular,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// Input label
  static TextStyle inputLabel({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 14,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Input hint
  static TextStyle inputHint({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 16,
    fontWeight: regular,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// Input error
  static TextStyle inputError({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 12,
    fontWeight: regular,
    height: 1.4,
    letterSpacing: 0.4,
  );

  /// Caption text (timestamps, metadata)
  static TextStyle caption({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 12,
    fontWeight: regular,
    height: 1.4,
    letterSpacing: 0.4,
  );

  /// Overline text (section labels)
  static TextStyle overline({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 10,
    fontWeight: semiBold,
    height: 1.4,
    letterSpacing: 1.5,
  );

  /// Timer display (large numbers)
  static TextStyle timer({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 36,
    fontWeight: bold,
    height: 1.2,
    letterSpacing: 2,
  );

  /// Stat value (dashboard numbers)
  static TextStyle statValue({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 28,
    fontWeight: bold,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Stat label
  static TextStyle statLabel({String locale = 'en'}) => GoogleFonts.getFont(
    getFontFamily(locale),
    fontSize: 12,
    fontWeight: medium,
    height: 1.4,
    letterSpacing: 0.5,
  );
}
