import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/service_provider_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/work_type_model.dart';
import '../../../data/repositories/admin_issue_repository.dart';
import '../../providers/admin_category_provider.dart';
import '../../providers/admin_issue_provider.dart';
import '../../providers/admin_service_provider_provider.dart';
import '../../providers/work_type_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/shimmer/shimmer.dart';

/// Assign Issue Screen with 4-step flow
/// Step 1: Select Category
/// Step 2: Select Work Type OR Custom Duration
/// Step 3: Select Service Provider
/// Step 4: Schedule (Date + Time Slot)
class AssignIssueScreen extends ConsumerStatefulWidget {
  final String issueId;

  const AssignIssueScreen({super.key, required this.issueId});

  @override
  ConsumerState<AssignIssueScreen> createState() => _AssignIssueScreenState();
}

class _AssignIssueScreenState extends ConsumerState<AssignIssueScreen> {
  int _currentStep = 0;
  int? _selectedCategoryId;
  int? _selectedWorkTypeId;
  int? _allocatedDurationMinutes;
  bool _isCustomDuration = false;
  final _customDurationController = TextEditingController();
  int? _selectedServiceProviderId;
  DateTime _selectedDate = DateTime.now();
  int? _selectedTimeSlotId;
  String? _manualStartTime; // "HH:mm" format
  String? _manualEndTime;   // "HH:mm" format
  final _notesController = TextEditingController();

  // Auto-select results from multi-day API
  List<int>? _autoSelectedSlotIds;
  String? _autoSelectedEndDate;
  bool _hasAutoSelectedSlots = false; // Flag to skip stale availability validation

  // Category search and pagination controllers
  final _categorySearchController = TextEditingController();
  final _categoryScrollController = ScrollController();
  Timer? _categorySearchDebounce;

  // Service provider search and pagination controllers
  final _spSearchController = TextEditingController();
  final _spScrollController = ScrollController();
  Timer? _spSearchDebounce;

  @override
  void initState() {
    super.initState();

    // Initialize scroll listeners
    _categoryScrollController.addListener(_onCategoryScroll);
    _spScrollController.addListener(_onSpScroll);

    // Initialize search listeners
    _categorySearchController.addListener(_onCategorySearchChanged);
    _spSearchController.addListener(_onSpSearchChanged);

    // Initialize category list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminCategoryListProvider.notifier)
        ..filterByActive(true) // Only show active categories
        ..search('') // Clear any previous search
        ..loadCategories();
    });
  }

  @override
  void dispose() {
    // Cancel timers
    _categorySearchDebounce?.cancel();
    _spSearchDebounce?.cancel();

    // Remove listeners
    _categoryScrollController.removeListener(_onCategoryScroll);
    _spScrollController.removeListener(_onSpScroll);
    _categorySearchController.removeListener(_onCategorySearchChanged);
    _spSearchController.removeListener(_onSpSearchChanged);

    // Dispose controllers
    _categoryScrollController.dispose();
    _spScrollController.dispose();
    _categorySearchController.dispose();
    _spSearchController.dispose();
    _customDurationController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  List<DateTime> get _availableDates {
    final now = DateTime.now();
    return List.generate(7, (index) => now.add(Duration(days: index)));
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedCategoryId != null;
      case 1:
        // Can proceed if work type is selected OR custom duration is entered
        return _selectedWorkTypeId != null ||
            (_isCustomDuration &&
             _allocatedDurationMinutes != null &&
             _allocatedDurationMinutes! >= 15);
      case 2:
        return _selectedServiceProviderId != null;
      case 3:
        // Can proceed if time slot selected OR auto-selected slots available
        return _selectedTimeSlotId != null || _autoSelectedSlotIds != null;
      default:
        return false;
    }
  }

  // Scroll listeners for pagination
  void _onCategoryScroll() {
    if (_categoryScrollController.position.pixels >=
        _categoryScrollController.position.maxScrollExtent - 200) {
      ref.read(adminCategoryListProvider.notifier).loadMore();
    }
  }

  void _onSpScroll() {
    if (_spScrollController.position.pixels >=
        _spScrollController.position.maxScrollExtent - 200) {
      ref.read(adminServiceProviderListProvider.notifier).loadMore();
    }
  }

  // Search listeners with debouncing
  void _onCategorySearchChanged() {
    _categorySearchDebounce?.cancel();
    _categorySearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final query = _categorySearchController.text;
        ref.read(adminCategoryListProvider.notifier).search(query);
      }
    });
  }

  void _onSpSearchChanged() {
    _spSearchDebounce?.cancel();
    _spSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final query = _spSearchController.text;
        ref.read(adminServiceProviderListProvider.notifier).search(query);
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);

      // Clear category search when moving to Step 1 (work type selection)
      if (_currentStep == 1) {
        _categorySearchController.clear();
        // Work types will be loaded by provider when step renders
      }
      // Initialize SP list filtered by selected category when moving to Step 2
      else if (_currentStep == 2) {
        // Initialize SP list filtered by selected category
        if (_selectedCategoryId != null) {
          ref.read(adminServiceProviderListProvider.notifier)
            ..filterByCategory(_selectedCategoryId)
            ..filterByActive(true)
            ..search('')
            ..loadServiceProviders();
        }
      } else if (_currentStep == 3) {
        _spSearchController.clear();

        // Auto-select slots when duration is specified
        if (_selectedServiceProviderId != null && _allocatedDurationMinutes != null) {
          _autoSelectSlotsForDuration();
        } else if (_selectedServiceProviderId != null) {
          // Just refresh availability without duration filter
          final availabilityParams = AvailabilityParams(
            serviceProviderId: _selectedServiceProviderId!,
            date: _selectedDate,
            minDurationMinutes: null,
          );
          ref.invalidate(serviceProviderAvailabilityProvider(availabilityParams));
        }
      }
    } else {
      _submitAssignment();
    }
  }

  /// Auto-select time slots across multiple days for the specified duration
  Future<void> _autoSelectSlotsForDuration() async {
    if (_selectedServiceProviderId == null || _allocatedDurationMinutes == null) {
      return;
    }

    try {
      final repository = ref.read(adminIssueRepositoryProvider);
      final result = await repository.autoSelectSlots(
        _selectedServiceProviderId!,
        startDate: _selectedDate,
        durationMinutes: _allocatedDurationMinutes!,
      );

      if (mounted) {
        // Parse the result
        final isSufficient = result['is_sufficient'] as bool? ?? false;
        final accumulatedMinutes = result['accumulated_minutes'] as int? ?? 0;
        final requestedMinutes = result['requested_duration_minutes'] as int? ?? 0;
        final isMultiDay = result['is_multi_day'] as bool? ?? false;
        final spanDays = result['span_days'] as int? ?? 1;
        final timeSlotIds = (result['time_slot_ids'] as List?)?.cast<int>() ?? [];
        final scheduledEndDate = result['end_date'] as String?;
        final assignedStartTime = result['assigned_start_time'] as String?;
        final assignedEndTime = result['assigned_end_time'] as String?;

        // Update state with auto-selected values
        setState(() {
          // For single slot, select it automatically
          if (timeSlotIds.length == 1) {
            _selectedTimeSlotId = timeSlotIds.first;
          }
          // For multi-slot, store but don't auto-select (let user see the breakdown)
          _autoSelectedSlotIds = timeSlotIds;
          _autoSelectedEndDate = scheduledEndDate;
          _manualStartTime = assignedStartTime;
          _manualEndTime = assignedEndTime;
          _hasAutoSelectedSlots = true; // Flag set - skip stale availability checks
        });

        // Show notifications based on result
        if (!isSufficient) {
          final shortfallMinutes = requestedMinutes - accumulatedMinutes;
          final hours = accumulatedMinutes ~/ 60;
          final mins = accumulatedMinutes % 60;
          final durationText = hours > 0 && mins > 0
              ? '$hours h $mins min'
              : hours > 0
                  ? '$hours h'
                  : '$mins min';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could only find $durationText capacity across $spanDays day(s). Need $shortfallMinutes more minutes.',
              ),
              backgroundColor: context.colors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        } else if (isMultiDay) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'admin.assign.spans_days'.tr(namedArgs: {'days': '$spanDays', 'slots': '${timeSlotIds.length}'}),
              ),
              backgroundColor: context.colors.info,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // DON'T refresh availability when auto-select succeeds
        // The multi-day selection is already complete and valid
        // Refreshing with availability provider causes stale single-day validation
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to auto-select slots: ${e.toString()}'),
            backgroundColor: context.colors.error,
          ),
        );

        // Fallback to regular availability
        final availabilityParams = AvailabilityParams(
          serviceProviderId: _selectedServiceProviderId!,
          date: _selectedDate,
          minDurationMinutes: _allocatedDurationMinutes,
        );
        ref.invalidate(serviceProviderAvailabilityProvider(availabilityParams));
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        // Reset dependent selections when going back
        if (_currentStep == 0) {
          _selectedWorkTypeId = null;
          _allocatedDurationMinutes = null;
          _isCustomDuration = false;
          _customDurationController.clear();
          _selectedServiceProviderId = null;
          _selectedTimeSlotId = null;

          // Reset scroll position when returning to category step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_categoryScrollController.hasClients) {
              _categoryScrollController.jumpTo(0);
            }
          });
        } else if (_currentStep == 1) {
          _selectedServiceProviderId = null;
          _selectedTimeSlotId = null;
        } else if (_currentStep == 2) {
          _selectedTimeSlotId = null;
        }
      });
    }
  }

  Future<void> _submitAssignment() async {
    // Validation: Must have service provider and either auto-selected slots or manually selected slot
    if (_selectedServiceProviderId == null ||
        (_autoSelectedSlotIds == null && _selectedTimeSlotId == null)) {
      return;
    }

    // Parse scheduled end date if available
    DateTime? scheduledEndDate;
    if (_autoSelectedEndDate != null) {
      scheduledEndDate = DateTime.tryParse(_autoSelectedEndDate!);
    }

    final success = await ref
        .read(adminIssueActionProvider.notifier)
        .assignIssue(
          int.parse(widget.issueId),
          categoryId: _selectedCategoryId,
          serviceProviderId: _selectedServiceProviderId!,
          workTypeId: _selectedWorkTypeId,
          allocatedDurationMinutes: _allocatedDurationMinutes,
          isCustomDuration: _isCustomDuration,
          scheduledDate: _selectedDate,
          // Multi-slot support: prefer auto-selected slots, fall back to manual selection
          timeSlotId: _autoSelectedSlotIds == null ? _selectedTimeSlotId : null,
          timeSlotIds: _autoSelectedSlotIds,
          scheduledEndDate: scheduledEndDate,
          assignedStartTime: _manualStartTime,
          assignedEndTime: _manualEndTime,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('assign.issue_assigned'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(adminIssueActionProvider).error;
        String errorMessage = 'assign.assign_failed'.tr();

        if (error != null) {
          // Remove status codes (422, 403, etc.) from error messages
          String cleanError = error.replaceAll(RegExp(r'\(status: \d+\)'), '').trim();
          cleanError = cleanError.replaceFirst(RegExp(r'^ApiException: '), '');

          // Handle specific error types
          if (error.contains('status: 403') || error.contains('unauthorized')) {
            errorMessage = 'common.permission_denied'.tr();
          } else if (error.contains('status: 422') || error.contains('validation')) {
            // Validation error (422) - provide user-friendly message
            if (cleanError.toLowerCase().contains('overlap')) {
              errorMessage = 'admin.assign.time_conflict_error'.tr();
            } else if (cleanError.toLowerCase().contains('time')) {
              errorMessage = 'admin.assign.invalid_time_error'.tr();
            } else {
              // Generic validation error
              errorMessage = cleanError.isNotEmpty ? cleanError : 'admin.assign.validation_error'.tr();
            }
          } else if (error.contains('status: 404')) {
            errorMessage = 'common.not_found'.tr();
          } else if (error.contains('status: 500')) {
            errorMessage = 'common.server_error'.tr();
          } else {
            // Use cleaned error message
            errorMessage = cleanError.isNotEmpty ? cleanError : 'assign.assign_failed'.tr();

            // Try to translate if it looks like a translation key
            if (errorMessage.contains('.') && !errorMessage.contains(' ')) {
              try {
                final translated = errorMessage.tr();
                if (translated != errorMessage) {
                  errorMessage = translated;
                }
              } catch (_) {
                // If translation fails, use the original message
              }
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: context.colors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueAsync = ref.watch(
      adminIssueDetailProvider(int.parse(widget.issueId)),
    );
    final actionState = ref.watch(adminIssueActionProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('assign.title'.tr()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: context.colors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: issueAsync.when(
              loading: () => const IssueDetailShimmer(),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: context.colors.error,
                    ),
                    AppSpacing.vGapLg,
                    Text(
                      'errors.load_failed'.tr(),
                      style: context.textTheme.titleMedium,
                    ),
                    AppSpacing.vGapSm,
                    Text(
                      error.toString(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapLg,
                    FilledButton(
                      onPressed: () => ref.invalidate(
                        adminIssueDetailProvider(int.parse(widget.issueId)),
                      ),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
              data: (issue) => _buildContent(issue, actionState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(IssueModel issue, AdminIssueActionState actionState) {
    // Pre-select first category if available and not yet selected
    if (_selectedCategoryId == null && issue.categories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedCategoryId = issue.categories.first.id);
        }
      });
    }

    return Column(
      children: [
        // Issue Summary Card
        Container(
          margin: AppSpacing.allLg,
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: AppRadius.cardRadius,
            boxShadow: context.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: context.priorityColor(issue.priority),
                  borderRadius: AppRadius.allSm,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.title,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      '${issue.tenant?.unitNumber ?? 'N/A'}, ${issue.tenant?.buildingName ?? 'N/A'} • ${issue.priority.label} priority',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Step Indicator
        Padding(
          padding: AppSpacing.horizontalLg,
          child: Row(
            children: [
              _StepIndicator(
                step: 1,
                title: 'assign.category'.tr(),
                isActive: _currentStep == 0,
                isCompleted: _currentStep > 0,
              ),
              Expanded(child: _StepConnector(isActive: _currentStep > 0)),
              _StepIndicator(
                step: 2,
                title: 'assign.work_type'.tr(),
                isActive: _currentStep == 1,
                isCompleted: _currentStep > 1,
              ),
              Expanded(child: _StepConnector(isActive: _currentStep > 1)),
              _StepIndicator(
                step: 3,
                title: 'assign.provider'.tr(),
                isActive: _currentStep == 2,
                isCompleted: _currentStep > 2,
              ),
              Expanded(child: _StepConnector(isActive: _currentStep > 2)),
              _StepIndicator(
                step: 4,
                title: 'assign.schedule'.tr(),
                isActive: _currentStep == 3,
                isCompleted: false,
              ),
            ],
          ),
        ),

        AppSpacing.vGapLg,

        // Step Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStepContent(issue),
          ),
        ),

        // Bottom Navigation
        Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            color: context.colors.card,
            boxShadow: context.bottomNavShadow,
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: actionState.isLoading ? null : _previousStep,
                      child: Text('common.back'.tr()),
                    ),
                  ),
                if (_currentStep > 0) AppSpacing.gapMd,
                Expanded(
                  flex: _currentStep > 0 ? 2 : 1,
                  child: ElevatedButton(
                    onPressed: (_canProceed && !actionState.isLoading)
                        ? _nextStep
                        : null,
                    child: actionState.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.colors.onPrimary,
                              ),
                            ),
                          )
                        : Text(
                            _currentStep == 3
                                ? 'assign.assign_issue'.tr()
                                : 'common.continue'.tr(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(IssueModel issue) {
    return switch (_currentStep) {
      0 => RefreshIndicator(
          onRefresh: _refreshCategoryStep,
          child: _buildCategoryStep(issue),
        ),
      1 => RefreshIndicator(
          onRefresh: _refreshWorkTypeStep,
          child: _buildWorkTypeStep(),
        ),
      2 => RefreshIndicator(
          onRefresh: _refreshProviderStep,
          child: _buildProviderStep(),
        ),
      3 => RefreshIndicator(
          onRefresh: _refreshScheduleStep,
          child: _buildScheduleStep(),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  /// Refresh category list
  Future<void> _refreshCategoryStep() async {
    await ref.read(adminCategoryListProvider.notifier).loadCategories();
  }

  /// Refresh work type list
  Future<void> _refreshWorkTypeStep() async {
    if (_selectedCategoryId != null) {
      ref.invalidate(workTypesForCategoryProvider(_selectedCategoryId!));
    }
  }

  /// Refresh service provider list
  Future<void> _refreshProviderStep() async {
    await ref.read(adminServiceProviderListProvider.notifier).loadServiceProviders();
  }

  /// Refresh availability
  Future<void> _refreshScheduleStep() async {
    if (_selectedServiceProviderId != null && _allocatedDurationMinutes != null) {
      final availabilityParams = AvailabilityParams(
        serviceProviderId: _selectedServiceProviderId!,
        date: _selectedDate,
        minDurationMinutes: _allocatedDurationMinutes,
      );
      ref.invalidate(serviceProviderAvailabilityProvider(availabilityParams));
    }
  }

  Widget _buildCategoryStep(IssueModel issue) {
    final categoryState = ref.watch(adminCategoryListProvider);

    // Initial loading state
    if (categoryState.categories.isEmpty && categoryState.isLoading) {
      return const CategoryGridShimmer();
    }

    // Error state
    if (categoryState.error != null && categoryState.categories.isEmpty) {
      return _buildCategoryErrorState(categoryState.error!);
    }

    // Separate issue categories from paginated results
    final issueCategories = issue.categories;
    final issueCategoryIds = issueCategories.map((c) => c.id).toSet();
    final otherCategories = categoryState.categories
        .where((c) => !issueCategoryIds.contains(c.id))
        .toList();

    return Column(
      key: const ValueKey('category'),
      children: [
        // Search bar
        Padding(
          padding: AppSpacing.horizontalLg,
          child: TextField(
            controller: _categorySearchController,
            decoration: InputDecoration(
              hintText: 'assign.search_categories'.tr(),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _categorySearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _categorySearchController.clear();
                        ref.read(adminCategoryListProvider.notifier).search('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        AppSpacing.vGapMd,

        // Scrollable list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(adminCategoryListProvider.notifier).refresh(),
            child: ListView(
              controller: _categoryScrollController,
              padding: AppSpacing.horizontalLg,
              children: [
                // Title & description
                Text(
                  'assign.select_category'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  'assign.category_desc'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                AppSpacing.vGapLg,

                // Issue categories (always shown first when search is empty)
                if (issueCategories.isNotEmpty &&
                    _categorySearchController.text.isEmpty) ...[
                  Text(
                    'assign.issue_categories'.tr(),
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  AppSpacing.vGapSm,
                  ...issueCategories.map((cat) => _buildCategoryCard(cat)),
                  AppSpacing.vGapLg,
                  Text(
                    'assign.all_categories'.tr(),
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  AppSpacing.vGapSm,
                ],

                // Paginated categories
                ...otherCategories.map((cat) => _buildCategoryCard(cat)),

                // Loading more indicator
                if (categoryState.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // No more data
                if (!categoryState.hasMore &&
                    otherCategories.isNotEmpty &&
                    _categorySearchController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      'common.no_more_data'.tr(),
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),

                // Empty search results
                if (otherCategories.isEmpty &&
                    !categoryState.isLoading &&
                    _categorySearchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: context.colors.textTertiary,
                        ),
                        AppSpacing.vGapMd,
                        Text(
                          'assign.no_categories_found'.tr(),
                          style: context.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryErrorState(String error) {
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: context.colors.error,
            ),
            AppSpacing.vGapLg,
            Text(
              'assign.categories_failed'.tr(),
              style: context.textTheme.titleMedium,
            ),
            AppSpacing.vGapSm,
            Text(
              error,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            FilledButton(
              onPressed: () =>
                  ref.read(adminCategoryListProvider.notifier).loadCategories(),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    final isSelected = _selectedCategoryId == category.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: () => setState(() {
          _selectedCategoryId = category.id;
          // Reset dependent selections
          _selectedWorkTypeId = null;
          _allocatedDurationMinutes = null;
          _isCustomDuration = false;
          _customDurationController.clear();
          _selectedServiceProviderId = null;
          _selectedTimeSlotId = null;
        }),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.1)
                    : context.colors.surfaceVariant,
                borderRadius: AppRadius.allMd,
              ),
              child: Icon(
                _getCategoryIcon(category.iconName),
                color: isSelected
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.nameEn,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    category.nameAr,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: context.colors.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkTypeStep() {
    if (_selectedCategoryId == null) {
      return Center(
        child: Text('assign.select_category_first'.tr()),
      );
    }

    final workTypesAsync = ref.watch(
      workTypesForCategoryProvider(_selectedCategoryId!),
    );

    return workTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildWorkTypeErrorState(error.toString()),
      data: (workTypes) {
        if (workTypes.isEmpty && !_isCustomDuration) {
          return _buildNoWorkTypesState();
        }

        return Column(
          key: const ValueKey('worktype'),
          children: [
            Expanded(
              child: ListView(
                padding: AppSpacing.allLg,
                children: [
                  // Title & description
                  Text(
                    _isCustomDuration
                        ? 'assign.enter_custom_duration'.tr()
                        : 'assign.select_work_type'.tr(),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vGapSm,
                  Text(
                    _isCustomDuration
                        ? 'assign.custom_duration_desc'.tr()
                        : 'assign.work_type_desc'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  AppSpacing.vGapLg,

                  // Custom duration input or work type list
                  if (_isCustomDuration)
                    _buildCustomDurationInput()
                  else ...[
                    // Work types list
                    ...workTypes.map((wt) => _buildWorkTypeCard(wt)),

                    // Custom duration option
                    AppSpacing.vGapMd,
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _isCustomDuration = true;
                        _selectedWorkTypeId = null;
                        _allocatedDurationMinutes = null;
                      }),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text('assign.custom_duration'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkTypeErrorState(String error) {
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: context.colors.error,
            ),
            AppSpacing.vGapLg,
            Text(
              'assign.work_types_failed'.tr(),
              style: context.textTheme.titleMedium,
            ),
            AppSpacing.vGapSm,
            Text(
              error,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            FilledButton(
              onPressed: () => ref.invalidate(
                workTypesForCategoryProvider(_selectedCategoryId!),
              ),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWorkTypesState() {
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_off_rounded,
              size: 64,
              color: context.colors.textTertiary,
            ),
            AppSpacing.vGapMd,
            Text(
              'assign.no_work_types'.tr(),
              style: context.textTheme.titleMedium,
            ),
            AppSpacing.vGapSm,
            Text(
              'assign.no_work_types_desc'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            FilledButton.icon(
              onPressed: () => setState(() => _isCustomDuration = true),
              icon: const Icon(Icons.edit_outlined),
              label: Text('assign.enter_custom_duration'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkTypeCard(WorkTypeModel workType) {
    final isSelected = _selectedWorkTypeId == workType.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: () => setState(() {
          _selectedWorkTypeId = workType.id;
          _allocatedDurationMinutes = workType.durationMinutes;
          _isCustomDuration = false;
          _customDurationController.clear();
          _hasAutoSelectedSlots = false; // Reset auto-select flag
          _autoSelectedSlotIds = null;
          _autoSelectedEndDate = null;
        }),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary.withValues(alpha: 0.1)
                    : context.colors.surfaceVariant,
                borderRadius: AppRadius.allMd,
              ),
              child: Icon(
                Icons.work_outline_rounded,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workType.nameEn,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    workType.formattedDuration,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: context.colors.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDurationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customDurationController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'assign.duration_minutes'.tr(),
            suffixText: 'work_types.minutes'.tr(),
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
            ),
          ),
          onChanged: (value) {
            final minutes = int.tryParse(value);
            setState(() {
              _allocatedDurationMinutes = minutes;
              _hasAutoSelectedSlots = false; // Reset auto-select flag
              _autoSelectedSlotIds = null;
              _autoSelectedEndDate = null;
            });
          },
        ),
        AppSpacing.vGapLg,
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _isCustomDuration = false;
            _customDurationController.clear();
            _allocatedDurationMinutes = null;
          }),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text('assign.back_to_work_types'.tr()),
        ),
      ],
    );
  }

  Widget _buildProviderStep() {
    final spState = ref.watch(adminServiceProviderListProvider);

    // Initial loading
    if (spState.serviceProviders.isEmpty && spState.isLoading) {
      return const ServiceProviderListShimmer();
    }

    // Error state
    if (spState.error != null && spState.serviceProviders.isEmpty) {
      return _buildSpErrorState(spState.error!);
    }

    return Column(
      key: const ValueKey('provider'),
      children: [
        // Search bar
        Padding(
          padding: AppSpacing.horizontalLg,
          child: TextField(
            controller: _spSearchController,
            decoration: InputDecoration(
              hintText: 'assign.search_providers'.tr(),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _spSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _spSearchController.clear();
                        ref
                            .read(adminServiceProviderListProvider.notifier)
                            .search('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        AppSpacing.vGapMd,

        // List with pagination
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(adminServiceProviderListProvider.notifier).refresh(),
            child: ListView(
              controller: _spScrollController,
              padding: AppSpacing.horizontalLg,
              children: [
                // Title
                Text(
                  'assign.select_provider'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  'assign.provider_desc'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                AppSpacing.vGapLg,

                // Service providers list
                ...spState.serviceProviders.map((sp) => _buildProviderCard(sp)),

                // Loading more indicator
                if (spState.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // No more data
                if (!spState.hasMore &&
                    spState.serviceProviders.isNotEmpty &&
                    _spSearchController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      'common.no_more_data'.tr(),
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),

                // Empty search results
                if (spState.serviceProviders.isEmpty &&
                    !spState.isLoading &&
                    _spSearchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: context.colors.textTertiary,
                        ),
                        AppSpacing.vGapMd,
                        Text(
                          'assign.no_providers_found'.tr(),
                          style: context.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),

                // No SPs for category (when not searching)
                if (spState.serviceProviders.isEmpty &&
                    !spState.isLoading &&
                    _spSearchController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          size: 64,
                          color: context.colors.textTertiary,
                        ),
                        AppSpacing.vGapMd,
                        Text(
                          'assign.no_providers_for_category'.tr(),
                          style: context.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpErrorState(String error) {
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: context.colors.error,
            ),
            AppSpacing.vGapLg,
            Text(
              'assign.providers_failed'.tr(),
              style: context.textTheme.titleMedium,
            ),
            AppSpacing.vGapSm,
            Text(
              error,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            FilledButton(
              onPressed: () {
                ref.read(adminServiceProviderListProvider.notifier)
                  ..filterByCategory(_selectedCategoryId)
                  ..loadServiceProviders();
              },
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(ServiceProviderModel provider) {
    final isSelected = _selectedServiceProviderId == provider.id;
    final isAvailable =
        provider.activeJobs < 5; // Consider busy if 5+ active jobs

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: isAvailable
            ? () => setState(() {
                _selectedServiceProviderId = provider.id;
                _selectedTimeSlotId = null; // Reset time slot
                _hasAutoSelectedSlots = false; // Reset auto-select flag
                _autoSelectedSlotIds = null;
                _autoSelectedEndDate = null;
              })
            : null,
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.5,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isSelected
                    ? context.colors.primary.withValues(alpha: 0.1)
                    : context.colors.surfaceVariant,
                backgroundImage: provider.userProfilePhotoUrl != null &&
                        provider.userProfilePhotoUrl!.isNotEmpty
                    ? NetworkImage(provider.userProfilePhotoUrl!)
                    : null,
                child: provider.userProfilePhotoUrl == null ||
                        provider.userProfilePhotoUrl!.isEmpty
                    ? Text(
                        provider.displayName[0].toUpperCase(),
                        style: TextStyle(
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          provider.displayName,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppSpacing.gapSm,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? context.colors.success.withValues(alpha: 0.1)
                                : context.colors.warning.withValues(alpha: 0.1),
                            borderRadius: AppRadius.badgeRadius,
                          ),
                          child: Text(
                            isAvailable
                                ? 'assign.available'.tr()
                                : 'assign.busy'.tr(),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: isAvailable
                                  ? context.colors.success
                                  : context.colors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapXs,
                    Row(
                      children: [
                        if (provider.userEmail != null) ...[
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              provider.userEmail!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (provider.rating != null) ...[
                          const Text(' • '),
                          Icon(
                            Icons.star,
                            size: 14,
                            color: context.colors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            provider.rating!.toStringAsFixed(1),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                        const Text(' • '),
                        Text(
                          'assign.active_jobs'.tr(
                            namedArgs: {'count': '${provider.activeJobs}'},
                          ),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: context.colors.onPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleStep() {
    return ListView(
      key: const ValueKey('schedule'),
      padding: AppSpacing.horizontalLg,
      children: [
        Text(
          'assign.schedule'.tr(),
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapSm,
        Text(
          'assign.schedule_desc'.tr(),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        AppSpacing.vGapLg,

        // Date Selection
        Text(
          'assign.select_date'.tr(),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapMd,
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableDates.length,
            separatorBuilder: (_, __) => AppSpacing.gapMd,
            itemBuilder: (context, index) {
              final date = _availableDates[index];
              final isSelected =
                  _selectedDate.day == date.day &&
                  _selectedDate.month == date.month &&
                  _selectedDate.year == date.year;
              final dayName = [
                'Sun',
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
              ][date.weekday % 7];
              final isToday =
                  date.day == DateTime.now().day &&
                  date.month == DateTime.now().month &&
                  date.year == DateTime.now().year;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                    _selectedTimeSlotId = null; // Reset time slot on date change
                    _hasAutoSelectedSlots = false; // Reset auto-select flag
                    _autoSelectedSlotIds = null;
                    _autoSelectedEndDate = null;
                  });
                  // Re-trigger auto-select if duration is already set
                  if (_allocatedDurationMinutes != null) {
                    _autoSelectSlotsForDuration();
                  }
                },
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.card,
                    borderRadius: AppRadius.allMd,
                    border: Border.all(
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isToday ? 'time.today'.tr() : dayName,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? context.colors.onPrimary
                              : context.colors.textSecondary,
                        ),
                      ),
                      AppSpacing.vGapXs,
                      Text(
                        '${date.day}',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? context.colors.onPrimary
                              : context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        AppSpacing.vGapXl,

        // Time Slot Selection
        Text(
          'assign.select_time'.tr(),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapMd,
        _buildTimeSlotSelection(),

        AppSpacing.vGapLg,

        // Manual time override (permission-based)
        _buildManualTimeOverride(),

        // Notes
        Text(
          'assign.notes_optional'.tr(),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapMd,
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'assign.notes_hint'.tr(),
            border: OutlineInputBorder(borderRadius: AppRadius.inputRadius),
          ),
        ),

        AppSpacing.vGapXxl,
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    if (_selectedServiceProviderId == null) {
      return Text(
        'assign.select_provider_first'.tr(),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      );
    }

    final availabilityParams = AvailabilityParams(
      serviceProviderId: _selectedServiceProviderId!,
      date: _selectedDate,
      minDurationMinutes: _allocatedDurationMinutes,
    );

    final timeSlotsAsync = ref.watch(
      serviceProviderAvailabilityProvider(availabilityParams),
    );

    return timeSlotsAsync.when(
      loading: () => const TimeSlotShimmer(),
      error: (error, _) => Column(
        children: [
          Text(
            'assign.timeslots_failed'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.error,
            ),
          ),
          AppSpacing.vGapMd,
          TextButton(
            onPressed: () => ref.invalidate(
              serviceProviderAvailabilityProvider(availabilityParams),
            ),
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
      data: (timeSlots) {
        // If auto-selection succeeded, show success state instead
        if (_hasAutoSelectedSlots && _autoSelectedSlotIds != null) {
          return Container(
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: context.colors.success.withValues(alpha: 0.1),
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: context.colors.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: context.colors.success,
                      size: 24,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'assign.auto_selected_success'.tr(),
                        style: context.textTheme.titleSmall?.copyWith(
                          color: context.colors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.vGapSm,
                Text(
                  'assign.selected_slots_count'.tr(namedArgs: {
                    'count': _autoSelectedSlotIds!.length.toString(),
                  }),
                  style: context.textTheme.bodyMedium,
                ),
                if (_autoSelectedEndDate != null) ...[
                  AppSpacing.vGapXs,
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 16,
                        color: context.colors.textSecondary,
                      ),
                      AppSpacing.gapXs,
                      Text(
                        'assign.multi_day_range'.tr(namedArgs: {
                          'start': DateFormat('MMM d').format(_selectedDate),
                          'end': DateFormat('MMM d, y').format(
                            DateTime.parse(_autoSelectedEndDate!),
                          ),
                        }),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }

        // Only show "no slots" error if NO auto-selection AND provider returned nothing
        if (timeSlots.isEmpty) {
          // Show appropriate message based on whether duration filter is active
          if (_allocatedDurationMinutes != null) {
            final hours = _allocatedDurationMinutes! ~/ 60;
            final mins = _allocatedDurationMinutes! % 60;
            String durationText = hours > 0 && mins > 0
                ? '${hours}h ${mins}m'
                : hours > 0
                    ? '${hours}h'
                    : '${mins}m';

            return Container(
              padding: AppSpacing.allLg,
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: context.colors.warning),
                      AppSpacing.gapMd,
                      Expanded(
                        child: Text(
                          'assign.no_slots_for_duration'.tr(namedArgs: {
                            'duration': durationText,
                          }),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapSm,
                  Text(
                    'assign.try_shorter_duration'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.1),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.colors.warning),
                AppSpacing.gapMd,
                Expanded(
                  child: Text(
                    'assign.no_timeslots'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.warning,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: timeSlots.map((slot) => _buildTimeSlotCard(slot)).toList(),
        );
      },
    );
  }

  Widget _buildTimeSlotCard(TimeSlotModel slot) {
    final isSelected = _selectedTimeSlotId == slot.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: () => setState(() => _selectedTimeSlotId = slot.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time range header
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.textSecondary,
                ),
                AppSpacing.gapSm,
                Text(
                  slot.formattedRange,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: context.colors.onPrimary,
                    ),
                  ),
              ],
            ),

            // Capacity info (if available)
            if (slot.totalMinutes != null && slot.availableMinutes != null) ...[
              AppSpacing.gapSm,

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (slot.bookedMinutes ?? 0) / (slot.totalMinutes ?? 1),
                  backgroundColor: context.colors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(
                    _getCapacityColor(slot.utilizationPercent ?? 0),
                  ),
                  minHeight: 8,
                ),
              ),

              AppSpacing.gapXs,

              // Capacity text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    slot.capacityDisplay,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getCapacityColor(slot.utilizationPercent ?? 0)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${slot.utilizationPercent ?? 0}%',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: _getCapacityColor(slot.utilizationPercent ?? 0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Next available time
              if (slot.nextAvailableRange != null) ...[
                AppSpacing.gapXs,
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: context.colors.success,
                    ),
                    AppSpacing.gapXs,
                    Text(
                      slot.nextAvailableRange!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.success,
                      ),
                    ),
                  ],
                ),
              ],

              // Show blocked time ranges (if any)
              if (slot.blockedRanges.isNotEmpty) ...[
                AppSpacing.gapMd,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colors.error.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 14,
                            color: context.colors.error,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'admin.assign.blocked_times'.tr(),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: slot.blockedRanges
                            .map((blocked) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${blocked['start']} - ${blocked['end']}',
                                    style: context.textTheme.labelSmall?.copyWith(
                                      color: context.colors.error,
                                      fontSize: 10,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Get color based on utilization percentage
  Color _getCapacityColor(int utilizationPercent) {
    if (utilizationPercent >= 90) return context.colors.error;
    if (utilizationPercent >= 70) return context.colors.warning;
    return context.colors.success;
  }

  IconData _getCategoryIcon(String? icon) {
    return switch (icon) {
      'plumbing' => Icons.plumbing,
      'electrical' => Icons.electrical_services,
      'hvac' => Icons.ac_unit,
      'carpentry' => Icons.carpenter,
      'painting' => Icons.format_paint,
      'general' => Icons.build,
      _ => Icons.category,
    };
  }

  /// Manual time override section (permission-based)
  Widget _buildManualTimeOverride() {
    // Only show if user has permission AND time slot is selected
    final currentUser = ref.watch(currentUserProvider);
    final hasPermission = currentUser?.hasPermission('override_work_type_duration') ?? false;

    if (!hasPermission || _selectedTimeSlotId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'admin.assign.manual_time_override'.tr(),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapSm,
        Text(
          'admin.assign.manual_time_hint'.tr(),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        AppSpacing.vGapMd,

        Row(
          children: [
            // Start time picker
            Expanded(
              child: InkWell(
                onTap: _pickStartTime,
                borderRadius: AppRadius.inputRadius,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'admin.assign.start_time'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                    suffixIcon: const Icon(Icons.access_time_rounded),
                  ),
                  child: Text(
                    _manualStartTime ?? 'admin.assign.auto'.tr(),
                    style: _manualStartTime == null
                        ? context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                            fontStyle: FontStyle.italic,
                          )
                        : context.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // End time picker
            Expanded(
              child: InkWell(
                onTap: _pickEndTime,
                borderRadius: AppRadius.inputRadius,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'admin.assign.end_time'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                    suffixIcon: const Icon(Icons.access_time_rounded),
                  ),
                  child: Text(
                    _manualEndTime ?? 'admin.assign.auto'.tr(),
                    style: _manualEndTime == null
                        ? context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                            fontStyle: FontStyle.italic,
                          )
                        : context.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Clear button
        if (_manualStartTime != null || _manualEndTime != null) ...[
          AppSpacing.vGapSm,
          TextButton.icon(
            icon: const Icon(Icons.clear_rounded),
            label: Text('admin.assign.clear_manual_time'.tr()),
            onPressed: () {
              setState(() {
                _manualStartTime = null;
                _manualEndTime = null;
              });
            },
          ),
        ],

        // Overlap warning (check if manual time conflicts with blocked ranges)
        if (_manualStartTime != null && _manualEndTime != null) ...[
          AppSpacing.vGapMd,
          _buildOverlapWarning(),
        ],

        AppSpacing.vGapLg,
      ],
    );
  }

  /// Build overlap warning if manual time conflicts with existing assignments
  Widget _buildOverlapWarning() {
    // Get selected time slot to check for overlaps
    if (_selectedServiceProviderId == null) return const SizedBox.shrink();

    final availabilityParams = AvailabilityParams(
      serviceProviderId: _selectedServiceProviderId!,
      date: _selectedDate,
      minDurationMinutes: _allocatedDurationMinutes,
    );

    final timeSlotsAsync = ref.watch(
      serviceProviderAvailabilityProvider(availabilityParams),
    );

    return timeSlotsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (timeSlots) {
        // Find the selected slot
        final selectedSlot = timeSlots.firstWhere(
          (slot) => slot.id == _selectedTimeSlotId,
          orElse: () => timeSlots.first,
        );

        // Check if manual time would overlap
        final wouldOverlap = selectedSlot.wouldOverlap(
          _manualStartTime!,
          _manualEndTime!,
        );

        if (!wouldOverlap) {
          // No overlap - show success message
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.colors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: context.colors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'admin.assign.time_available'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.success,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Overlap detected - show error warning
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 20,
                color: context.colors.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.assign.time_overlap_warning'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'admin.assign.time_overlap_hint'.tr(),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.error.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pick manual start time
  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _manualStartTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        // Auto-calculate end time from duration if available
        if (_allocatedDurationMinutes != null) {
          final totalMinutes = time.hour * 60 + time.minute + _allocatedDurationMinutes!;
          final endHour = (totalMinutes ~/ 60) % 24;
          final endMin = totalMinutes % 60;
          _manualEndTime = '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
        }
      });
    }
  }

  /// Pick manual end time
  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _manualEndTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }
}

/// Selectable card widget
class _SelectableCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;

  const _SelectableCard({
    required this.isSelected,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? context.colors.primary.withValues(alpha: 0.05)
          : context.colors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: isSelected ? context.colors.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: context.cardShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Step indicator widget
class _StepIndicator extends StatelessWidget {
  final int step;
  final String title;
  final bool isActive;
  final bool isCompleted;

  const _StepIndicator({
    required this.step,
    required this.title,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? context.colors.success
        : isActive
        ? context.colors.primary
        : context.colors.textTertiary;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 18, color: context.colors.onPrimary)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? context.colors.onPrimary : color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        AppSpacing.vGapXs,
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isActive || isCompleted
                ? context.colors.textPrimary
                : context.colors.textTertiary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Step connector line
class _StepConnector extends StatelessWidget {
  final bool isActive;

  const _StepConnector({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? context.colors.success : context.colors.border,
    );
  }
}
