import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'theme_extensions.dart';

/// App theme configuration with Material 3 and custom extensions
class AppTheme {
  AppTheme._();

  /// Build light theme
  static ThemeData light({String locale = 'en'}) {
    final fontFamily = AppTypography.getFontFamily(locale);
    final colorScheme = _lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: fontFamily,

      // Scaffold
      scaffoldBackgroundColor: AppColors.scaffoldBackground,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.appBarTitle(locale: locale).copyWith(
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bottomNavBackground,
        selectedItemColor: AppColors.bottomNavSelected,
        unselectedItemColor: AppColors.bottomNavUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bottomNavBackground,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium(locale: locale).copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelMedium(locale: locale).copyWith(
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: AppSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: AppTypography.button(locale: locale),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: AppTypography.button(locale: locale),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: AppSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: AppTypography.button(locale: locale),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.inputPadding,
          vertical: AppSpacing.inputPadding,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.inputLabel(locale: locale).copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.inputHint(locale: locale).copyWith(
          color: AppColors.textTertiary,
        ),
        errorStyle: AppTypography.inputError(locale: locale).copyWith(
          color: AppColors.error,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withOpacity(0.12),
        labelStyle: AppTypography.labelMedium(locale: locale).copyWith(
          color: AppColors.textPrimary,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allSm,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheetRadius,
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogRadius,
        ),
        titleTextStyle: AppTypography.headlineMedium(locale: locale).copyWith(
          color: AppColors.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium(locale: locale).copyWith(
          color: AppColors.textSecondary,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.bodyMedium(locale: locale).copyWith(
          color: AppColors.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMd,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Tab Bar
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.labelLarge(locale: locale).copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.labelLarge(locale: locale),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
        indicatorSize: TabBarIndicatorSize.label,
      ),

      // Text Theme
      textTheme: _buildTextTheme(locale),

      // Extensions
      extensions: [
        AppColorsExtension.light,
        AppSpacingExtension.standard,
      ],
    );
  }

  /// Build dark theme
  static ThemeData dark({String locale = 'en'}) {
    final fontFamily = AppTypography.getFontFamily(locale);
    final colorScheme = _darkColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: fontFamily,

      // Scaffold
      scaffoldBackgroundColor: AppColors.darkBackground,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTypography.appBarTitle(locale: locale).copyWith(
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primary.withOpacity(0.24),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium(locale: locale).copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelMedium(locale: locale).copyWith(
            color: AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.darkTextSecondary, size: 24);
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: AppSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: AppTypography.button(locale: locale),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: AppTypography.button(locale: locale),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: Color(0xFF3D3D3D)),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: AppSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: AppTypography.button(locale: locale),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.inputPadding,
          vertical: AppSpacing.inputPadding,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: Color(0xFF3D3D3D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: Color(0xFF3D3D3D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.inputLabel(locale: locale).copyWith(
          color: AppColors.darkTextSecondary,
        ),
        hintStyle: AppTypography.inputHint(locale: locale).copyWith(
          color: AppColors.darkTextSecondary.withOpacity(0.7),
        ),
        errorStyle: AppTypography.inputError(locale: locale).copyWith(
          color: AppColors.error,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkCard,
        selectedColor: AppColors.primary.withOpacity(0.24),
        labelStyle: AppTypography.labelMedium(locale: locale).copyWith(
          color: AppColors.darkTextPrimary,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allSm,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheetRadius,
        ),
        showDragHandle: true,
        dragHandleColor: const Color(0xFF3D3D3D),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogRadius,
        ),
        titleTextStyle: AppTypography.headlineMedium(locale: locale).copyWith(
          color: AppColors.darkTextPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium(locale: locale).copyWith(
          color: AppColors.darkTextSecondary,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: AppTypography.bodyMedium(locale: locale).copyWith(
          color: AppColors.darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMd,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3D3D3D),
        thickness: 1,
        space: 1,
      ),

      // Tab Bar
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.darkTextSecondary,
        labelStyle: AppTypography.labelLarge(locale: locale).copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.labelLarge(locale: locale),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
        indicatorSize: TabBarIndicatorSize.label,
      ),

      // Text Theme
      textTheme: _buildDarkTextTheme(locale),

      // Extensions
      extensions: [
        AppColorsExtension.dark,
        AppSpacingExtension.standard,
      ],
    );
  }

  /// Build dark text theme
  static TextTheme _buildDarkTextTheme(String locale) {
    return TextTheme(
      displayLarge: AppTypography.displayLarge(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      displayMedium: AppTypography.displayMedium(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      displaySmall: AppTypography.displaySmall(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      headlineLarge: AppTypography.headlineLarge(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      headlineMedium: AppTypography.headlineMedium(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      headlineSmall: AppTypography.headlineSmall(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      titleLarge: AppTypography.titleLarge(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      titleMedium: AppTypography.titleMedium(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      titleSmall: AppTypography.titleSmall(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      bodyLarge: AppTypography.bodyLarge(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      bodyMedium: AppTypography.bodyMedium(locale: locale).copyWith(color: AppColors.darkTextSecondary),
      bodySmall: AppTypography.bodySmall(locale: locale).copyWith(color: AppColors.darkTextSecondary),
      labelLarge: AppTypography.labelLarge(locale: locale).copyWith(color: AppColors.darkTextPrimary),
      labelMedium: AppTypography.labelMedium(locale: locale).copyWith(color: AppColors.darkTextSecondary),
      labelSmall: AppTypography.labelSmall(locale: locale).copyWith(color: AppColors.darkTextSecondary),
    );
  }

  // =============================================================
  // COLOR SCHEMES
  // =============================================================

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryLight,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryLight,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.border,
    outlineVariant: AppColors.borderLight,
  );

  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryDark,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryDark,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    error: AppColors.error,
    onError: Colors.white,
    outline: Color(0xFF3D3D3D),
    outlineVariant: Color(0xFF2D2D2D),
  );

  // =============================================================
  // TEXT THEME
  // =============================================================

  static TextTheme _buildTextTheme(String locale) {
    return TextTheme(
      displayLarge: AppTypography.displayLarge(locale: locale),
      displayMedium: AppTypography.displayMedium(locale: locale),
      displaySmall: AppTypography.displaySmall(locale: locale),
      headlineLarge: AppTypography.headlineLarge(locale: locale),
      headlineMedium: AppTypography.headlineMedium(locale: locale),
      headlineSmall: AppTypography.headlineSmall(locale: locale),
      titleLarge: AppTypography.titleLarge(locale: locale),
      titleMedium: AppTypography.titleMedium(locale: locale),
      titleSmall: AppTypography.titleSmall(locale: locale),
      bodyLarge: AppTypography.bodyLarge(locale: locale),
      bodyMedium: AppTypography.bodyMedium(locale: locale),
      bodySmall: AppTypography.bodySmall(locale: locale),
      labelLarge: AppTypography.labelLarge(locale: locale),
      labelMedium: AppTypography.labelMedium(locale: locale),
      labelSmall: AppTypography.labelSmall(locale: locale),
    );
  }
}
