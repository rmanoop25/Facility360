import 'dart:convert';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/device_repository.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/notification_navigation_provider.dart';
import 'presentation/providers/theme_provider.dart';

/// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Main application widget
class Facility360App extends ConsumerWidget {
  const Facility360App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    // Watch auth state to trigger token registration
    ref.listen(authStateProvider, (previous, next) async {
      if (previous?.user != next.user) {
        if (next.user != null && next.isLoggedIn) {
          // User logged in - initialize FCM
          await _initializeFcm(ref);
        } else if (previous?.user != null && !next.isLoggedIn) {
          // User logged out - cleanup FCM token
          await _cleanupFcm(ref);
        }
      }
    });

    // Watch notification navigation to handle deep links
    ref.listen(notificationNavigationProvider, (previous, next) {
      if (next != null) {
        _handleNotificationNavigation(context, next, router, ref);
        ref.read(notificationNavigationProvider.notifier).clear();
      }
    });

    return MaterialApp.router(
      title: 'app.name'.tr(),
      debugShowCheckedModeBanner: false,

      // Theme - use easy_localization's locale
      theme: AppTheme.light(locale: context.locale.languageCode),
      darkTheme: AppTheme.dark(locale: context.locale.languageCode),
      themeMode: themeMode,

      // Routing
      routerConfig: router,

      // Localization - using easy_localization
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Builder for RTL support
      builder: (context, child) {
        return Directionality(
          textDirection: context.locale.languageCode == 'ar'
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Initialize FCM after login
  Future<void> _initializeFcm(WidgetRef ref) async {
    try {
      // Wait for UI to settle after login before showing dialogs
      await Future.delayed(const Duration(milliseconds: 500));

      // Check current permission status
      final status = await Permission.notification.status;
      debugPrint('FCM: Current permission status: $status');

      if (status.isGranted) {
        // Permission already granted, proceed with token registration
        await _registerFcmToken(ref);
        return;
      }

      if (status.isPermanentlyDenied) {
        // User has permanently denied, show dialog to open settings
        debugPrint('FCM: Permission permanently denied, showing settings dialog');
        _showPermissionDeniedDialog();
        return;
      }

      // Permission not yet requested or denied (can ask again)
      // Show pre-permission dialog to explain why we need notifications
      final shouldRequest = await _showPermissionRequestDialog();
      if (!shouldRequest) {
        debugPrint('FCM: User declined to enable notifications');
        return;
      }

      // Request permission
      final result = await Permission.notification.request();
      debugPrint('FCM: Permission request result: $result');

      if (result.isGranted) {
        await _registerFcmToken(ref);
      } else if (result.isPermanentlyDenied) {
        _showPermissionDeniedDialog();
      } else {
        debugPrint('FCM: Permission denied');
      }
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerFcmToken(WidgetRef ref) async {
    try {
      // Get FCM token
      final token = await ref.read(fcmServiceProvider).getToken();
      if (token == null) {
        debugPrint('Failed to get FCM token');
        return;
      }

      // Register token with backend
      final repository = ref.read(deviceRepositoryProvider);
      await repository.registerToken(token);

      debugPrint('FCM initialized and token registered');
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  /// Show dialog explaining why notifications are needed
  Future<bool> _showPermissionRequestDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('permission.notification_title'.tr()),
        content: Text('permission.notification_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('permission.not_now'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('permission.enable'.tr()),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show dialog when permission is permanently denied
  void _showPermissionDeniedDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('permission.notification_denied_title'.tr()),
        content: Text('permission.notification_denied_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('permission.maybe_later'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('permission.open_settings'.tr()),
          ),
        ],
      ),
    );
  }

  /// Cleanup FCM on logout
  Future<void> _cleanupFcm(WidgetRef ref) async {
    try {
      final repository = ref.read(deviceRepositoryProvider);
      final token = await repository.getStoredToken();

      if (token != null) {
        // Remove token from backend
        await repository.removeToken(token);
      }

      debugPrint('FCM token cleared');
    } catch (e) {
      debugPrint('FCM cleanup error: $e');
    }
  }

  /// Handle navigation from notification tap
  void _handleNotificationNavigation(
    BuildContext context,
    String payload,
    GoRouter router,
    WidgetRef ref,
  ) {
    try {
      // Parse payload JSON
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final issueId = data['issue_id'] as String?;

      // Navigate based on notification type
      if (type != null && issueId != null) {
        // Get current user to determine navigation path
        final user = ref.read(authStateProvider).user;

        if (user?.isTenant == true) {
          router.go('/tenant/issues/$issueId');
        } else if (user?.isServiceProvider == true) {
          router.go('/sp/assignments/$issueId');
        } else if (user?.isAdmin == true) {
          router.go('/admin/issues/$issueId');
        }
      }
    } catch (e) {
      debugPrint('Failed to handle notification navigation: $e');
    }
  }
}
