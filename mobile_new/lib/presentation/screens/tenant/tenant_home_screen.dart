import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_provider.dart';
import '../../widgets/notifications/notification_icon_button.dart';
import '../../widgets/shimmer/shimmer.dart';

/// Tenant home screen with stats and recent issues
class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final issueState = ref.watch(issueListProvider);
    final issues = issueState.issues;

    // Calculate stats
    final activeCount = issues.where((i) => i.status.isActive).length;
    final pendingCount = issues.where((i) => i.status == IssueStatus.pending).length;
    final completedCount = issues.where((i) => i.status == IssueStatus.completed).length;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(issueListProvider.notifier).refresh();
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
                    'tenant.hello'.tr(namedArgs: {'name': user?.name.split(' ').first ?? 'Guest'}),
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.tenant?.fullAddress ?? 'tenant.welcome'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: const [
                NotificationIconButton(),
              ],
            ),

            // Content
            SliverPadding(
              padding: AppSpacing.screen,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Cards - show shimmer when initial loading
                  if (issueState.isInitialLoading && issues.isEmpty)
                    const StatCardsRowShimmer()
                  else
                    _buildStatsRow(context, activeCount, pendingCount, completedCount),

                  AppSpacing.vGapXl,

                  // Recent Issues Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'tenant.recent_issues'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(RoutePaths.tenantIssues),
                        child: Text('common.view_all'.tr()),
                      ),
                    ],
                  ),

                  AppSpacing.vGapMd,

                  // Recent Issues List
                  if (issueState.isInitialLoading && issues.isEmpty)
                    const IssueListShimmer(itemCount: 3)
                  else if (issueState.error != null && issues.isEmpty)
                    _EmptyState(
                      icon: Icons.error_rounded,
                      title: 'tenant.failed_to_load'.tr(),
                      subtitle: issueState.error!,
                    )
                  else if (issues.isEmpty)
                    _EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'tenant.no_issues_yet'.tr(),
                      subtitle: 'tenant.tap_to_report'.tr(),
                    )
                  else
                    ...issues.take(3).map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _IssueCard(
                        title: issue.title,
                        category: issue.getCategoryNames('en'),
                        status: issue.status,
                        priority: issue.priority,
                        timeAgo: issue.timeAgo,
                        syncStatus: issue.syncStatus,
                        onTap: () {
                          // Navigate based on whether it's local or server issue
                          if (issue.id > 0) {
                            context.push('/tenant/issues/${issue.id}');
                          } else if (issue.localId != null) {
                            // For local-only issues, navigate with localId
                            context.push('/tenant/issues/local/${issue.localId}');
                          }
                        },
                      ),
                    )),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push(RoutePaths.tenantCreateIssue),
      icon: const Icon(Icons.add_rounded),
      label: Text('tenant.report_issue'.tr()),
    ),
  );
  }

  Widget _buildStatsRow(BuildContext context, int active, int pending, int completed) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'common.active'.tr(),
            value: active.toString(),
            color: context.colors.statusInProgress,
            icon: Icons.pending_actions_rounded,
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
            label: 'status.completed'.tr(),
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

/// Issue card widget
class _IssueCard extends StatelessWidget {
  final String title;
  final String category;
  final IssueStatus status;
  final IssuePriority priority;
  final String timeAgo;
  final SyncStatus syncStatus;
  final VoidCallback onTap;

  const _IssueCard({
    required this.title,
    required this.category,
    required this.status,
    required this.priority,
    required this.timeAgo,
    required this.syncStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              // Priority indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: context.priorityColor(priority),
                  borderRadius: AppRadius.allFull,
                ),
              ),
              AppSpacing.gapMd,
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      '$category • $timeAgo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.issueStatusBgColor(status),
                  borderRadius: AppRadius.badgeRadius,
                ),
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.issueStatusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
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
    );
  }
}
