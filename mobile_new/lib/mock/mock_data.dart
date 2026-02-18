import '../data/models/models.dart';
import '../domain/enums/enums.dart';

/// Mock data for development and testing
/// Provides realistic sample data matching Laravel backend structure
class MockData {
  MockData._();

  // =============================================================
  // CATEGORIES (Master Data)
  // =============================================================

  static final List<CategoryModel> categories = [
    const CategoryModel(
      id: 1,
      nameEn: 'Plumbing',
      nameAr: 'السباكة',
      icon: 'plumbing',
    ),
    const CategoryModel(
      id: 2,
      nameEn: 'Electrical',
      nameAr: 'الكهرباء',
      icon: 'electrical',
    ),
    const CategoryModel(
      id: 3,
      nameEn: 'HVAC',
      nameAr: 'التكييف',
      icon: 'hvac',
    ),
    const CategoryModel(
      id: 4,
      nameEn: 'Carpentry',
      nameAr: 'النجارة',
      icon: 'carpentry',
    ),
    const CategoryModel(
      id: 5,
      nameEn: 'Painting',
      nameAr: 'الدهان',
      icon: 'painting',
    ),
    const CategoryModel(
      id: 6,
      nameEn: 'General',
      nameAr: 'عام',
      icon: 'general',
    ),
  ];

  // =============================================================
  // CONSUMABLES (Master Data by Category)
  // =============================================================

  static final Map<int, List<ConsumableModel>> consumablesByCategory = {
    1: [
      // Plumbing
      const ConsumableModel(id: 1, categoryId: 1, nameEn: 'PVC Pipe (meter)', nameAr: 'أنبوب PVC (متر)'),
      const ConsumableModel(id: 2, categoryId: 1, nameEn: 'Tap/Faucet', nameAr: 'صنبور'),
      const ConsumableModel(id: 3, categoryId: 1, nameEn: 'Valve', nameAr: 'صمام'),
      const ConsumableModel(id: 4, categoryId: 1, nameEn: 'Seal Ring', nameAr: 'حلقة مانعة للتسرب'),
      const ConsumableModel(id: 5, categoryId: 1, nameEn: 'Drain Pipe', nameAr: 'أنبوب صرف'),
      const ConsumableModel(id: 6, categoryId: 1, nameEn: 'Water Heater Element', nameAr: 'سخان مياه'),
    ],
    2: [
      // Electrical
      const ConsumableModel(id: 7, categoryId: 2, nameEn: 'Wire (meter)', nameAr: 'سلك (متر)'),
      const ConsumableModel(id: 8, categoryId: 2, nameEn: 'Switch', nameAr: 'مفتاح'),
      const ConsumableModel(id: 9, categoryId: 2, nameEn: 'Socket', nameAr: 'مقبس'),
      const ConsumableModel(id: 10, categoryId: 2, nameEn: 'Circuit Breaker', nameAr: 'قاطع دارة'),
      const ConsumableModel(id: 11, categoryId: 2, nameEn: 'Light Bulb', nameAr: 'لمبة'),
      const ConsumableModel(id: 12, categoryId: 2, nameEn: 'Light Fixture', nameAr: 'مصباح'),
    ],
    3: [
      // HVAC
      const ConsumableModel(id: 13, categoryId: 3, nameEn: 'AC Filter', nameAr: 'فلتر مكيف'),
      const ConsumableModel(id: 14, categoryId: 3, nameEn: 'Refrigerant (kg)', nameAr: 'غاز تبريد (كجم)'),
      const ConsumableModel(id: 15, categoryId: 3, nameEn: 'Thermostat', nameAr: 'ثرموستات'),
      const ConsumableModel(id: 16, categoryId: 3, nameEn: 'Fan Motor', nameAr: 'موتور مروحة'),
      const ConsumableModel(id: 17, categoryId: 3, nameEn: 'Compressor', nameAr: 'ضاغط'),
    ],
    4: [
      // Carpentry
      const ConsumableModel(id: 18, categoryId: 4, nameEn: 'Wood Plank', nameAr: 'لوح خشب'),
      const ConsumableModel(id: 19, categoryId: 4, nameEn: 'Door Hinge', nameAr: 'مفصلة باب'),
      const ConsumableModel(id: 20, categoryId: 4, nameEn: 'Door Lock', nameAr: 'قفل باب'),
      const ConsumableModel(id: 21, categoryId: 4, nameEn: 'Wood Screws (pack)', nameAr: 'براغي خشب (علبة)'),
    ],
    5: [
      // Painting
      const ConsumableModel(id: 22, categoryId: 5, nameEn: 'Paint (liter)', nameAr: 'طلاء (لتر)'),
      const ConsumableModel(id: 23, categoryId: 5, nameEn: 'Primer (liter)', nameAr: 'أساس (لتر)'),
      const ConsumableModel(id: 24, categoryId: 5, nameEn: 'Paint Brush', nameAr: 'فرشاة طلاء'),
      const ConsumableModel(id: 25, categoryId: 5, nameEn: 'Roller', nameAr: 'رولة'),
    ],
    6: [
      // General
      const ConsumableModel(id: 26, categoryId: 6, nameEn: 'Cleaning Supplies', nameAr: 'مواد تنظيف'),
      const ConsumableModel(id: 27, categoryId: 6, nameEn: 'Sealant', nameAr: 'مادة لاصقة'),
    ],
  };

  static List<ConsumableModel> get allConsumables =>
      consumablesByCategory.values.expand((list) => list).toList();

  // =============================================================
  // TIME SLOTS
  // =============================================================

  static final List<TimeSlotModel> timeSlots = [
    const TimeSlotModel(id: 1, serviceProviderId: 10, dayOfWeek: 0, startTime: '09:00', endTime: '12:00'),
    const TimeSlotModel(id: 2, serviceProviderId: 10, dayOfWeek: 1, startTime: '09:00', endTime: '12:00'),
    const TimeSlotModel(id: 3, serviceProviderId: 10, dayOfWeek: 1, startTime: '14:00', endTime: '17:00'),
    const TimeSlotModel(id: 4, serviceProviderId: 10, dayOfWeek: 2, startTime: '09:00', endTime: '12:00'),
    const TimeSlotModel(id: 5, serviceProviderId: 10, dayOfWeek: 3, startTime: '09:00', endTime: '12:00'),
    const TimeSlotModel(id: 6, serviceProviderId: 10, dayOfWeek: 4, startTime: '09:00', endTime: '12:00'),
    const TimeSlotModel(id: 7, serviceProviderId: 10, dayOfWeek: 4, startTime: '14:00', endTime: '17:00'),
  ];

  // =============================================================
  // USERS (Demo Accounts)
  // =============================================================

  /// Demo tenant user
  static final UserModel tenantUser = UserModel(
    id: 1,
    name: 'Mohammed Al-Ahmed',
    email: 'mohammed@example.com',
    phone: '+971501234567',
    locale: 'en',
    isActive: true,
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
    tenant: const TenantModel(
      id: 1,
      userId: 1,
      unitNumber: '301',
      buildingName: 'Building A',
    ),
  );

  /// Demo service provider user
  static final UserModel serviceProviderUser = UserModel(
    id: 10,
    name: 'Ahmed Hassan',
    email: 'ahmed.sp@example.com',
    phone: '+971509876543',
    locale: 'en',
    isActive: true,
    createdAt: DateTime.now().subtract(const Duration(days: 180)),
    serviceProvider: ServiceProviderModel(
      id: 1,
      userId: 10,
      categoryIds: const [1],
      latitude: 25.2048,
      longitude: 55.2708,
      isAvailable: true,
      categories: [categories.first],
      timeSlots: timeSlots,
    ),
  );

  /// Demo super admin user
  static final UserModel superAdminUser = UserModel(
    id: 100,
    name: 'Super Admin',
    email: 'superadmin@facility.com',
    phone: '+971501111111',
    locale: 'en',
    isActive: true,
    role: UserRole.superAdmin,
    createdAt: DateTime.now().subtract(const Duration(days: 365)),
  );

  /// Demo manager user
  static final UserModel managerUser = UserModel(
    id: 101,
    name: 'Manager',
    email: 'manager@facility.com',
    phone: '+971502222222',
    locale: 'en',
    isActive: true,
    role: UserRole.manager,
    createdAt: DateTime.now().subtract(const Duration(days: 200)),
  );

  /// Demo viewer user
  static final UserModel viewerUser = UserModel(
    id: 102,
    name: 'Viewer',
    email: 'viewer@facility.com',
    phone: '+971503333333',
    locale: 'en',
    isActive: true,
    role: UserRole.viewer,
    createdAt: DateTime.now().subtract(const Duration(days: 100)),
  );

  // =============================================================
  // BUILDINGS
  // =============================================================

  static const List<String> buildings = [
    'Building A',
    'Building B',
    'Building C',
    'Villa Block D',
    'Villa Block E',
  ];

  // =============================================================
  // TENANTS LIST (For Admin View)
  // =============================================================

  static List<UserModel> get tenants => [
    tenantUser, // Already defined demo tenant
    UserModel(
      id: 2,
      name: 'Fatima Al-Rashid',
      email: 'fatima.rashid@example.com',
      phone: '+971502345678',
      locale: 'ar',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      tenant: const TenantModel(
        id: 2,
        userId: 2,
        unitNumber: '102',
        buildingName: 'Building A',
      ),
    ),
    UserModel(
      id: 3,
      name: 'Omar Khalil',
      email: 'omar.khalil@example.com',
      phone: '+971503456789',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 85)),
      tenant: const TenantModel(
        id: 3,
        userId: 3,
        unitNumber: '205',
        buildingName: 'Building B',
      ),
    ),
    UserModel(
      id: 4,
      name: 'Sara Abdullah',
      email: 'sara.abdullah@example.com',
      phone: '+971504567890',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      tenant: const TenantModel(
        id: 4,
        userId: 4,
        unitNumber: '410',
        buildingName: 'Building B',
      ),
    ),
    UserModel(
      id: 5,
      name: 'Khalid Hassan',
      email: 'khalid.hassan@example.com',
      phone: '+971505678901',
      locale: 'ar',
      isActive: false, // Inactive tenant
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
      tenant: const TenantModel(
        id: 5,
        userId: 5,
        unitNumber: '103',
        buildingName: 'Building C',
      ),
    ),
    UserModel(
      id: 6,
      name: 'Layla Mohamed',
      email: 'layla.m@example.com',
      phone: '+971506789012',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      tenant: const TenantModel(
        id: 6,
        userId: 6,
        unitNumber: 'V12',
        buildingName: 'Villa Block D',
      ),
    ),
    UserModel(
      id: 7,
      name: 'Yusuf Al-Farsi',
      email: 'yusuf.farsi@example.com',
      phone: '+971507890123',
      locale: 'ar',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      tenant: const TenantModel(
        id: 7,
        userId: 7,
        unitNumber: '508',
        buildingName: 'Building A',
      ),
    ),
    UserModel(
      id: 8,
      name: 'Mariam Said',
      email: 'mariam.said@example.com',
      phone: '+971508901234',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      tenant: const TenantModel(
        id: 8,
        userId: 8,
        unitNumber: 'V05',
        buildingName: 'Villa Block E',
      ),
    ),
  ];

  // =============================================================
  // SERVICE PROVIDERS LIST (For Admin View)
  // =============================================================

  static List<UserModel> get serviceProviders => [
    serviceProviderUser, // Already defined demo SP (Plumbing)
    UserModel(
      id: 11,
      name: 'Ali Mahmoud',
      email: 'ali.m@example.com',
      phone: '+971509111222',
      locale: 'ar',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 150)),
      serviceProvider: ServiceProviderModel(
        id: 2,
        userId: 11,
        categoryIds: const [2], // Electrical
        latitude: 25.2100,
        longitude: 55.2750,
        isAvailable: true,
        categories: [categories[1]],
        timeSlots: const [
          TimeSlotModel(id: 10, serviceProviderId: 11, dayOfWeek: 0, startTime: '08:00', endTime: '12:00'),
          TimeSlotModel(id: 11, serviceProviderId: 11, dayOfWeek: 1, startTime: '08:00', endTime: '12:00'),
          TimeSlotModel(id: 12, serviceProviderId: 11, dayOfWeek: 2, startTime: '08:00', endTime: '12:00'),
          TimeSlotModel(id: 13, serviceProviderId: 11, dayOfWeek: 3, startTime: '08:00', endTime: '12:00'),
          TimeSlotModel(id: 14, serviceProviderId: 11, dayOfWeek: 4, startTime: '08:00', endTime: '12:00'),
        ],
      ),
    ),
    UserModel(
      id: 12,
      name: 'Rashid Al-Mansoori',
      email: 'rashid.mansoori@example.com',
      phone: '+971509222333',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 100)),
      serviceProvider: ServiceProviderModel(
        id: 3,
        userId: 12,
        categoryIds: const [3], // HVAC
        latitude: 25.1980,
        longitude: 55.2680,
        isAvailable: true,
        categories: [categories[2]],
        timeSlots: const [
          TimeSlotModel(id: 20, serviceProviderId: 12, dayOfWeek: 0, startTime: '09:00', endTime: '17:00'),
          TimeSlotModel(id: 21, serviceProviderId: 12, dayOfWeek: 1, startTime: '09:00', endTime: '17:00'),
          TimeSlotModel(id: 22, serviceProviderId: 12, dayOfWeek: 2, startTime: '09:00', endTime: '17:00'),
          TimeSlotModel(id: 23, serviceProviderId: 12, dayOfWeek: 3, startTime: '09:00', endTime: '17:00'),
          TimeSlotModel(id: 24, serviceProviderId: 12, dayOfWeek: 4, startTime: '09:00', endTime: '17:00'),
        ],
      ),
    ),
    UserModel(
      id: 13,
      name: 'Hassan Noor',
      email: 'hassan.noor@example.com',
      phone: '+971509333444',
      locale: 'ar',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 80)),
      serviceProvider: ServiceProviderModel(
        id: 4,
        userId: 13,
        categoryIds: const [4], // Carpentry
        latitude: 25.2020,
        longitude: 55.2720,
        isAvailable: false, // Currently busy
        categories: [categories[3]],
        timeSlots: const [
          TimeSlotModel(id: 30, serviceProviderId: 13, dayOfWeek: 0, startTime: '10:00', endTime: '14:00'),
          TimeSlotModel(id: 31, serviceProviderId: 13, dayOfWeek: 2, startTime: '10:00', endTime: '14:00'),
          TimeSlotModel(id: 32, serviceProviderId: 13, dayOfWeek: 4, startTime: '10:00', endTime: '14:00'),
        ],
      ),
    ),
    UserModel(
      id: 14,
      name: 'Samir Youssef',
      email: 'samir.y@example.com',
      phone: '+971509444555',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      serviceProvider: ServiceProviderModel(
        id: 5,
        userId: 14,
        categoryIds: const [5], // Painting
        latitude: 25.2060,
        longitude: 55.2740,
        isAvailable: true,
        categories: [categories[4]],
        timeSlots: const [
          TimeSlotModel(id: 40, serviceProviderId: 14, dayOfWeek: 1, startTime: '07:00', endTime: '15:00'),
          TimeSlotModel(id: 41, serviceProviderId: 14, dayOfWeek: 2, startTime: '07:00', endTime: '15:00'),
          TimeSlotModel(id: 42, serviceProviderId: 14, dayOfWeek: 3, startTime: '07:00', endTime: '15:00'),
        ],
      ),
    ),
    UserModel(
      id: 15,
      name: 'Ibrahim Zayed',
      email: 'ibrahim.z@example.com',
      phone: '+971509555666',
      locale: 'ar',
      isActive: false, // Inactive SP
      createdAt: DateTime.now().subtract(const Duration(days: 300)),
      serviceProvider: ServiceProviderModel(
        id: 6,
        userId: 15,
        categoryIds: const [1], // Plumbing (another plumber)
        latitude: 25.2030,
        longitude: 55.2700,
        isAvailable: false,
        categories: [categories[0]],
        timeSlots: const [],
      ),
    ),
    UserModel(
      id: 16,
      name: 'Nasser Al-Qasimi',
      email: 'nasser.q@example.com',
      phone: '+971509666777',
      locale: 'en',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
      serviceProvider: ServiceProviderModel(
        id: 7,
        userId: 16,
        categoryIds: const [6], // General
        latitude: 25.2040,
        longitude: 55.2690,
        isAvailable: true,
        categories: [categories[5]],
        timeSlots: const [
          TimeSlotModel(id: 50, serviceProviderId: 16, dayOfWeek: 0, startTime: '08:00', endTime: '16:00'),
          TimeSlotModel(id: 51, serviceProviderId: 16, dayOfWeek: 1, startTime: '08:00', endTime: '16:00'),
          TimeSlotModel(id: 52, serviceProviderId: 16, dayOfWeek: 2, startTime: '08:00', endTime: '16:00'),
          TimeSlotModel(id: 53, serviceProviderId: 16, dayOfWeek: 3, startTime: '08:00', endTime: '16:00'),
          TimeSlotModel(id: 54, serviceProviderId: 16, dayOfWeek: 4, startTime: '08:00', endTime: '16:00'),
          TimeSlotModel(id: 55, serviceProviderId: 16, dayOfWeek: 5, startTime: '08:00', endTime: '12:00'),
        ],
      ),
    ),
  ];

  // =============================================================
  // ADMIN USERS LIST (For Super Admin View)
  // =============================================================

  static List<UserModel> get adminUsers => [
    superAdminUser,
    managerUser,
    viewerUser,
  ];

  // =============================================================
  // ISSUES (Sample Data)
  // =============================================================

  static List<IssueModel> get issues => [
    // Pending issue
    IssueModel(
      id: 1,
      tenantId: 1,
      title: 'Water leak in bathroom',
      description: 'There is a water leak under the bathroom sink. Water is dripping constantly and needs immediate attention.',
      status: IssueStatus.pending,
      priority: IssuePriority.high,
      latitude: 25.2048,
      longitude: 55.2708,
      proofRequired: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      tenant: tenantUser.tenant,
      categories: [categories[0]], // Plumbing
      media: [],
      timeline: [
        TimelineModel(
          id: 1,
          issueId: 1,
          action: TimelineAction.created,
          performedBy: 1,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          performedByUser: tenantUser,
        ),
      ],
    ),

    // Assigned issue
    IssueModel(
      id: 2,
      tenantId: 1,
      title: 'AC not cooling properly',
      description: 'The air conditioner in the living room is not cooling. It makes a strange noise when turned on.',
      status: IssueStatus.assigned,
      priority: IssuePriority.medium,
      latitude: 25.2052,
      longitude: 55.2712,
      proofRequired: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      tenant: tenantUser.tenant,
      categories: [categories[2]], // HVAC
      assignments: [
        AssignmentModel(
          id: 1,
          issueId: 2,
          serviceProviderId: 10,
          categoryId: 3,
          scheduledDate: DateTime.now().add(const Duration(hours: 2)),
          status: AssignmentStatus.assigned,
          proofRequired: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          category: categories[2],
          timeSlot: timeSlots[0],
          issueTitle: 'AC not cooling properly',
          tenantUnit: '301',
          tenantBuilding: 'Building A',
          latitude: 25.2052,
          longitude: 55.2712,
        ),
      ],
      timeline: [
        TimelineModel(
          id: 2,
          issueId: 2,
          action: TimelineAction.created,
          performedBy: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          performedByUser: tenantUser,
        ),
        TimelineModel(
          id: 3,
          issueId: 2,
          action: TimelineAction.assigned,
          performedBy: 100, // Admin
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
      ],
    ),

    // In Progress issue
    IssueModel(
      id: 3,
      tenantId: 1,
      title: 'Electrical outlet not working',
      description: 'The electrical outlet in the bedroom stopped working. I tried multiple devices but none of them work.',
      status: IssueStatus.inProgress,
      priority: IssuePriority.medium,
      latitude: 25.2045,
      longitude: 55.2705,
      proofRequired: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      tenant: tenantUser.tenant,
      categories: [categories[1]], // Electrical
      assignments: [
        AssignmentModel(
          id: 2,
          issueId: 3,
          serviceProviderId: 10,
          categoryId: 2,
          scheduledDate: DateTime.now(),
          status: AssignmentStatus.inProgress,
          proofRequired: true,
          startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          category: categories[1],
          timeSlot: timeSlots[1],
          issueTitle: 'Electrical outlet not working',
          tenantUnit: '301',
          tenantBuilding: 'Building A',
          latitude: 25.2045,
          longitude: 55.2705,
        ),
      ],
      timeline: [
        TimelineModel(
          id: 4,
          issueId: 3,
          action: TimelineAction.created,
          performedBy: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          performedByUser: tenantUser,
        ),
        TimelineModel(
          id: 5,
          issueId: 3,
          action: TimelineAction.assigned,
          performedBy: 100,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        TimelineModel(
          id: 6,
          issueId: 3,
          action: TimelineAction.started,
          performedBy: 10,
          createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
          performedByUser: serviceProviderUser,
        ),
      ],
    ),

    // Finished issue (awaiting approval)
    IssueModel(
      id: 4,
      tenantId: 1,
      title: 'Kitchen sink clogged',
      description: 'The kitchen sink is completely clogged. Water does not drain at all.',
      status: IssueStatus.finished,
      priority: IssuePriority.high,
      latitude: 25.2050,
      longitude: 55.2710,
      proofRequired: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      tenant: tenantUser.tenant,
      categories: [categories[0]], // Plumbing
      assignments: [
        AssignmentModel(
          id: 3,
          issueId: 4,
          serviceProviderId: 10,
          categoryId: 1,
          scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
          status: AssignmentStatus.finished,
          proofRequired: true,
          startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          finishedAt: DateTime.now().subtract(const Duration(days: 1)),
          notes: 'Cleared the clog and replaced the drain pipe section.',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          category: categories[0],
          issueTitle: 'Kitchen sink clogged',
          tenantUnit: '301',
          tenantBuilding: 'Building A',
        ),
      ],
      timeline: [
        TimelineModel(
          id: 7,
          issueId: 4,
          action: TimelineAction.created,
          performedBy: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          performedByUser: tenantUser,
        ),
        TimelineModel(
          id: 8,
          issueId: 4,
          action: TimelineAction.assigned,
          performedBy: 100,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        TimelineModel(
          id: 9,
          issueId: 4,
          action: TimelineAction.started,
          performedBy: 10,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          performedByUser: serviceProviderUser,
        ),
        TimelineModel(
          id: 10,
          issueId: 4,
          action: TimelineAction.finished,
          performedBy: 10,
          notes: 'Cleared the clog and replaced the drain pipe section.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          performedByUser: serviceProviderUser,
        ),
      ],
    ),

    // Completed issue
    IssueModel(
      id: 5,
      tenantId: 1,
      title: 'Door lock is broken',
      description: 'The main door lock is broken and the door cannot be properly secured.',
      status: IssueStatus.completed,
      priority: IssuePriority.high,
      latitude: 25.2048,
      longitude: 55.2708,
      proofRequired: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      tenant: tenantUser.tenant,
      categories: [categories[3]], // Carpentry
      assignments: [
        AssignmentModel(
          id: 4,
          issueId: 5,
          serviceProviderId: 10,
          categoryId: 4,
          scheduledDate: DateTime.now().subtract(const Duration(days: 5)),
          status: AssignmentStatus.completed,
          proofRequired: true,
          startedAt: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
          finishedAt: DateTime.now().subtract(const Duration(days: 5, hours: 1)),
          completedAt: DateTime.now().subtract(const Duration(days: 5)),
          notes: 'Replaced the door lock with a new one.',
          createdAt: DateTime.now().subtract(const Duration(days: 6)),
          category: categories[3],
          issueTitle: 'Door lock is broken',
          tenantUnit: '301',
          tenantBuilding: 'Building A',
        ),
      ],
      timeline: [
        TimelineModel(
          id: 11,
          issueId: 5,
          action: TimelineAction.created,
          performedBy: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          performedByUser: tenantUser,
        ),
        TimelineModel(
          id: 12,
          issueId: 5,
          action: TimelineAction.assigned,
          performedBy: 100,
          createdAt: DateTime.now().subtract(const Duration(days: 6)),
        ),
        TimelineModel(
          id: 13,
          issueId: 5,
          action: TimelineAction.started,
          performedBy: 10,
          createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
          performedByUser: serviceProviderUser,
        ),
        TimelineModel(
          id: 14,
          issueId: 5,
          action: TimelineAction.finished,
          performedBy: 10,
          createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 1)),
          performedByUser: serviceProviderUser,
        ),
        TimelineModel(
          id: 15,
          issueId: 5,
          action: TimelineAction.approved,
          performedBy: 100,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ],
    ),
  ];

  // =============================================================
  // ASSIGNMENTS (For Service Provider View)
  // =============================================================

  static List<AssignmentModel> get assignments => issues
      .expand((issue) => issue.assignments)
      .toList();

  /// Get today's assignments for service provider
  static List<AssignmentModel> get todaysAssignments => assignments
      .where((a) => a.isScheduledToday)
      .toList();

  /// Get pending assignments
  static List<AssignmentModel> get pendingAssignments => assignments
      .where((a) => a.status == AssignmentStatus.assigned)
      .toList();

  /// Get in-progress assignments
  static List<AssignmentModel> get inProgressAssignments => assignments
      .where((a) => a.status == AssignmentStatus.inProgress)
      .toList();

  /// Get completed assignments
  static List<AssignmentModel> get completedAssignments => assignments
      .where((a) => a.status == AssignmentStatus.completed)
      .toList();

  // =============================================================
  // HELPER METHODS
  // =============================================================

  /// Get consumables for a specific category
  static List<ConsumableModel> getConsumablesForCategory(int categoryId) =>
      consumablesByCategory[categoryId] ?? [];

  /// Get category by ID
  static CategoryModel? getCategoryById(int id) =>
      categories.where((c) => c.id == id).firstOrNull;

  /// Get issue by ID
  static IssueModel? getIssueById(int id) =>
      issues.where((i) => i.id == id).firstOrNull;

  /// Get assignment by ID
  static AssignmentModel? getAssignmentById(int id) =>
      assignments.where((a) => a.id == id).firstOrNull;

  /// Get tenant by ID
  static UserModel? getTenantById(int id) =>
      tenants.where((t) => t.id == id).firstOrNull;

  /// Get service provider by ID
  static UserModel? getServiceProviderById(int id) =>
      serviceProviders.where((sp) => sp.id == id).firstOrNull;

  /// Get admin user by ID
  static UserModel? getAdminUserById(int id) =>
      adminUsers.where((a) => a.id == id).firstOrNull;

  /// Get active tenants
  static List<UserModel> get activeTenants =>
      tenants.where((t) => t.isActive).toList();

  /// Get inactive tenants
  static List<UserModel> get inactiveTenants =>
      tenants.where((t) => !t.isActive).toList();

  /// Get active service providers
  static List<UserModel> get activeServiceProviders =>
      serviceProviders.where((sp) => sp.isActive).toList();

  /// Get available service providers
  static List<UserModel> get availableServiceProviders =>
      serviceProviders.where((sp) => sp.isActive && (sp.serviceProvider?.isAvailable ?? false)).toList();

  /// Get service providers by category
  static List<UserModel> getServiceProvidersByCategory(int categoryId) =>
      serviceProviders.where((sp) => sp.serviceProvider?.categoryIds.contains(categoryId) ?? false).toList();

  /// Get issue count for tenant
  static int getIssueCountForTenant(int tenantId) =>
      issues.where((i) => i.tenantId == tenantId).length;

  /// Get active issue count for service provider
  static int getActiveIssueCountForSP(int spId) =>
      assignments.where((a) =>
          a.serviceProviderId == spId &&
          (a.status == AssignmentStatus.assigned || a.status == AssignmentStatus.inProgress)
      ).length;
}
