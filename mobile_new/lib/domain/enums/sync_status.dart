import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Sync status for offline-first functionality
enum SyncStatus {
  /// Data is synced with server
  synced('synced'),

  /// Data is waiting to be synced
  pending('pending'),

  /// Data is currently being synced
  syncing('syncing'),

  /// Sync failed, will retry
  failed('failed');

  const SyncStatus(this.value);

  /// The string value for serialization
  final String value;

  /// Parse from string value
  static SyncStatus? fromValue(String? value) {
    if (value == null) return null;
    return SyncStatus.values.cast<SyncStatus?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }

  /// Get localized label using easy_localization
  String get label => switch (this) {
    synced => 'sync_status_enum.synced'.tr(),
    pending => 'sync_status_enum.pending'.tr(),
    syncing => 'sync_status_enum.syncing'.tr(),
    failed => 'sync_status_enum.failed'.tr(),
  };

  /// Get icon for this status
  IconData get icon => switch (this) {
    synced => Icons.cloud_done_rounded,
    pending => Icons.cloud_upload_rounded,
    syncing => Icons.sync_rounded,
    failed => Icons.cloud_off_rounded,
  };

  /// Check if data needs to be synced
  bool get needsSync => this == pending || this == failed;

  /// Check if sync is in progress
  bool get isInProgress => this == syncing;

  /// Check if data is available offline
  bool get isAvailableOffline => true; // All data is available offline
}
