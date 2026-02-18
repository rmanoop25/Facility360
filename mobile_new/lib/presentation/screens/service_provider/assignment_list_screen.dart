import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/assignment_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/assignment_provider.dart';
import '../../widgets/common/error_placeholder.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/sync_status_indicator.dart';

/// Assignment list screen with filtering tabs
class AssignmentListScreen extends ConsumerStatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  ConsumerState<AssignmentListScreen> createState() =>
      _AssignmentListScreenState();
}

class _AssignmentListScreenState extends ConsumerState<AssignmentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // No-op: Tab filtering is done locally via _getFilteredAssignments
    // This prevents unnecessary API calls and loading spinners
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(assignmentListProvider.notifier).loadMore();
    }
  }

  List<AssignmentModel> _getFilteredAssignments(
      List<AssignmentModel> assignments, int tabIndex) {
    return switch (tabIndex) {
      0 => assignments, // All
      1 => assignments
          .where((a) => a.status == AssignmentStatus.assigned)
          .toList(), // Pending
      2 => assignments
          .where((a) => a.status == AssignmentStatus.inProgress)
          .toList(), // In Progress
      3 => assignments
          .where((a) => a.status == AssignmentStatus.onHold)
          .toList(), // On Hold
      4 => assignments
          .where((a) => a.status == AssignmentStatus.finished)
          .toList(), // Finished
      5 => assignments
          .where((a) => a.status == AssignmentStatus.completed)
          .toList(), // Completed
      6 => assignments
          .where((a) => a.issueStatus == IssueStatus.cancelled)
          .toList(), // Cancelled (by issue status)
      _ => assignments,
    };
  }

  Future<void> _onRefresh() async {
    await ref.read(assignmentListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(assignmentListProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('nav.jobs'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'admin.all'.tr()),
            Tab(text: 'common.pending'.tr()),
            Tab(text: 'status.in_progress'.tr()),
            Tab(text: 'status.on_hold'.tr()),
            Tab(text: 'status.finished'.tr()),
            Tab(text: 'common.completed'.tr()),
            Tab(text: 'status.cancelled'.tr()),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offline banner
          const OfflineBanner(),

          // Search bar
          Padding(
            padding: AppSpacing.allLg,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'assignment.search_jobs'.tr(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // TODO: Implement search filter
              },
            ),
          ),

          // Assignment list
          Expanded(
            // Only show loading if we have NO cached data
            child: assignmentState.assignments.isEmpty && assignmentState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : assignmentState.error != null &&
                        assignmentState.assignments.isEmpty
                    ? ErrorPlaceholder(
                        isFullScreen: false,
                        onRetry: () => ref
                            .read(assignmentListProvider.notifier)
                            .loadAssignments(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(7, (tabIndex) {
                          final filteredAssignments = _getFilteredAssignments(
                              assignmentState.assignments, tabIndex);
                          if (filteredAssignments.isEmpty &&
                              !assignmentState.isLoading) {
                            return RefreshIndicator(
                              onRefresh: _onRefresh,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.6,
                                  child: _EmptyState(tabIndex: tabIndex),
                                ),
                              ),
                            );
                          }
                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              controller:
                                  tabIndex == 0 ? _scrollController : null,
                              padding: AppSpacing.horizontalLg,
                              itemCount: filteredAssignments.length +
                                  (assignmentState.isLoadingMore && tabIndex == 0
                                      ? 1
                                      : 0),
                              itemBuilder: (context, index) {
                                // Loading indicator at the end
                                if (index >= filteredAssignments.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(AppSpacing.lg),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final assignment = filteredAssignments[index];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md),
                                  child: _AssignmentListItem(
                                    assignment: assignment,
                                    onTap: () => context.push(
                                        '/sp/assignments/${assignment.issueId}'),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Assignment list item widget
class _AssignmentListItem extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onTap;

  const _AssignmentListItem({
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = assignment.issueTitle ?? 'Assignment #${assignment.id}';
    final location = assignment.tenantAddress;

    // Date display: multi-day or single day
    final scheduledDate = assignment.isMultiDay && assignment.scheduledDateRange != null
        ? assignment.scheduledDateRange!
        : (assignment.isScheduledToday
            ? 'time.today'.tr()
            : assignment.scheduledDateFormatted ?? 'assignment.not_scheduled'.tr());

    final scheduledTime = assignment.timeSlotDisplay ?? '';
    final category = assignment.getCategoryName(context.locale.languageCode);

    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            boxShadow: context.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Category
                  Expanded(
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Sync status indicator (if not synced)
                  if (assignment.syncStatus != SyncStatus.synced)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: SyncStatusIndicator(status: assignment.syncStatus),
                    ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.assignmentStatusBgColor(assignment.status),
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Text(
                      assignment.status.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                context.assignmentStatusColor(assignment.status),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapMd,

              // Title
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              AppSpacing.vGapSm,

              // Location
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: context.colors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapMd,

              // Schedule info
              if (scheduledTime.isNotEmpty || scheduledDate.isNotEmpty)
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withAlpha(13),
                        borderRadius: AppRadius.allMd,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            assignment.isMultiDay
                                ? Icons.date_range_rounded
                                : (assignment.hasMultipleSlots
                                    ? Icons.calendar_view_week_rounded
                                    : Icons.schedule),
                            size: 16,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            assignment.hasMultipleSlots
                                ? scheduledDate
                                : (scheduledTime.isNotEmpty
                                    ? '$scheduledDate, $scheduledTime'
                                    : scheduledDate),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          // Multi-slot badge
                          if (assignment.hasMultipleSlots) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                borderRadius: AppRadius.badgeRadius,
                              ),
                              child: Text(
                                '${assignment.timeSlotCount} ${'common.slots'.tr()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: context.colors.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Multi-day badge
                    if (assignment.isMultiDay) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.warningBg,
                          borderRadius: AppRadius.badgeRadius,
                        ),
                        child: Text(
                          '${assignment.spanDays} ${'common.days'.tr()}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.colors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tabIndex) {
      0 => (Icons.work_outline, 'assignment.no_jobs'.tr(), 'assignment.no_jobs_desc'.tr()),
      1 => (Icons.pending_actions_outlined, 'assignment.no_pending'.tr(),
          'assignment.no_pending_desc'.tr()),
      2 => (Icons.engineering_outlined, 'assignment.no_active'.tr(),
          'assignment.no_active_desc'.tr()),
      3 => (Icons.pause_circle_outlined, 'assignment.no_on_hold'.tr(),
          'assignment.no_on_hold_desc'.tr()),
      4 => (Icons.fact_check_outlined, 'assignment.no_finished'.tr(),
          'assignment.no_finished_desc'.tr()),
      5 => (Icons.check_circle_outline, 'assignment.no_completed'.tr(),
          'assignment.no_completed_desc'.tr()),
      6 => (Icons.cancel_outlined, 'assignment.no_cancelled'.tr(),
          'assignment.no_cancelled_desc'.tr()),
      _ => (Icons.work_outline, 'assignment.no_jobs'.tr(), 'assignment.no_jobs_desc'.tr()),
    };

    return Center(
      child: Padding(
        padding: AppSpacing.allXxl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: context.colors.textTertiary),
            AppSpacing.vGapLg,
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            AppSpacing.vGapSm,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

