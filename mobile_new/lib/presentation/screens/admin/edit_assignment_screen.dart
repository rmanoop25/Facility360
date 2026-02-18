import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/assignment_model.dart';
import '../../../data/models/service_provider_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/work_type_model.dart';
import '../../../data/repositories/admin_issue_repository.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/admin_issue_provider.dart';
import '../../providers/admin_service_provider_provider.dart';
import '../../providers/work_type_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/shimmer/shimmer.dart';

/// Edit Assignment Screen for admin
/// Allows editing service provider, work type, duration, scheduled date, time slots, and notes
/// Supports multi-day and multi-slot assignments
/// Only available for assignments with status == ASSIGNED (work not started)
class EditAssignmentScreen extends ConsumerStatefulWidget {
  final String issueId;
  final String assignmentId;

  const EditAssignmentScreen({
    super.key,
    required this.issueId,
    required this.assignmentId,
  });

  @override
  ConsumerState<EditAssignmentScreen> createState() =>
      _EditAssignmentScreenState();
}

class _EditAssignmentScreenState extends ConsumerState<EditAssignmentScreen> {
  // Core selection states
  int? _selectedServiceProviderId;
  int? _selectedCategoryId; // From assignment
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedEndDate; // For multi-day

  // Work type and duration
  int? _selectedWorkTypeId;
  int? _allocatedDurationMinutes;
  bool _isCustomDuration = false;
  final _customDurationController = TextEditingController();

  // Time slot selection (multi-slot support)
  int? _selectedTimeSlotId; // Single slot (backward compat)
  List<int>? _selectedTimeSlotIds; // Multi-slot (new)

  // Auto-selection results
  List<int>? _autoSelectedSlotIds;
  String? _autoSelectedEndDate;
  bool _hasAutoSelectedSlots = false;

  // Manual time override
  String? _manualStartTime; // "HH:mm" format
  String? _manualEndTime; // "HH:mm" format

  final _notesController = TextEditingController();

  // Service provider search and pagination controllers
  final _spSearchController = TextEditingController();
  final _spScrollController = ScrollController();
  Timer? _spSearchDebounce;

  bool _isInitialized = false;
  AssignmentModel? _originalAssignment;

  @override
  void initState() {
    super.initState();

    // Initialize scroll and search listeners
    _spScrollController.addListener(_onSpScroll);
    _spSearchController.addListener(_onSpSearchChanged);
  }

  @override
  void dispose() {
    // Cancel timer
    _spSearchDebounce?.cancel();

    // Remove listeners
    _spScrollController.removeListener(_onSpScroll);
    _spSearchController.removeListener(_onSpSearchChanged);

    // Dispose controllers
    _spScrollController.dispose();
    _spSearchController.dispose();
    _customDurationController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  List<DateTime> get _availableDates {
    final now = DateTime.now();
    return List.generate(14, (index) => now.add(Duration(days: index)));
  }

  bool get _canSave {
    return _selectedServiceProviderId != null &&
        (_selectedTimeSlotId != null ||
            _selectedTimeSlotIds != null ||
            _autoSelectedSlotIds != null);
  }

  bool get _hasChanges {
    if (_originalAssignment == null) return false;

    // Check service provider change
    if (_selectedServiceProviderId != _originalAssignment!.serviceProviderId) {
      return true;
    }

    // Check work type change
    if (_selectedWorkTypeId != _originalAssignment!.workTypeId) return true;

    // Check duration change
    if (_allocatedDurationMinutes != _originalAssignment!.allocatedDurationMinutes) {
      return true;
    }

    // Check time slot changes (single vs multi)
    final originalIsMulti = _originalAssignment!.hasMultipleSlots;
    final newIsMulti = _selectedTimeSlotIds != null || _autoSelectedSlotIds != null;

    if (originalIsMulti != newIsMulti) return true;

    if (originalIsMulti) {
      // Compare multi-slot arrays
      final currentIds = _autoSelectedSlotIds ?? _selectedTimeSlotIds ?? [];
      final originalIds = _originalAssignment!.timeSlotIds ?? [];
      if (currentIds.length != originalIds.length) return true;
      for (var id in currentIds) {
        if (!originalIds.contains(id)) return true;
      }
    } else {
      // Compare single slot
      if (_selectedTimeSlotId != _originalAssignment!.timeSlotId) return true;
    }

    // Check date change
    if (!_isSameDate(_selectedDate, _originalAssignment!.scheduledDate)) {
      return true;
    }

    // Check end date change for multi-day
    if (_selectedEndDate != null && _originalAssignment!.scheduledEndDate != null) {
      if (!_isSameDate(_selectedEndDate!, _originalAssignment!.scheduledEndDate!)) {
        return true;
      }
    } else if (_selectedEndDate != null || _originalAssignment!.scheduledEndDate != null) {
      // One is null, the other isn't - that's a change
      return true;
    }

    // Check manual time override change
    if (_manualStartTime != _originalAssignment!.assignedStartTime ||
        _manualEndTime != _originalAssignment!.assignedEndTime) {
      return true;
    }

    // Check notes change
    if (_notesController.text != (_originalAssignment!.notes ?? '')) {
      return true;
    }

    return false;
  }

  bool _isSameDate(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Scroll listener for pagination
  void _onSpScroll() {
    if (_spScrollController.position.pixels >=
        _spScrollController.position.maxScrollExtent - 200) {
      ref.read(adminServiceProviderListProvider.notifier).loadMore();
    }
  }

  // Search listener with debouncing
  void _onSpSearchChanged() {
    _spSearchDebounce?.cancel();
    _spSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final query = _spSearchController.text;
        ref.read(adminServiceProviderListProvider.notifier).search(query);
      }
    });
  }

  void _initializeFromAssignment(AssignmentModel assignment) {
    if (_isInitialized) return;
    _isInitialized = true;
    _originalAssignment = assignment;

    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedServiceProviderId = assignment.serviceProviderId;
          _selectedCategoryId = assignment.categoryId;
          _selectedWorkTypeId = assignment.workTypeId;
          _allocatedDurationMinutes = assignment.allocatedDurationMinutes;
          _isCustomDuration = assignment.isCustomDuration ?? false;
          _selectedDate = assignment.scheduledDate ?? DateTime.now();
          _selectedEndDate = assignment.scheduledEndDate;

          // Handle multi-slot vs single slot
          if (assignment.hasMultipleSlots && assignment.timeSlotIds != null) {
            _selectedTimeSlotIds = List.from(assignment.timeSlotIds!);
            _selectedTimeSlotId = null;
          } else {
            _selectedTimeSlotId = assignment.timeSlotId;
            _selectedTimeSlotIds = null;
          }

          // Time overrides
          _manualStartTime = assignment.assignedStartTime;
          _manualEndTime = assignment.assignedEndTime;

          _notesController.text = assignment.notes ?? '';

          // Set custom duration in controller if custom
          if (_isCustomDuration && _allocatedDurationMinutes != null) {
            _customDurationController.text = _allocatedDurationMinutes.toString();
          }
        });
      }
    });
  }

  /// Auto-select time slots for the specified duration
  Future<void> _autoSelectSlotsForDuration() async {
    if (_selectedServiceProviderId == null || _allocatedDurationMinutes == null) {
      return;
    }

    setState(() {
      _hasAutoSelectedSlots = false; // Reset flag
    });

    try {
      final repository = ref.read(adminIssueRepositoryProvider);
      final result = await repository.autoSelectSlots(
        _selectedServiceProviderId!,
        startDate: _selectedDate,
        durationMinutes: _allocatedDurationMinutes!,
      );

      // Parse result
      final timeSlotIds = (result['time_slot_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [];
      final scheduledEndDate = result['scheduled_end_date'] as String?;
      final assignedStartTime = result['assigned_start_time'] as String?;
      final assignedEndTime = result['assigned_end_time'] as String?;
      final totalCapacityMinutes = result['total_capacity_minutes'] as int? ?? 0;

      if (timeSlotIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.assign.insufficient_capacity'.tr()),
              backgroundColor: context.colors.warning,
            ),
          );
        }
        return;
      }

      // Check if full duration was allocated
      final shortfall = _allocatedDurationMinutes! - totalCapacityMinutes;
      if (shortfall > 0) {
        if (mounted) {
          final spanDays = result['span_days'] as int? ?? 1;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'admin.assign.partial_allocation'.tr(namedArgs: {
                  'allocated': totalCapacityMinutes.toString(),
                  'days': spanDays.toString(),
                  'shortfall': shortfall.toString(),
                }),
              ),
              backgroundColor: context.colors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          final spanDays = result['span_days'] as int? ?? 1;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                spanDays == 1
                    ? 'admin.assign.auto_selected_success'.tr(namedArgs: {
                        'count': timeSlotIds.length.toString(),
                        'days': spanDays.toString(),
                      })
                    : 'admin.assign.auto_selected_success_plural'.tr(namedArgs: {
                        'count': timeSlotIds.length.toString(),
                        'days': spanDays.toString(),
                      }),
              ),
              backgroundColor: context.colors.success,
            ),
          );
        }
      }

      setState(() {
        _autoSelectedSlotIds = timeSlotIds;
        _autoSelectedEndDate = scheduledEndDate;
        _manualStartTime = assignedStartTime;
        _manualEndTime = assignedEndTime;
        _hasAutoSelectedSlots = true;

        // Clear manual selection
        _selectedTimeSlotId = null;
        _selectedTimeSlotIds = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.assign.auto_selection_failed'.tr(namedArgs: {
              'error': e.toString(),
            })),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitUpdate() async {
    if (!_canSave) return;

    final issueIdInt = int.tryParse(widget.issueId);
    final assignmentIdInt = int.tryParse(widget.assignmentId);

    if (issueIdInt == null || assignmentIdInt == null) return;

    // Determine which slots to send
    final timeSlotIds = _autoSelectedSlotIds ?? _selectedTimeSlotIds;
    final singleSlotId = _selectedTimeSlotId;

    // Calculate end date
    DateTime? endDate;
    if (_autoSelectedEndDate != null) {
      endDate = DateTime.parse(_autoSelectedEndDate!);
    } else if (_selectedEndDate != null) {
      endDate = _selectedEndDate;
    }

    final success =
        await ref.read(adminIssueActionProvider.notifier).updateAssignment(
              issueIdInt,
              assignmentIdInt,
              categoryId: _selectedCategoryId,
              serviceProviderId: _selectedServiceProviderId!,
              workTypeId: _selectedWorkTypeId,
              allocatedDurationMinutes: _allocatedDurationMinutes,
              isCustomDuration: _isCustomDuration,
              scheduledDate: _selectedDate,
              timeSlotId: singleSlotId,
              timeSlotIds: timeSlotIds,
              scheduledEndDate: endDate,
              assignedStartTime: _manualStartTime,
              assignedEndTime: _manualEndTime,
              notes:
                  _notesController.text.isNotEmpty ? _notesController.text : null,
            );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.update_assignment_success'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(adminIssueActionProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'admin.update_assignment_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueIdInt = int.tryParse(widget.issueId) ?? 0;
    final issueAsync = ref.watch(adminIssueDetailProvider(issueIdInt));
    final actionState = ref.watch(adminIssueActionProvider);

    return issueAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: Text('admin.edit_assignment'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: Text('admin.edit_assignment'.tr())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: context.colors.error),
              AppSpacing.vGapLg,
              Text('errors.load_failed'.tr()),
              AppSpacing.vGapMd,
              FilledButton(
                onPressed: () =>
                    ref.invalidate(adminIssueDetailProvider(issueIdInt)),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
      data: (issue) {
        // Find the assignment being edited
        final assignmentIdInt = int.tryParse(widget.assignmentId) ?? 0;
        final assignment = issue.assignments.cast<AssignmentModel?>().firstWhere(
              (a) => a?.id == assignmentIdInt,
              orElse: () => null,
            );

        if (assignment == null) {
          return Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(title: Text('admin.edit_assignment'.tr())),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: context.colors.error),
                  AppSpacing.vGapLg,
                  Text(
                    'assignments.not_found'.tr(),
                    style: context.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vGapMd,
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: Text('common.go_back'.tr()),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if assignment is editable
        if (assignment.status != AssignmentStatus.assigned) {
          return Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(title: Text('admin.edit_assignment'.tr())),
            body: Center(
              child: Padding(
                padding: AppSpacing.allXl,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 64, color: context.colors.warning),
                    AppSpacing.vGapLg,
                    Text(
                      'admin.assignment_locked'.tr(),
                      style: context.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapSm,
                    Text(
                      'admin.assignment_locked_desc'.tr(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapMd,
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: Text('common.go_back'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Initialize form with current values
        _initializeFromAssignment(assignment);

        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            title: Text('admin.edit_assignment'.tr()),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: actionState.isLoading
                  ? const LinearProgressIndicator()
                  : const SizedBox(height: 4),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.allLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Issue summary card
                      _buildIssueSummary(issue),
                      AppSpacing.vGapXl,

                      // Work Type Selection (if category selected)
                      if (_selectedCategoryId != null) ...[
                        _buildWorkTypeSection(),
                        AppSpacing.vGapXl,
                      ],

                      // Service Provider Selection
                      Text(
                        'assign.select_provider'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapMd,
                      _buildProviderSelection(_selectedCategoryId),
                      AppSpacing.vGapXl,

                      // Date Selection
                      Text(
                        'assign.select_date'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapMd,
                      _buildDateSelection(),
                      AppSpacing.vGapXl,

                      // Auto-select button (if duration specified)
                      if (_selectedServiceProviderId != null &&
                          _allocatedDurationMinutes != null) ...[
                        _buildAutoSelectButton(),
                        AppSpacing.vGapMd,
                      ],

                      // Success state for auto-selection
                      if (_hasAutoSelectedSlots) ...[
                        _buildAutoSelectSuccessCard(),
                        AppSpacing.vGapMd,
                      ],

                      // Time Slot Selection
                      Text(
                        'assign.select_time'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapMd,
                      _buildTimeSlotSelection(),
                      AppSpacing.vGapXl,

                      // Manual time override (permission-based)
                      _buildManualTimeOverride(),

                      // Notes
                      Text(
                        'assign.notes_optional'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapMd,
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'assign.notes_hint'.tr(),
                          filled: true,
                          fillColor: context.colors.surface,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                      // Bottom spacing
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: context.colors.card,
              boxShadow: context.bottomNavShadow,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          actionState.isLoading ? null : () => context.pop(),
                      child: Text('common.cancel'.tr()),
                    ),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          (_canSave && _hasChanges && !actionState.isLoading)
                              ? _submitUpdate
                              : null,
                      child: actionState.isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.onPrimary,
                              ),
                            )
                          : Text('admin.update_assignment'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssueSummary(dynamic issue) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border(
          left: BorderSide(
            color: context.priorityColor(issue.priority),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapXs,
          Text(
            issue.tenantAddress,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'assign.work_type'.tr(),
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapSm,
        Text(
          'assign.work_type_desc'.tr(),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        AppSpacing.vGapMd,

        // Toggle between work type and custom duration
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text('assign.use_work_type'.tr()),
                selected: !_isCustomDuration,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isCustomDuration = false;
                      _customDurationController.clear();
                      // Duration will come from work type
                    });
                  }
                },
              ),
            ),
            AppSpacing.gapSm,
            Expanded(
              child: ChoiceChip(
                label: Text('assign.custom_duration'.tr()),
                selected: _isCustomDuration,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isCustomDuration = true;
                      _selectedWorkTypeId = null;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        AppSpacing.vGapMd,

        // Work type selection
        if (!_isCustomDuration) ...[
          _buildWorkTypeList(),
        ],

        // Custom duration input
        if (_isCustomDuration) ...[
          TextField(
            controller: _customDurationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'assign.duration_minutes'.tr(),
              hintText: 'assign.duration_hint'.tr(),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: BorderSide.none,
              ),
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
            onChanged: (value) {
              final minutes = int.tryParse(value);
              setState(() {
                _allocatedDurationMinutes =
                    (minutes != null && minutes >= 15) ? minutes : null;
              });
            },
          ),
          if (_allocatedDurationMinutes != null &&
              _allocatedDurationMinutes! < 15) ...[
            AppSpacing.vGapSm,
            Text(
              'assign.duration_min_15'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildWorkTypeList() {
    if (_selectedCategoryId == null) {
      return Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Text(
          'assign.select_category_first'.tr(),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    final workTypesAsync =
        ref.watch(workTypesForCategoryProvider(_selectedCategoryId!));

    return workTypesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          children: [
            Text('assign.work_types_failed'.tr()),
            TextButton(
              onPressed: () => ref.invalidate(
                  workTypesForCategoryProvider(_selectedCategoryId!)),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
      data: (workTypes) {
        if (workTypes.isEmpty) {
          return Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.1),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: context.colors.warning),
                AppSpacing.gapMd,
                Expanded(
                  child: Text(
                    'assign.no_work_types'.tr(),
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
          children: workTypes.map((workType) {
            return _buildWorkTypeCard(workType);
          }).toList(),
        );
      },
    );
  }

  Widget _buildWorkTypeCard(WorkTypeModel workType) {
    final isSelected = _selectedWorkTypeId == workType.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: () {
          setState(() {
            _selectedWorkTypeId = workType.id;
            _allocatedDurationMinutes = workType.durationMinutes;
          });
        },
        child: Row(
          children: [
            Icon(
              Icons.work_outline_rounded,
              color: isSelected
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workType.name,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  if (workType.description != null) ...[
                    AppSpacing.vGapXs,
                    Text(
                      workType.description!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapMd,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.badgeRadius,
              ),
              child: Text(
                '${workType.durationMinutes}min',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected) ...[
              AppSpacing.gapSm,
              Icon(
                Icons.check_circle,
                color: context.colors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelection(int? categoryId) {
    // Initialize provider list when category changes
    if (categoryId != null) {
      // Use post-frame callback to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final notifier = ref.read(adminServiceProviderListProvider.notifier);
          // Only initialize if not already loaded for this category
          final currentState = ref.read(adminServiceProviderListProvider);
          if (currentState.categoryIdFilter != categoryId) {
            notifier
              ..filterByCategory(categoryId)
              ..filterByActive(true)
              ..search('')
              ..loadServiceProviders();
          }
        }
      });
    }

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
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
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

        // Service providers list
        SizedBox(
          height: 300,
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(adminServiceProviderListProvider.notifier).refresh(),
            child: ListView(
              controller: _spScrollController,
              children: [
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
    final isAvailable = provider.activeJobs < 5;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: isAvailable
            ? () {
                setState(() {
                  _selectedServiceProviderId = provider.id;
                  // Reset time slot selection when changing provider
                  _selectedTimeSlotId = null;
                  _selectedTimeSlotIds = null;
                  _autoSelectedSlotIds = null;
                  _hasAutoSelectedSlots = false;
                });
              }
            : null,
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.5,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                backgroundImage: provider.userProfilePhotoUrl != null &&
                        provider.userProfilePhotoUrl!.isNotEmpty
                    ? NetworkImage(provider.userProfilePhotoUrl!)
                    : null,
                child: provider.userProfilePhotoUrl == null ||
                        provider.userProfilePhotoUrl!.isEmpty
                    ? Text(
                        provider.displayName[0].toUpperCase(),
                        style: TextStyle(
                          color: context.colors.primary,
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
                    Text(
                      provider.displayName,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (provider.userEmail != null) ...[
                      Text(
                        provider.userEmail!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Text(
                          isAvailable
                              ? 'assign.available'.tr()
                              : 'assign.busy'.tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: isAvailable
                                ? context.colors.success
                                : context.colors.warning,
                          ),
                        ),
                        if (provider.activeJobs > 0) ...[
                          Text(
                            ' • ${provider.activeJobs} active',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: context.colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelection() {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _availableDates.length,
        separatorBuilder: (_, __) => AppSpacing.gapSm,
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final isSelected = _isSameDate(_selectedDate, date);
          final isToday = _isSameDate(date, DateTime.now());
          final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          final dayName = dayNames[date.weekday % 7];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                // Reset time slots when date changes
                _selectedTimeSlotId = null;
                _selectedTimeSlotIds = null;
                _autoSelectedSlotIds = null;
                _hasAutoSelectedSlots = false;
              });
            },
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.surfaceVariant,
                borderRadius: AppRadius.cardRadius,
                border: isToday && !isSelected
                    ? Border.all(color: context.colors.primary, width: 2)
                    : null,
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
                      fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildAutoSelectButton() {
    return FilledButton.icon(
      onPressed: _autoSelectSlotsForDuration,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: Text('admin.assign.auto_select_slots'.tr()),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildAutoSelectSuccessCard() {
    final slotCount = _autoSelectedSlotIds?.length ?? 0;
    final endDate = _autoSelectedEndDate != null
        ? DateTime.parse(_autoSelectedEndDate!)
        : null;
    final spanDays =
        endDate != null ? endDate.difference(_selectedDate).inDays + 1 : 1;

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.success.withValues(alpha: 0.1),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: context.colors.success,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: context.colors.success),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slotCount == 1
                      ? 'admin.assign.auto_selected_success'.tr(namedArgs: {
                          'count': slotCount.toString(),
                          'days': spanDays.toString(),
                        })
                      : 'admin.assign.auto_selected_success_plural'.tr(namedArgs: {
                          'count': slotCount.toString(),
                          'days': spanDays.toString(),
                        }),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (spanDays > 1) ...[
                  AppSpacing.vGapXs,
                  Text(
                    'admin.assign.spanning_days'.tr(namedArgs: {
                      'count': spanDays.toString(),
                    }),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _autoSelectedSlotIds = null;
                _autoSelectedEndDate = null;
                _hasAutoSelectedSlots = false;
                _manualStartTime = null;
                _manualEndTime = null;
              });
            },
            child: Text('common.clear'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotSelection() {
    if (_selectedServiceProviderId == null) {
      return Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Text(
          'assign.select_provider_first'.tr(),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    // If auto-selected, show readonly display
    if (_hasAutoSelectedSlots && _autoSelectedSlotIds != null) {
      return Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Text(
          'admin.assign.using_auto_selected'.tr(namedArgs: {
            'count': _autoSelectedSlotIds!.length.toString(),
          }),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    final availabilityParams = AvailabilityParams(
      serviceProviderId: _selectedServiceProviderId!,
      date: _selectedDate,
      minDurationMinutes: _allocatedDurationMinutes,
    );
    final timeSlotsAsync =
        ref.watch(serviceProviderAvailabilityProvider(availabilityParams));

    return timeSlotsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          children: [
            Text('assign.timeslots_failed'.tr()),
            TextButton(
              onPressed: () => ref.invalidate(
                  serviceProviderAvailabilityProvider(availabilityParams)),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
      data: (timeSlots) {
        if (timeSlots.isEmpty) {
          return Container(
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.1),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: context.colors.warning),
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
    // Check if this slot is selected (single or multi)
    final isSelectedSingle = _selectedTimeSlotId == slot.id;
    final isSelectedMulti =
        _selectedTimeSlotIds != null && _selectedTimeSlotIds!.contains(slot.id);
    final isSelected = isSelectedSingle || isSelectedMulti;
    final isAvailable = slot.isActive;

    // Multi-slot mode: show checkboxes
    final isMultiSlotMode = _selectedTimeSlotIds != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _SelectableCard(
        isSelected: isSelected,
        onTap: isAvailable
            ? () {
                setState(() {
                  if (isMultiSlotMode) {
                    // Multi-slot: toggle checkbox
                    if (isSelectedMulti) {
                      _selectedTimeSlotIds!.remove(slot.id);
                      if (_selectedTimeSlotIds!.isEmpty) {
                        _selectedTimeSlotIds = null;
                      }
                    } else {
                      _selectedTimeSlotIds!.add(slot.id);
                    }
                  } else {
                    // Single slot: radio button behavior
                    _selectedTimeSlotId = slot.id;
                  }
                });
              }
            : null,
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.5,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isMultiSlotMode
                        ? (isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                        : (isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textSecondary,
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.formattedRange,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        ),
                        if (slot.blockedRanges != null &&
                            slot.blockedRanges!.isNotEmpty) ...[
                          AppSpacing.vGapXs,
                          Text(
                            'admin.assign.blocked_times_count'.tr(namedArgs: {
                              'count': slot.blockedRanges!.length.toString(),
                            }),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Text(
                        'assign.booked'.tr(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                ],
              ),
              // Capacity visualization
              if (slot.capacityDisplay != null ||
                  slot.utilizationPercent != null) ...[
                AppSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.badgeRadius,
                        child: LinearProgressIndicator(
                          value: (slot.utilizationPercent ?? 0) / 100,
                          backgroundColor:
                              context.colors.surfaceVariant.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getCapacityColor(slot.utilizationPercent ?? 0),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    AppSpacing.gapMd,
                    if (slot.capacityDisplay != null) ...[
                      Text(
                        slot.capacityDisplay!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: _getCapacityColor(slot.utilizationPercent ?? 0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.gapXs,
                    ],
                    Text(
                      '${slot.utilizationPercent ?? 0}%',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: _getCapacityColor(slot.utilizationPercent ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get color based on utilization percentage
  Color _getCapacityColor(int utilizationPercent) {
    if (utilizationPercent >= 90) return context.colors.error;
    if (utilizationPercent >= 70) return context.colors.warning;
    if (utilizationPercent >= 50) return context.colors.primary;
    return context.colors.success;
  }

  /// Manual time override section (permission-based)
  Widget _buildManualTimeOverride() {
    // Only show if user has permission AND time slot is selected
    final currentUser = ref.watch(currentUserProvider);
    final hasPermission =
        currentUser?.hasPermission('override_work_type_duration') ?? false;

    if (!hasPermission ||
        (_selectedTimeSlotId == null &&
            (_selectedTimeSlotIds == null || _selectedTimeSlotIds!.isEmpty) &&
            _autoSelectedSlotIds == null)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_calendar_rounded, size: 20),
            AppSpacing.gapSm,
            Text(
              'admin.assign.manual_time_override'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppSpacing.vGapSm,
        Text(
          'admin.assign.manual_time_desc'.tr(),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        AppSpacing.vGapMd,

        // Start and end time pickers
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickStartTime(context),
                borderRadius: AppRadius.inputRadius,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'admin.assign.start_time'.tr(),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                      borderSide: BorderSide.none,
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
            AppSpacing.gapMd,
            Expanded(
              child: InkWell(
                onTap: () => _pickEndTime(context),
                borderRadius: AppRadius.inputRadius,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'admin.assign.end_time'.tr(),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                      borderSide: BorderSide.none,
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

        AppSpacing.vGapXl,
      ],
    );
  }

  Future<void> _pickStartTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _manualStartTime != null
          ? TimeOfDay(
              hour: int.parse(_manualStartTime!.split(':')[0]),
              minute: int.parse(_manualStartTime!.split(':')[1]),
            )
          : TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _manualStartTime =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        // Auto-calculate end time from duration if available
        if (_allocatedDurationMinutes != null) {
          final totalMinutes =
              time.hour * 60 + time.minute + _allocatedDurationMinutes!;
          final endHour = (totalMinutes ~/ 60) % 24;
          final endMin = totalMinutes % 60;
          _manualEndTime =
              '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
        }
      });
    }
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _manualEndTime != null
          ? TimeOfDay(
              hour: int.parse(_manualEndTime!.split(':')[0]),
              minute: int.parse(_manualEndTime!.split(':')[1]),
            )
          : TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _manualEndTime =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }
}

/// Reusable selectable card widget
class _SelectableCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;

  const _SelectableCard({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? context.colors.primary.withValues(alpha: 0.1)
          : context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: isSelected
                  ? context.colors.primary
                  : context.colors.surfaceVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
