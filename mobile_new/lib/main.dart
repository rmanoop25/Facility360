import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/sync/background_sync.dart';
import 'core/sync/sync_operation.dart';
import 'core/sync/sync_operation_adapter.dart';
import 'data/local/adapters/assignment_hive_model.dart';
import 'data/local/adapters/assignment_hive_model_adapter.dart';
import 'data/local/adapters/category_hive_model.dart';
import 'data/local/adapters/category_hive_model_adapter.dart';
import 'data/local/adapters/consumable_hive_model.dart';
import 'data/local/adapters/consumable_hive_model_adapter.dart';
import 'data/local/adapters/dashboard_stats_hive_model.dart';
import 'data/local/adapters/dashboard_stats_hive_model_adapter.dart';
import 'data/local/adapters/issue_hive_model.dart';
import 'data/local/adapters/issue_hive_model_adapter.dart';
import 'data/local/adapters/last_location_hive_model.dart';
import 'data/local/adapters/last_location_hive_model_adapter.dart';
import 'data/local/adapters/notification_hive_model.dart';
import 'data/local/adapters/notification_hive_model_adapter.dart';
import 'data/local/adapters/service_provider_hive_model.dart';
import 'data/local/adapters/service_provider_hive_model_adapter.dart';
import 'data/local/adapters/tenant_hive_model.dart';
import 'data/local/adapters/tenant_hive_model_adapter.dart';
import 'data/local/adapters/time_slot_hive_model.dart';
import 'data/local/adapters/time_slot_hive_model_adapter.dart';
import 'data/local/adapters/user_hive_model.dart';
import 'data/local/adapters/user_hive_model_adapter.dart';
import 'data/local/adapters/work_type_hive_model.dart';
import 'data/local/adapters/work_type_hive_model_adapter.dart';

/// Top-level function for handling background FCM messages
///
/// MUST be top-level (not inside a class) for Firebase to call it.
/// Called when app receives notification in background or terminated state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FcmBackgroundHandler: Message received - ${message.messageId}');
  // OS handles notification display - no action needed here
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize easy_localization
  await EasyLocalization.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Custom error widget for build-time exceptions (replaces red/grey error screen)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Image.asset(
                  'assets/images/something_went_wrong.png',
                  width: 260,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode ? details.exceptionAsString() : 'An unexpected error occurred.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Log Flutter errors in debug mode
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Register Hive adapters
  _registerHiveAdapters();

  // Open Hive boxes for offline storage
  await _openHiveBoxes();

  // Initialize Firebase (before runApp)
  await Firebase.initializeApp();
  debugPrint('Firebase initialized successfully');

  // Setup background message handler (MUST be top-level function)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize background sync (only on mobile platforms)
  if (!kIsWeb) {
    await initBackgroundSync();
  }

  // Run the app with Riverpod and EasyLocalization
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(
        child: Facility360App(),
      ),
    ),
  );
}

/// Register all Hive type adapters
void _registerHiveAdapters() {
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

  // WorkTypeHiveModel adapter (typeId: 13)
  if (!Hive.isAdapterRegistered(13)) {
    Hive.registerAdapter(WorkTypeHiveModelAdapter());
  }
}

/// Open all required Hive boxes
Future<void> _openHiveBoxes() async {
  await Future.wait([
    // Sync queue for offline operations
    Hive.openBox<SyncOperation>('sync_queue'),
    // Core entity boxes
    Hive.openBox<IssueHiveModel>('issues'),
    Hive.openBox<AssignmentHiveModel>('assignments'),
    Hive.openBox<NotificationHiveModel>('notifications'),
    // User and auth boxes
    Hive.openBox<UserHiveModel>('users'),
    // Admin entity boxes
    Hive.openBox<TenantHiveModel>('tenants'),
    Hive.openBox<ServiceProviderHiveModel>('service_providers'),
    // Master data boxes
    Hive.openBox<CategoryHiveModel>('categories'),
    Hive.openBox<ConsumableHiveModel>('consumables'),
    Hive.openBox<TimeSlotHiveModel>('time_slots'),
    Hive.openBox<WorkTypeHiveModel>('work_types'),
    // Stats and cache boxes
    Hive.openBox<DashboardStatsHiveModel>('dashboard_stats'),
    Hive.openBox<LastLocationHiveModel>('last_location'),
    // Legacy cache boxes (keep for compatibility)
    Hive.openBox('categories_cache'),
    Hive.openBox('calendar_cache'),
  ]);
}
