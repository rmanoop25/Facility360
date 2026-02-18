/// API configuration constants
class ApiConstants {
  ApiConstants._();

  // Base URLs - configurable per environment
  static const String devBaseUrl =
      'http://192.168.1.7:8000/api/v1'; // Local backend
  static const String iosSimulatorUrl =
      'https://dev.devsuite.xyz/api/v1'; // iOS simulator
  static const String prodBaseUrl =
      'https://dev.devsuite.xyz/api/v1'; // Hosted backend

  // Current environment (change for production)
  static const bool isProduction = false;

  /// Get base URL - supports runtime override via --dart-define
  ///
  /// Usage examples:
  /// - Default (local): flutter run
  /// - Hosted backend: flutter run --dart-define=BASE_URL=http://app.51.83.40.231.nip.io/api/v1
  /// - Custom backend: flutter build apk --dart-define=BASE_URL=http://custom-ip:8000/api/v1
  static String get baseUrl {
    // Check for environment override
    const envBaseUrl = String.fromEnvironment('BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) return envBaseUrl;

    // Fall back to defaults
    return isProduction ? prodBaseUrl : devBaseUrl;
  }

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Profile Endpoints
  static const String profileLocale = '/profile/locale';

  // =============================================================
  // TENANT ENDPOINTS
  // =============================================================
  /// List tenant's issues (paginated)
  static const String issues = '/issues';

  /// Get/create issue - use with issue ID for detail
  static String issueDetail(int id) => '/issues/$id';

  /// Cancel issue - POST
  static String cancelIssue(int id) => '/issues/$id/cancel';

  // =============================================================
  // SERVICE PROVIDER ENDPOINTS
  // =============================================================
  /// List SP's assignments (paginated)
  static const String assignments = '/assignments';

  /// Get assignment by issue ID
  static String assignmentDetail(int issueId) => '/assignments/$issueId';

  /// Start work on assignment - POST
  static String startWork(int issueId) => '/assignments/$issueId/start';

  /// Hold work on assignment - POST
  static String holdWork(int issueId) => '/assignments/$issueId/hold';

  /// Resume work on assignment - POST
  static String resumeWork(int issueId) => '/assignments/$issueId/resume';

  /// Finish work on assignment - POST (multipart)
  static String finishWork(int issueId) => '/assignments/$issueId/finish';

  // =============================================================
  // ADMIN ENDPOINTS
  // =============================================================
  /// Admin dashboard statistics
  static const String adminDashboard = '/admin/dashboard/stats';

  /// List all issues (admin) - paginated
  static const String adminIssues = '/admin/issues';

  /// Get admin issue detail
  static String adminIssueDetail(int id) => '/admin/issues/$id';

  /// Assign issue to service provider - POST
  static String assignIssue(int id) => '/admin/issues/$id/assign';

  /// Approve finished work - POST
  static String approveIssue(int id) => '/admin/issues/$id/approve';

  /// Update issue (admin) - PUT (via POST with _method=PUT for multipart)
  static String updateIssue(int id) => '/admin/issues/$id';

  /// Cancel issue (admin) - POST
  static String adminCancelIssue(int id) => '/admin/issues/$id/cancel';

  /// Update assignment (admin) - PUT
  static String updateAssignment(int issueId, int assignmentId) =>
      '/admin/issues/$issueId/assignments/$assignmentId';

  /// Admin calendar events endpoint - GET
  static const String adminCalendarEvents = '/admin/calendar/events';

  // =============================================================
  // SUPPORTING ENDPOINTS
  // =============================================================
  /// List categories
  static const String categories = '/categories';

  /// List consumables
  static const String consumables = '/consumables';

  /// List service providers (admin only)
  static const String serviceProviders = '/admin/service-providers';

  /// Get SP availability for date
  static String serviceProviderAvailability(int id) =>
      '/admin/service-providers/$id/availability';

  /// Auto-select slots for duration across multiple days
  static String serviceProviderAutoSelectSlots(int id) =>
      '/admin/service-providers/$id/auto-select-slots';

  // =============================================================
  // ADMIN CRUD ENDPOINTS
  // =============================================================
  /// Admin Categories CRUD
  static const String adminCategories = '/admin/categories';
  static String adminCategoryDetail(int id) => '/admin/categories/$id';
  static String adminCategoryToggle(int id) => '/admin/categories/$id/toggle';
  static const String adminCategoryTree = '/admin/categories/tree';
  static String adminCategoryChildren(int id) =>
      '/admin/categories/$id/children';
  static String adminCategoryRestore(int id) => '/admin/categories/$id/restore';
  static String adminCategoryMove(int id) => '/admin/categories/$id/move';

  /// Public Categories (with hierarchy)
  static const String categoryTree = '/categories/tree';
  static String categoryChildren(int id) => '/categories/$id/children';

  /// Admin Consumables CRUD
  static const String adminConsumables = '/admin/consumables';
  static String adminConsumableDetail(int id) => '/admin/consumables/$id';
  static String adminConsumableToggle(int id) =>
      '/admin/consumables/$id/toggle';

  /// Admin Tenants CRUD
  static const String adminTenants = '/admin/tenants';
  static String adminTenantDetail(int id) => '/admin/tenants/$id';
  static String adminTenantToggle(int id) => '/admin/tenants/$id/toggle';

  /// Admin Service Provider detail (list endpoint exists above)
  static String adminServiceProviderDetail(int id) =>
      '/admin/service-providers/$id';
  static String adminServiceProviderToggle(int id) =>
      '/admin/service-providers/$id/toggle';

  // =============================================================
  // TIME EXTENSION ENDPOINTS
  // =============================================================
  /// Request time extension (SP) - POST
  static const String requestExtension = '/time-extensions/request';

  /// Get my extension requests (SP) - GET
  static const String myExtensionRequests = '/time-extensions/my-requests';

  /// List all extension requests (Admin) - GET
  static const String adminExtensions = '/admin/time-extensions';

  /// Approve extension request (Admin) - POST
  static String approveExtension(int id) => '/admin/time-extensions/$id/approve';

  /// Reject extension request (Admin) - POST
  static String rejectExtension(int id) => '/admin/time-extensions/$id/reject';

  // =============================================================
  // SYNC ENDPOINTS
  // =============================================================
  /// Get all master data at once (categories, consumables)
  static const String syncMasterData = '/sync/master-data';

  /// Batch sync multiple operations
  static const String syncBatch = '/sync/batch';

  // =============================================================
  // DEVICE ENDPOINTS (FCM Token Registration)
  // =============================================================
  /// Register FCM device token - POST
  static const String registerDevice = '/devices';

  /// Remove FCM device token - DELETE
  static String removeDevice(String token) => '/devices/$token';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String tokenExpiryKey = 'token_expiry';
  static const String userDataKey = 'user_data';
}
