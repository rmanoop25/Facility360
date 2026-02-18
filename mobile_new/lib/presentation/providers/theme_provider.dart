import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage_service.dart';

/// Storage key for theme preference
const _themeStorageKey = 'app_theme_mode';

/// Theme state provider with persistence
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return ThemeNotifier(storage);
});

/// Theme state notifier with persistence support
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SecureStorageService _storage;

  ThemeNotifier(this._storage) : super(ThemeMode.system) {
    _loadSavedTheme();
  }

  /// Load saved theme preference from storage
  Future<void> _loadSavedTheme() async {
    final savedTheme = await _storage.read(_themeStorageKey);
    if (savedTheme != null) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }
  }

  /// Set theme mode and persist to storage
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _storage.write(_themeStorageKey, mode.name);
  }

  /// Toggle between light and dark mode
  /// Uses platform brightness to determine current effective theme when in system mode
  Future<void> toggleTheme(Brightness platformBrightness) async {
    final isCurrentlyDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && platformBrightness == Brightness.dark);
    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }

  /// Check if dark mode is effectively active (considering system brightness)
  bool isDarkMode(Brightness platformBrightness) =>
      state == ThemeMode.dark ||
      (state == ThemeMode.system && platformBrightness == Brightness.dark);

  /// Check if light mode is active
  bool get isLightMode => state == ThemeMode.light;

  /// Check if system mode is active
  bool get isSystemMode => state == ThemeMode.system;
}
