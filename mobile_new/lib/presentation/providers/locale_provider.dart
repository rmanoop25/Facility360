import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/storage/secure_storage_service.dart' show secureStorageServiceProvider;

/// Storage key for persisted locale
const _localeStorageKey = 'app_locale';

/// Locale state provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref);
});

/// Locale state notifier with persistence via SecureStorageService
class LocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;
  
  LocaleNotifier(this._ref) : super(const Locale('en')) {
    _loadSavedLocale();
  }

  /// Load saved locale from storage and sync to backend
  Future<void> _loadSavedLocale() async {
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      final savedLocale = await storage.read(_localeStorageKey);
      if (savedLocale != null && (savedLocale == 'en' || savedLocale == 'ar')) {
        state = Locale(savedLocale);
        // Sync to backend to ensure notification language matches
        _syncLocaleToBackend(savedLocale);
      }
    } catch (e) {
      // Fallback to English on error
      state = const Locale('en');
    }
  }

  /// Set locale and persist to storage
  /// Also syncs with easy_localization via context and backend API
  Future<void> setLocale(Locale locale, BuildContext context) async {
    state = locale;

    // Sync with easy_localization
    await context.setLocale(locale);

    // Persist to local storage
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      await storage.write(_localeStorageKey, locale.languageCode);
    } catch (e) {
      // Ignore storage errors
    }

    // Sync to backend (for notification language)
    // This is fire-and-forget to not block UI
    _syncLocaleToBackend(locale.languageCode);
  }

  /// Sync locale preference to backend for notification language
  Future<void> _syncLocaleToBackend(String localeCode) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.put(
        ApiConstants.profileLocale,
        data: {'locale': localeCode},
      );
    } catch (e) {
      // Log error but don't block - local preference is already saved
      debugPrint('Failed to sync locale to backend: $e');
    }
  }

  /// Toggle between English and Arabic
  Future<void> toggleLocale(BuildContext context) async {
    final newLocale = state.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    await setLocale(newLocale, context);
  }

  /// Check if current locale is Arabic
  bool get isArabic => state.languageCode == 'ar';

  /// Check if current locale is English
  bool get isEnglish => state.languageCode == 'en';
}
