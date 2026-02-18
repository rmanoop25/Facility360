import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

// Hive adapters - imported for registration in isolate
import '../../data/local/adapters/assignment_hive_model_adapter.dart';
import '../../data/local/adapters/category_hive_model_adapter.dart';
import '../../data/local/adapters/consumable_hive_model_adapter.dart';
import '../../data/local/adapters/dashboard_stats_hive_model_adapter.dart';
import '../../data/local/adapters/issue_hive_model_adapter.dart';
import '../../data/local/adapters/last_location_hive_model_adapter.dart';
import '../../data/local/adapters/notification_hive_model_adapter.dart';
import '../../data/local/adapters/service_provider_hive_model_adapter.dart';
import '../../data/local/adapters/tenant_hive_model_adapter.dart';
import '../../data/local/adapters/time_slot_hive_model_adapter.dart';
import '../../data/local/adapters/user_hive_model_adapter.dart';
import 'background_sync_processor.dart';
import 'sync_operation.dart';
import 'sync_operation_adapter.dart';

/// Unique task name for background sync
const String backgroundSyncTaskName = 'facility360SyncTask';
const String backgroundSyncTaskTag = 'sync';

/// Callback dispatcher for WorkManager
/// This runs in an isolate, so we need to reinitialize Hive
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BackgroundSync: Task started - $task');

    try {
      // Initialize Hive in the background isolate
      await Hive.initFlutter();

      // Register all adapters (must be done in isolate)
      _registerHiveAdaptersInIsolate();

      // Open the sync queue box
      final box = await Hive.openBox<SyncOperation>('sync_queue');
      final pendingCount = box.length;

      if (pendingCount == 0) {
        debugPrint('BackgroundSync: No pending operations');
        await box.close();
        return true;
      }

      debugPrint('BackgroundSync: Found $pendingCount pending operations');

      // Initialize the background sync processor
      final processor = BackgroundSyncProcessor();
      final initialized = await processor.init();

      if (!initialized) {
        debugPrint('BackgroundSync: Processor init failed (no token or expired)');
        await box.close();
        return true; // Return true to avoid retries for auth issues
      }

      // Process the sync queue
      final successCount = await processor.processQueue(box);
      debugPrint('BackgroundSync: Synced $successCount operations');

      // Cleanup
      processor.dispose();
      await box.close();

      debugPrint('BackgroundSync: Task completed');
      return true;
    } catch (e, stackTrace) {
      debugPrint('BackgroundSync: Error - $e');
      debugPrint('BackgroundSync: Stack trace - $stackTrace');
      return false; // Will trigger retry with exponential backoff
    }
  });
}

/// Register all Hive adapters in the isolate
void _registerHiveAdaptersInIsolate() {
  // IssueHiveModel adapter (typeId: 1)
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(IssueHiveModelAdapter());
  }

  // AssignmentHiveModel adapter (typeId: 2)
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(AssignmentHiveModelAdapter());
  }

  // NotificationHiveModel adapter (typeId: 3)
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(NotificationHiveModelAdapter());
  }

  // UserHiveModel adapter (typeId: 4)
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(UserHiveModelAdapter());
  }

  // TenantHiveModel adapter (typeId: 5)
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(TenantHiveModelAdapter());
  }

  // ServiceProviderHiveModel adapter (typeId: 6)
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(ServiceProviderHiveModelAdapter());
  }

  // CategoryHiveModel adapter (typeId: 7)
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(CategoryHiveModelAdapter());
  }

  // ConsumableHiveModel adapter (typeId: 8)
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(ConsumableHiveModelAdapter());
  }

  // TimeSlotHiveModel adapter (typeId: 9)
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(TimeSlotHiveModelAdapter());
  }

  // SyncOperation adapter (typeId: 10)
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SyncOperationAdapter());
  }

  // DashboardStatsHiveModel adapter (typeId: 11)
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(DashboardStatsHiveModelAdapter());
  }

  // LastLocationHiveModel adapter (typeId: 12)
  if (!Hive.isAdapterRegistered(12)) {
    Hive.registerAdapter(LastLocationHiveModelAdapter());
  }
}

/// Initialize background sync with WorkManager
Future<void> initBackgroundSync() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    // Register periodic task (runs every 30 minutes when connected)
    // Per plan: "Every 30 minutes via WorkManager background task"
    await Workmanager().registerPeriodicTask(
      'sync-periodic',
      backgroundSyncTaskName,
      tag: backgroundSyncTaskTag,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      initialDelay: const Duration(seconds: 10),
    );

    debugPrint('BackgroundSync: Initialized with 30-minute interval');
  } catch (e) {
    debugPrint('BackgroundSync: Failed to initialize - $e');
  }
}

/// Trigger immediate sync (one-time task)
Future<void> triggerImmediateSync() async {
  try {
    await Workmanager().registerOneOffTask(
      'sync-immediate-${DateTime.now().millisecondsSinceEpoch}',
      backgroundSyncTaskName,
      tag: backgroundSyncTaskTag,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    debugPrint('BackgroundSync: Immediate sync triggered');
  } catch (e) {
    debugPrint('BackgroundSync: Failed to trigger immediate sync - $e');
  }
}

/// Cancel all background sync tasks
Future<void> cancelBackgroundSync() async {
  try {
    await Workmanager().cancelByTag(backgroundSyncTaskTag);
    debugPrint('BackgroundSync: Cancelled');
  } catch (e) {
    debugPrint('BackgroundSync: Failed to cancel - $e');
  }
}
