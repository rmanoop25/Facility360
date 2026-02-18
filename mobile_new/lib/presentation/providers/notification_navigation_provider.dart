import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_navigation_provider.g.dart';

/// Provider for handling notification navigation
///
/// Manages navigation state when user taps a notification.
/// State is cleared after navigation is handled.
@riverpod
class NotificationNavigation extends _$NotificationNavigation {
  @override
  String? build() => null;

  /// Navigate to a screen based on notification payload
  ///
  /// [payload] - JSON string containing notification data (issue_id, type, etc.)
  void navigate(String payload) {
    state = payload;
  }

  /// Clear navigation state after handling
  void clear() {
    state = null;
  }
}
