import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/notification_provider.dart';
import '../../presentation/providers/notification_settings_provider.dart';
import 'local_notifications_service.dart';

/// Service for Firebase Cloud Messaging integration
///
/// Handles FCM token management, message reception, and notification display.
/// Follows ConnectivityService pattern with initialization in constructor.
class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationsService _localNotifications;
  final void Function(RemoteMessage) _onMessage;
  final void Function(String) _onNotificationTap;
  final bool Function() _isNotificationEnabled;

  FcmService({
    required LocalNotificationsService localNotifications,
    required void Function(RemoteMessage) onMessage,
    required void Function(String) onNotificationTap,
    required bool Function() isNotificationEnabled,
  })  : _localNotifications = localNotifications,
        _onMessage = onMessage,
        _onNotificationTap = onNotificationTap,
        _isNotificationEnabled = isNotificationEnabled {
    _init();
  }

  /// Initialize FCM service
  void _init() {
    try {
      // Initialize local notifications first
      _localNotifications.initialize(
        onNotificationTap: (payload) {
          debugPrint('FcmService: Local notification tapped');
          _onNotificationTap(payload);
        },
      );

      // Setup foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Setup notification tap handler (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from terminated state by notification
      _checkInitialMessage();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_handleTokenRefresh);

      debugPrint('FcmService: Initialized successfully');
    } catch (e) {
      debugPrint('FcmService: Initialization failed - $e');
    }
  }

  /// Request notification permission (iOS 10+, Android 13+)
  Future<NotificationSettings> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FcmService: Permission status - ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      debugPrint('FcmService: Failed to request permission - $e');
      rethrow;
    }
  }

  /// Check current permission status
  Future<NotificationSettings> checkPermission() async {
    try {
      return await _messaging.getNotificationSettings();
    } catch (e) {
      debugPrint('FcmService: Failed to check permission - $e');
      rethrow;
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FcmService: Token obtained - ${token.substring(0, 20)}...');
      } else {
        debugPrint('FcmService: No token available');
      }
      return token;
    } catch (e) {
      debugPrint('FcmService: Failed to get token - $e');
      return null;
    }
  }

  /// Check and request permission (returns true if granted)
  Future<bool> checkAndRequestPermission() async {
    try {
      // Check current permission
      final currentSettings = await checkPermission();

      // If already authorized, return true
      if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FcmService: Permission already granted');
        return true;
      }

      // If denied, return false (user must enable in settings)
      if (currentSettings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FcmService: Permission denied - user must enable in settings');
        return false;
      }

      // Request permission
      final newSettings = await requestPermission();
      return newSettings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('FcmService: Permission check failed - $e');
      return false;
    }
  }

  /// Handle foreground messages (show local notification)
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      debugPrint('FcmService: Foreground message received - ${message.messageId}');

      // Call custom handler (always store notification)
      _onMessage(message);

      // Check if notifications are enabled before showing
      if (!_isNotificationEnabled()) {
        debugPrint('FcmService: Notifications disabled, skipping display');
        return;
      }

      // Show local notification
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        _localNotifications.showNotification(
          title: notification.title ?? 'New Notification',
          body: notification.body ?? '',
          payload: jsonEncode(data),
        );
      }
    } catch (e) {
      debugPrint('FcmService: Failed to handle foreground message - $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    try {
      debugPrint('FcmService: Notification tapped - ${message.messageId}');

      final data = message.data;
      if (data.isNotEmpty) {
        _onNotificationTap(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('FcmService: Failed to handle notification tap - $e');
    }
  }

  /// Handle token refresh (re-register with backend)
  void _handleTokenRefresh(String newToken) {
    try {
      debugPrint('FcmService: Token refreshed - ${newToken.substring(0, 20)}...');
      // Token refresh will be handled by DeviceRepository via app.dart listener
    } catch (e) {
      debugPrint('FcmService: Failed to handle token refresh - $e');
    }
  }

  /// Check initial message (app opened from terminated state)
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FcmService: App opened from notification - ${initialMessage.messageId}');
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('FcmService: Failed to check initial message - $e');
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('FcmService: Token deleted');
    } catch (e) {
      debugPrint('FcmService: Failed to delete token - $e');
    }
  }

  /// Dispose resources
  void dispose() {
    debugPrint('FcmService: Disposed');
  }
}

/// FCM service provider - created once with callbacks
final fcmServiceProvider = Provider<FcmService>((ref) {
  final localNotifications = ref.watch(localNotificationsServiceProvider);

  // Callback to handle foreground messages
  void onMessage(RemoteMessage message) {
    debugPrint('FcmService: Message callback - ${message.messageId}');
    // Save notification to local storage
    ref.read(notificationListProvider.notifier).addNotificationFromMessage(message);
  }

  // Callback to handle notification taps (navigate to screen)
  void onNotificationTap(String payload) {
    debugPrint('FcmService: Notification tap callback');
    // Will trigger navigation via provider
    // Note: This will be connected in app.dart
  }

  // Callback to check if notifications are enabled
  bool isNotificationEnabled() {
    return ref.read(notificationSettingsProvider);
  }

  final service = FcmService(
    localNotifications: localNotifications,
    onMessage: onMessage,
    onNotificationTap: onNotificationTap,
    isNotificationEnabled: isNotificationEnabled,
  );

  ref.onDispose(() => service.dispose());
  return service;
});

/// FCM token provider
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.getToken();
});

/// Permission status provider
final fcmPermissionProvider = FutureProvider<bool>((ref) async {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.checkAndRequestPermission();
});
