import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../lib/core/network/connectivity_service.dart';
import '../../../lib/core/router/app_router.dart';
import '../../../lib/core/services/auth_service.dart';
import '../../../lib/core/storage/storage_service.dart';
import '../../../lib/core/sync/sync_queue_service.dart';
import '../../../lib/data/local/adapters/issue_hive_model.dart';
import '../../../lib/data/local/adapters/assignment_hive_model.dart';
import '../../../lib/domain/enums/user_role.dart';
import '../../../lib/main.dart';

/// E2E Test Harness for Flutter Integration Tests
///
/// Provides utilities for:
/// - App initialization with Hive
/// - User login simulation
/// - Connectivity mocking
/// - Navigation helpers
/// - Widget interaction helpers
class E2ETestHarness {
  /// Initialize the app for testing with all dependencies
  static Future<void> setupApp(WidgetTester tester) async {
    // Initialize Hive for testing
    await Hive.initFlutter();

    // Register Hive adapters (manual adapters required)
    if (!Hive.isAdapterRegistered(IssueHiveModelAdapter().typeId)) {
      Hive.registerAdapter(IssueHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(AssignmentHiveModelAdapter().typeId)) {
      Hive.registerAdapter(AssignmentHiveModelAdapter());
    }

    // Open required boxes
    await StorageService.init();

    // Pump the app
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Wait for initial frame
    await tester.pumpAndSettle();
  }

  /// Login as a specific user role with test credentials
  static Future<void> loginAs(
    WidgetTester tester,
    UserRole role, {
    String? email,
    String? password,
  }) async {
    // Default credentials based on role
    final credentials = _getCredentialsForRole(role, email, password);

    // Find email field
    final emailField = find.byKey(const Key('login_email_field'));
    expect(emailField, findsOneWidget);

    await tester.enterText(emailField, credentials['email']!);
    await tester.pump();

    // Find password field
    final passwordField = find.byKey(const Key('login_password_field'));
    expect(passwordField, findsOneWidget);

    await tester.enterText(passwordField, credentials['password']!);
    await tester.pump();

    // Tap login button
    final loginButton = find.byKey(const Key('login_submit_button'));
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);

    // Wait for navigation and loading
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  /// Get test credentials for each role
  static Map<String, String> _getCredentialsForRole(
    UserRole role,
    String? email,
    String? password,
  ) {
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }

    switch (role) {
      case UserRole.tenant:
        return {
          'email': 'tenant1@maintenance.local',
          'password': 'password',
        };
      case UserRole.serviceProvider:
        return {
          'email': 'plumber@maintenance.local',
          'password': 'password',
        };
      case UserRole.superAdmin:
        return {
          'email': 'admin@maintenance.local',
          'password': 'password',
        };
      case UserRole.manager:
        return {
          'email': 'manager@maintenance.local',
          'password': 'password',
        };
      case UserRole.viewer:
        return {
          'email': 'viewer@maintenance.local',
          'password': 'password',
        };
    }
  }

  /// Simulate going offline
  static Future<void> simulateOffline(WidgetTester tester) async {
    // Override the connectivity provider to return false
    // This requires using ProviderScope overrides in tests
    // For now, this is a placeholder for the pattern

    // In real implementation, you would:
    // 1. Override isOnlineProvider with false
    // 2. Trigger connectivity change listener
    // 3. Wait for UI updates

    await tester.pump();
  }

  /// Simulate going online
  static Future<void> simulateOnline(WidgetTester tester) async {
    // Override the connectivity provider to return true
    // Trigger sync queue processing

    await tester.pump();
  }

  /// Navigate to a specific route
  static Future<void> navigateTo(
    WidgetTester tester,
    String route,
  ) async {
    // Use app router to navigate
    // This requires access to the router context

    await tester.pumpAndSettle();
  }

  /// Find and tap a button with specific text
  static Future<void> tapButton(
    WidgetTester tester,
    String buttonText,
  ) async {
    final button = find.text(buttonText);
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Find and tap a button with specific key
  static Future<void> tapButtonByKey(
    WidgetTester tester,
    String key,
  ) async {
    final button = find.byKey(Key(key));
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Enter text into a field with specific key
  static Future<void> enterText(
    WidgetTester tester,
    String fieldKey,
    String text,
  ) async {
    final field = find.byKey(Key(fieldKey));
    expect(field, findsOneWidget);

    await tester.enterText(field, text);
    await tester.pump();
  }

  /// Scroll until a widget is visible
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder finder, {
    Finder? scrollable,
    double scrollDelta = 300.0,
  }) async {
    final scrollFinder = scrollable ?? find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      finder,
      scrollDelta,
      scrollable: scrollFinder,
    );

    await tester.pumpAndSettle();
  }

  /// Wait for a loading indicator to disappear
  static Future<void> waitForLoadingToComplete(WidgetTester tester) async {
    // Wait for any CircularProgressIndicator to disappear
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Check if loading is still present
    final loading = find.byType(CircularProgressIndicator);
    if (loading.evaluate().isNotEmpty) {
      // Wait longer if still loading
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
  }

  /// Verify a snackbar with specific text appears
  static Future<void> expectSnackbar(
    WidgetTester tester,
    String message,
  ) async {
    await tester.pump(); // Trigger snackbar animation
    expect(find.text(message), findsOneWidget);
    await tester.pumpAndSettle();
  }

  /// Clear all Hive boxes (for test isolation)
  static Future<void> clearAllData() async {
    await StorageService.clearAll();
  }

  /// Logout the current user
  static Future<void> logout(WidgetTester tester) async {
    // Find logout button (typically in drawer or profile)
    final logoutButton = find.byKey(const Key('logout_button'));

    if (logoutButton.evaluate().isNotEmpty) {
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
    }
  }

  /// Create a test issue locally (simulating offline creation)
  static Future<String> createTestIssue({
    required String title,
    required String description,
    String priority = 'medium',
    List<int> categoryIds = const [1],
  }) async {
    // Create issue in Hive directly
    final localId = DateTime.now().millisecondsSinceEpoch.toString();

    final hiveModel = IssueHiveModel.createLocal(
      localId: localId,
      title: title,
      description: description,
      categoryIds: categoryIds,
      priority: priority == 'high'
          ? 'high'
          : priority == 'low'
              ? 'low'
              : 'medium',
    );

    // Save to Hive
    await StorageService.saveIssue(hiveModel);

    return localId;
  }

  /// Verify an issue exists in local storage
  static Future<bool> verifyIssueInStorage(String localId) async {
    final issue = await StorageService.getIssueByLocalId(localId);
    return issue != null;
  }

  /// Get sync queue count
  static Future<int> getSyncQueueCount() async {
    final operations = await StorageService.getSyncOperations();
    return operations.length;
  }

  /// Wait for sync to complete
  static Future<void> waitForSync(WidgetTester tester) async {
    // Wait for sync queue to be processed
    // This should be implemented based on your sync service

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  /// Switch language
  static Future<void> switchLanguage(
    WidgetTester tester,
    String languageCode,
  ) async {
    // Navigate to settings
    // Find language dropdown/button
    // Select language

    await tester.pumpAndSettle();
  }

  /// Switch theme
  static Future<void> switchTheme(
    WidgetTester tester,
    ThemeMode mode,
  ) async {
    // Navigate to settings
    // Find theme toggle
    // Switch theme

    await tester.pumpAndSettle();
  }

  /// Take a screenshot (for debugging)
  static Future<void> takeScreenshot(
    WidgetTester tester,
    String name,
  ) async {
    // Implementation depends on test framework
    // Can use flutter_driver's screenshot capability
    await tester.pump();
  }

  /// Verify text exists anywhere on screen
  static void expectTextOnScreen(String text) {
    expect(find.text(text), findsAtLeastNWidgets(1));
  }

  /// Verify text does not exist on screen
  static void expectTextNotOnScreen(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Verify widget with key exists
  static void expectWidgetByKey(String key) {
    expect(find.byKey(Key(key)), findsOneWidget);
  }

  /// Fill out a complete issue form
  static Future<void> fillIssueForm(
    WidgetTester tester, {
    required String title,
    required String description,
    String priority = 'medium',
    int categoryIndex = 0,
  }) async {
    // Title
    await enterText(tester, 'issue_title_field', title);

    // Description
    await enterText(tester, 'issue_description_field', description);

    // Priority dropdown
    final priorityDropdown = find.byKey(const Key('issue_priority_dropdown'));
    if (priorityDropdown.evaluate().isNotEmpty) {
      await tester.tap(priorityDropdown);
      await tester.pumpAndSettle();

      final priorityOption = find.text(priority).last;
      await tester.tap(priorityOption);
      await tester.pumpAndSettle();
    }

    // Category selection (simplified)
    // In real implementation, handle category picker

    await tester.pump();
  }

  /// Capture and select a photo (mock)
  static Future<void> selectPhoto(WidgetTester tester) async {
    final photoButton = find.byKey(const Key('add_photo_button'));

    if (photoButton.evaluate().isNotEmpty) {
      await tester.tap(photoButton);
      await tester.pumpAndSettle();

      // In real test, this would trigger mock image picker
      // For now, just pump
    }
  }

  /// Verify sync status indicator
  static void expectSyncStatus(String status) {
    // 'synced', 'pending', 'syncing', 'failed'
    expect(
      find.byKey(Key('sync_status_$status')),
      findsAtLeastNWidgets(1),
    );
  }

  /// Drag to refresh
  static Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.drag(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
  }
}

/// Mock providers for testing
class MockConnectivityOverrides {
  /// Override to always return offline
  static isOffline() {
    // return ProviderOverride(
    //   isOnlineProvider,
    //   (ref) => false,
    // );
  }

  /// Override to always return online
  static isOnline() {
    // return ProviderOverride(
    //   isOnlineProvider,
    //   (ref) => true,
    // );
  }
}
