import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for handling local notifications and Android notification channels
///
/// Used to display foreground notifications when app is active.
class LocalNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin;

  LocalNotificationsService() : _plugin = FlutterLocalNotificationsPlugin();

  /// Initialize local notifications with Android channels
  ///
  /// [onNotificationTap] - Callback when user taps notification
  Future<void> initialize({
    required Function(String) onNotificationTap,
  }) async {
    try {
      // Android initialization settings - use app icon if custom icon not found
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize plugin
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            onNotificationTap(details.payload!);
          }
        },
      );

      // Create Android notification channel
      if (Platform.isAndroid) {
        await createChannel(
          'issues_channel',
          'Issue Notifications',
          'Notifications for issue updates and assignments',
        );
      }

      debugPrint('LocalNotificationsService: Initialized successfully');
    } catch (e) {
      debugPrint('LocalNotificationsService: Initialization failed - $e');
    }
  }

  /// Show notification in foreground
  ///
  /// [title] - Notification title
  /// [body] - Notification body text
  /// [payload] - Data to pass when notification is tapped
  /// [channelId] - Android notification channel ID
  Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
    String? channelId,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'issues_channel',
        'Issue Notifications',
        channelDescription: 'Notifications for issue updates and assignments',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('LocalNotificationsService: Notification shown - $title');
    } catch (e) {
      debugPrint('LocalNotificationsService: Failed to show notification - $e');
    }
  }

  /// Create notification channel for Android 8+
  ///
  /// [id] - Unique channel identifier
  /// [name] - Channel name shown to user
  /// [description] - Channel description
  Future<void> createChannel(
    String id,
    String name,
    String description,
  ) async {
    if (!Platform.isAndroid) return;

    try {
      final channel = AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('LocalNotificationsService: Channel created - $id');
    } catch (e) {
      debugPrint('LocalNotificationsService: Failed to create channel - $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('LocalNotificationsService: All notifications cancelled');
  }

  /// Cancel specific notification by ID
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    debugPrint('LocalNotificationsService: Notification cancelled - $id');
  }
}

/// Provider for LocalNotificationsService
final localNotificationsServiceProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});
