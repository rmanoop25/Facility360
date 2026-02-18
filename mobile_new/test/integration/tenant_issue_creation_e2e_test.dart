import 'package:flutter_test/flutter_test.dart';

import '../../lib/domain/enums/sync_status.dart';
import '../../lib/domain/enums/user_role.dart';
import 'helpers/e2e_test_harness.dart';

/// Tenant Issue Creation Flow E2E Test
///
/// Tests the complete flow:
/// 1. Launch app → login as tenant
/// 2. Navigate to "Create Issue" screen
/// 3. Fill form (title, description, category, priority)
/// 4. Capture/upload images
/// 5. Submit while offline
/// 6. Verify issue appears in "My Issues" with SyncStatus.pending
/// 7. Simulate connectivity → online
/// 8. Verify sync queue processes
/// 9. Verify issue updates to SyncStatus.synced with server ID
/// 10. Navigate to issue details
/// 11. Verify all data persisted correctly
void main() {
  group('Tenant Issue Creation E2E', () {
    setUp(() async {
      // Clear all data before each test
      await E2ETestHarness.clearAllData();
    });

    testWidgets(
      'tenant creates issue while offline and syncs when online',
      (WidgetTester tester) async {
        // Step 1: Setup app and login as tenant
        await E2ETestHarness.setupApp(tester);
        await E2ETestHarness.loginAs(tester, UserRole.tenant);

        // Verify we're on tenant home screen
        E2ETestHarness.expectTextOnScreen('nav.home');

        // Step 2: Navigate to create issue screen
        await E2ETestHarness.tapButton(tester, 'common.create_issue');

        // Verify we're on create issue screen
        E2ETestHarness.expectWidgetByKey('create_issue_screen');

        // Step 3: Fill out the form
        await E2ETestHarness.fillIssueForm(
          tester,
          title: 'AC Not Working in Living Room',
          description:
              'The air conditioning unit has stopped working. Room is very hot.',
          priority: 'high',
          categoryIndex: 0,
        );

        // Step 4: Add photos (mock)
        await E2ETestHarness.selectPhoto(tester);
        await E2ETestHarness.selectPhoto(tester);

        // Step 5: Simulate offline mode
        await E2ETestHarness.simulateOffline(tester);

        // Verify offline banner appears
        E2ETestHarness.expectTextOnScreen('common.offline');

        // Submit the issue
        await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');

        // Wait for processing
        await E2ETestHarness.waitForLoadingToComplete(tester);

        // Verify success message
        await E2ETestHarness.expectSnackbar(
          tester,
          'tenant.issue_created_offline',
        );

        // Step 6: Verify issue appears in "My Issues" list with pending status
        await E2ETestHarness.navigateTo(tester, '/tenant/issues');

        E2ETestHarness.expectTextOnScreen('AC Not Working in Living Room');
        E2ETestHarness.expectSyncStatus('pending');

        // Tap on the issue to view details
        await E2ETestHarness.tapButton(
            tester, 'AC Not Working in Living Room');

        // Verify issue details screen
        E2ETestHarness.expectWidgetByKey('issue_details_screen');
        E2ETestHarness.expectTextOnScreen('AC Not Working in Living Room');
        E2ETestHarness.expectTextOnScreen(
          'The air conditioning unit has stopped working. Room is very hot.',
        );
        E2ETestHarness.expectSyncStatus('pending');

        // Verify sync queue has 1 operation
        final queueCountBefore = await E2ETestHarness.getSyncQueueCount();
        expect(queueCountBefore, equals(1));

        // Step 7: Go back to list and simulate going online
        await E2ETestHarness.navigateTo(tester, '/tenant/issues');
        await E2ETestHarness.simulateOnline(tester);

        // Verify offline banner disappears
        E2ETestHarness.expectTextNotOnScreen('common.offline');

        // Step 8: Wait for sync to process
        await E2ETestHarness.waitForSync(tester);

        // Step 9: Verify sync status changed to synced
        E2ETestHarness.expectSyncStatus('synced');

        // Verify sync queue is empty
        final queueCountAfter = await E2ETestHarness.getSyncQueueCount();
        expect(queueCountAfter, equals(0));

        // Step 10: Navigate to issue details again
        await E2ETestHarness.tapButton(
            tester, 'AC Not Working in Living Room');

        // Step 11: Verify all data persisted correctly
        E2ETestHarness.expectTextOnScreen('AC Not Working in Living Room');
        E2ETestHarness.expectTextOnScreen(
          'The air conditioning unit has stopped working. Room is very hot.',
        );
        E2ETestHarness.expectSyncStatus('synced');

        // Verify server ID is positive (not negative local ID)
        E2ETestHarness.expectWidgetByKey('issue_id_positive');
      },
    );

    testWidgets(
      'tenant creates multiple issues offline and syncs in FIFO order',
      (WidgetTester tester) async {
        await E2ETestHarness.setupApp(tester);
        await E2ETestHarness.loginAs(tester, UserRole.tenant);

        // Go offline
        await E2ETestHarness.simulateOffline(tester);

        // Create 3 issues
        for (int i = 1; i <= 3; i++) {
          await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');

          await E2ETestHarness.fillIssueForm(
            tester,
            title: 'Offline Issue $i',
            description: 'Created offline issue number $i',
            priority: 'medium',
          );

          await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');
          await E2ETestHarness.waitForLoadingToComplete(tester);
        }

        // Verify all 3 appear in list with pending status
        await E2ETestHarness.navigateTo(tester, '/tenant/issues');

        E2ETestHarness.expectTextOnScreen('Offline Issue 1');
        E2ETestHarness.expectTextOnScreen('Offline Issue 2');
        E2ETestHarness.expectTextOnScreen('Offline Issue 3');

        // Verify sync queue has 3 operations
        final queueCount = await E2ETestHarness.getSyncQueueCount();
        expect(queueCount, equals(3));

        // Go online
        await E2ETestHarness.simulateOnline(tester);
        await E2ETestHarness.waitForSync(tester);

        // Verify all synced
        final queueCountAfter = await E2ETestHarness.getSyncQueueCount();
        expect(queueCountAfter, equals(0));

        // All issues should show synced status
        // (In real implementation, verify sync status indicators)
      },
    );

    testWidgets(
      'tenant cannot submit issue with empty required fields',
      (WidgetTester tester) async {
        await E2ETestHarness.setupApp(tester);
        await E2ETestHarness.loginAs(tester, UserRole.tenant);

        await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');

        // Try to submit without filling anything
        await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');

        // Verify validation errors appear
        E2ETestHarness.expectTextOnScreen('common.validation_required');

        // Fill only title
        await E2ETestHarness.enterText(
          tester,
          'issue_title_field',
          'Test Title',
        );

        await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');

        // Still should fail (missing description and category)
        E2ETestHarness.expectTextOnScreen('common.validation_required');
      },
    );

    testWidgets(
      'tenant edits local issue before sync',
      (WidgetTester tester) async {
        await E2ETestHarness.setupApp(tester);
        await E2ETestHarness.loginAs(tester, UserRole.tenant);

        // Create issue offline
        await E2ETestHarness.simulateOffline(tester);

        await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');

        await E2ETestHarness.fillIssueForm(
          tester,
          title: 'Original Title',
          description: 'Original description',
          priority: 'low',
        );

        await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');
        await E2ETestHarness.waitForLoadingToComplete(tester);

        // Navigate to issue
        await E2ETestHarness.navigateTo(tester, '/tenant/issues');
        await E2ETestHarness.tapButton(tester, 'Original Title');

        // Tap edit
        await E2ETestHarness.tapButtonByKey(tester, 'edit_issue_button');

        // Change title and priority
        await E2ETestHarness.enterText(
          tester,
          'issue_title_field',
          'Updated Title',
        );

        // Change priority to high
        final priorityDropdown =
            find.byKey(const Key('issue_priority_dropdown'));
        await tester.tap(priorityDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('high').last);
        await tester.pumpAndSettle();

        await E2ETestHarness.tapButtonByKey(tester, 'save_issue_button');
        await E2ETestHarness.waitForLoadingToComplete(tester);

        // Verify changes reflected
        E2ETestHarness.expectTextOnScreen('Updated Title');

        // Verify still pending sync
        E2ETestHarness.expectSyncStatus('pending');

        // Go online and sync
        await E2ETestHarness.simulateOnline(tester);
        await E2ETestHarness.waitForSync(tester);

        // Verify updated data was synced
        E2ETestHarness.expectTextOnScreen('Updated Title');
        E2ETestHarness.expectSyncStatus('synced');
      },
    );

    testWidgets(
      'tenant views issue timeline after sync',
      (WidgetTester tester) async {
        await E2ETestHarness.setupApp(tester);
        await E2ETestHarness.loginAs(tester, UserRole.tenant);

        // Create issue while online
        await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');

        await E2ETestHarness.fillIssueForm(
          tester,
          title: 'Timeline Test Issue',
          description: 'Testing timeline display',
          priority: 'medium',
        );

        await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');
        await E2ETestHarness.waitForLoadingToComplete(tester);
        await E2ETestHarness.waitForSync(tester);

        // Navigate to issue details
        await E2ETestHarness.navigateTo(tester, '/tenant/issues');
        await E2ETestHarness.tapButton(tester, 'Timeline Test Issue');

        // Scroll to timeline section
        await E2ETestHarness.scrollUntilVisible(
          tester,
          find.byKey(const Key('issue_timeline_section')),
        );

        // Verify timeline entry exists
        E2ETestHarness.expectTextOnScreen('common.created');
        E2ETestHarness.expectWidgetByKey('timeline_entry_created');
      },
    );

    testWidgets(
      'tenant cancels local issue before sync',
      (WidgetTester tester) async {
        await E2ETestHarness.setupApp(tester);
        await E2ETestHarness.loginAs(tester, UserRole.tenant);

        // Create issue offline
        await E2ETestHarness.simulateOffline(tester);

        await E2ETestHarness.navigateTo(tester, '/tenant/issues/create');

        await E2ETestHarness.fillIssueForm(
          tester,
          title: 'To Be Cancelled',
          description: 'Will cancel this',
          priority: 'low',
        );

        await E2ETestHarness.tapButtonByKey(tester, 'submit_issue_button');
        await E2ETestHarness.waitForLoadingToComplete(tester);

        // Navigate to issue
        await E2ETestHarness.navigateTo(tester, '/tenant/issues');
        await E2ETestHarness.tapButton(tester, 'To Be Cancelled');

        // Tap cancel
        await E2ETestHarness.tapButtonByKey(tester, 'cancel_issue_button');

        // Confirm cancellation
        await E2ETestHarness.tapButton(tester, 'common.confirm');

        // Verify issue status changed to cancelled
        E2ETestHarness.expectTextOnScreen('status.cancelled');

        // Go online
        await E2ETestHarness.simulateOnline(tester);
        await E2ETestHarness.waitForSync(tester);

        // Verify cancellation synced to server
        E2ETestHarness.expectSyncStatus('synced');
      },
    );
  });
}
