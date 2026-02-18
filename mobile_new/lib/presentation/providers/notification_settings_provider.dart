import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage_service.dart';

/// Storage key for notification preference
const _notificationEnabledKey = 'notifications_enabled';

/// Notification settings state provider with persistence
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, bool>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return NotificationSettingsNotifier(storage);
});

/// Notification settings notifier with persistence support
class NotificationSettingsNotifier extends StateNotifier<bool> {
  final SecureStorageService _storage;

  NotificationSettingsNotifier(this._storage) : super(true) {
    _loadSavedSetting();
  }

  /// Load saved notification preference from storage
  Future<void> _loadSavedSetting() async {
    try {
      final saved = await _storage.read(_notificationEnabledKey);
      if (saved != null) {
        state = saved == 'true';
      }
      debugPrint('NotificationSettings: Loaded - $state');
    } catch (e) {
      debugPrint('NotificationSettings: Failed to load - $e');
    }
  }

  /// Set notification enabled state and persist to storage
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(_notificationEnabledKey, enabled.toString());
    debugPrint('NotificationSettings: Set to $enabled');
  }

  /// Toggle notification enabled state
  Future<void> toggle() async {
    await setEnabled(!state);
  }

  /// Check if notifications are enabled
  bool get isEnabled => state;
}
