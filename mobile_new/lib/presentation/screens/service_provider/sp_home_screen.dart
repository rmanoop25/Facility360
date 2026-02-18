import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/assignment_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../widgets/notifications/notification_icon_button.dart';
import '../../widgets/shimmer/shimmer.dart';

/// Service Provider home screen with dashboard
class SPHomeScreen extends ConsumerWidget {
  const SPHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final assignmentState = ref.watch(assignmentListProvider);
    final assignments = assignmentState.assignments;

    // Calculate stats
    final todayCount = assignments.where((a) =>
      a.status == AssignmentStatus.assigned ||
      a.status == AssignmentStatus.inProgress
    ).length;
    final pendingCount = assignments.where((a) =>
      a.status == AssignmentStatus.assigned
    ).length;
    final completedCount = assignments.where((a) =>
      a.status == AssignmentStatus.completed
    ).length;

    // Find active assignment (in progress)
    final activeAssignment = assignments.cast<AssignmentModel?>().firstWhere(
      (a) => a?.status == AssignmentStatus.inProgress,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Refresh assignments list
            ref.invalidate(assignmentListProvider);
            // Trigger reload by accessing the notifier
            ref.read(assignmentListProvider.notifier).loadAssignments();
          },
          child: CustomScrollView(
            slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: context.colors.background,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sp.hello'.tr(namedArgs: {'name': user?.name.split(' ').first ?? 'Provider'}),
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.serviceProvider?.categories.firstOrNull?.localizedName(context.locale.languageCode) ?? 'sp.service_provider'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                const NotificationIconButton(),
              ],
            ),

            // Content
            SliverPadding(
              padding: AppSpacing.screen,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Cards
                  _buildStatsRow(context, todayCount, pendingCount, completedCount),

                  AppSpacing.vGapXl,

                  // Active Job Section (if any)
                  if (activeAssignment != null) ...[
                    Text(
                      'sp.active_job'.tr(),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vGapMd,
                    _ActiveJobCard(
                      assignment: activeAssignment,
                      onTap: () => context.push('/sp/assignments/${activeAssignment.issueId}'),
                      onContinue: () => context.push('/sp/assignments/${activeAssignment.issueId}/work'),
                    ),
                    AppSpacing.vGapXl,
                  ],

                  // Today's Schedule Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'sp.todays_schedule'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(RoutePaths.spAssignments),
                        child: Text('common.view_all'.tr()),
                      ),
                    ],
                  ),

                  AppSpacing.vGapMd,

                  // Today's Jobs
                  if (assignmentState.isInitialLoading && assignments.isEmpty)
                    const SPHomeShimmer()
                  else if (assignmentState.error != null && assignments.isEmpty)
                    _EmptySchedule(
                      title: 'tenant.failed_to_load'.tr(),
                      subtitle: assignmentState.error!,
                      icon: Icons.error_rounded,
                    )
                  else if (assignments.where((a) => a.status == AssignmentStatus.assigned).isEmpty)
                    const _EmptySchedule()
                  else
                    ...assignments
                        .where((a) => a.status == AssignmentStatus.assigned)
                        .take(3)
                        .map((assignment) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _ScheduleCard(
                        assignment: assignment,
                        onTap: () => context.push('/sp/assignments/${assignment.issueId}'),
                      ),
                    )),
                ]),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int today, int pending, int completed) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'sp.todays_jobs'.tr(),
            value: today.toString(),
            color: context.colors.primary,
            icon: Icons.today_rounded,
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: _StatCard(
            label: 'common.pending'.tr(),
            value: pending.toString(),
            color: context.colors.statusPending,
            icon: Icons.schedule_rounded,
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: _StatCard(
            label: 'common.completed'.tr(),
            value: completed.toString(),
            color: context.colors.statusCompleted,
            icon: Icons.check_circle_rounded,
          ),
        ),
      ],
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          AppSpacing.vGapMd,
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Active job card with timer
class _ActiveJobCard extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onTap;
  final VoidCallback onContinue;

  const _ActiveJobCard({
    required this.assignment,
    required this.onTap,
    required this.onContinue,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final workDuration = assignment.workDuration ?? Duration.zero;
    final location = assignment.tenantUnit != null && assignment.tenantBuilding != null
        ? 'common.unit_building'.tr(namedArgs: {'unit': assignment.tenantUnit ?? '', 'building': assignment.tenantBuilding ?? ''})
        : assignment.tenantUnit ?? assignment.tenantBuilding ?? 'common.na'.tr();

    return Material(
      color: context.colors.primary.withOpacity(0.05),
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: context.colors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.statusInProgress,
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.colors.onPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'sp.in_progress'.tr(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_rounded, size: 16, color: context.colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(workDuration),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapMd,

              // Title
              Text(
                assignment.issueTitle ?? 'issue.issue_number'.tr(namedArgs: {'id': '${assignment.issueId}'}),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              AppSpacing.vGapXs,

              // Location
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: context.colors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapLg,

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('sp.continue_work'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schedule card widget
class _ScheduleCard extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeSlotText = assignment.timeSlot != null
        ? assignment.timeSlot!.formattedRange
        : 'Time not set';
    final location = assignment.tenantUnit != null && assignment.tenantBuilding != null
        ? 'common.unit_building'.tr(namedArgs: {'unit': assignment.tenantUnit ?? '', 'building': assignment.tenantBuilding ?? ''})
        : assignment.tenantUnit ?? assignment.tenantBuilding ?? 'common.na'.tr();

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
          child: Row(
            children: [
              // Time slot indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: context.assignmentStatusColor(assignment.status),
                  borderRadius: AppRadius.allFull,
                ),
              ),
              AppSpacing.gapMd,
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    Text(
                      timeSlotText,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    // Title
                    Text(
                      assignment.issueTitle ?? 'issue.issue_number'.tr(namedArgs: {'id': '${assignment.issueId}'}),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.vGapXs,
                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: context.colors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(Icons.chevron_right, color: context.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty schedule widget
class _EmptySchedule extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData icon;

  const _EmptySchedule({
    this.title,
    this.subtitle,
    this.icon = Icons.event_available_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allXxl,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: context.colors.textTertiary),
          AppSpacing.vGapLg,
          Text(
            title ?? 'sp.no_jobs'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapSm,
          Text(
            subtitle ?? 'sp.all_caught_up'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
