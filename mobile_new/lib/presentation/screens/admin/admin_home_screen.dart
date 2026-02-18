import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums/issue_status.dart';
import '../../../domain/enums/issue_priority.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/admin_issue_provider.dart';
import '../../widgets/admin/permission_gate.dart';
import '../../widgets/notifications/notification_icon_button.dart';
import '../../widgets/shimmer/shimmer.dart';

/// Admin Dashboard Screen
/// Displays overview stats, quick actions, and issues requiring attention
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final dashboardState = ref.watch(adminDashboardProvider);
    final issueListState = ref.watch(adminIssueListProvider);
    final issueStats = dashboardState.stats?.issues;
    final recentIssues = dashboardState.stats?.recentIssues ?? [];

    // Filter issues requiring attention (pending or finished)
    final issuesRequiringAttention = issueListState.issues
        .where(
          (issue) =>
              issue.status == IssueStatus.pending ||
              issue.status == IssueStatus.finished,
        )
        .take(5)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(adminDashboardProvider.notifier).refresh();
        await ref.read(adminIssueListProvider.notifier).refresh();
      },
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            title: Text('admin.dashboard'.tr()),
            actions: [const NotificationIconButton()],
          ),

          // Welcome Section
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.horizontalLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'admin.welcome'.tr(
                      namedArgs: {
                        'name': (user?.name ?? 'Admin').split(' ').first,
                      },
                    ),
                    style: context.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          // Stats Grid
          SliverPadding(
            padding: AppSpacing.horizontalLg,
            sliver: dashboardState.isInitialLoading
                ? const SliverAdminStatsShimmer()
                : SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.lg,
                          crossAxisSpacing: AppSpacing.lg,
                          childAspectRatio: 1.4,
                        ),
                    delegate: SliverChildListDelegate([
                      _StatCard(
                        label: 'common.pending'.tr(),
                        value: '${issueStats?.pending ?? 0}',
                        icon: Icons.pending_actions_rounded,
                        color: context.colors.statusPending,
                        onTap: () => context.go('${RoutePaths.adminIssues}?tab=1'),
                      ),
                      _StatCard(
                        label: 'common.active'.tr(),
                        value: '${issueStats?.activeCount ?? 0}',
                        icon: Icons.engineering_rounded,
                        color: context.colors.statusInProgress,
                        onTap: () => context.go('${RoutePaths.adminIssues}?tab=3'),
                      ),
                      _StatCard(
                        label: 'time.today'.tr(),
                        value: '${issueStats?.todayCreated ?? 0}',
                        icon: Icons.today_rounded,
                        color: context.colors.info,
                        onTap: () => context.go('${RoutePaths.adminIssues}?tab=0'),
                      ),
                      _StatCard(
                        label: 'common.done'.tr(),
                        value: '${issueStats?.completed ?? 0}',
                        icon: Icons.check_circle_rounded,
                        color: context.colors.statusCompleted,
                        onTap: () => context.go('${RoutePaths.adminIssues}?tab=5'),
                      ),
                    ]),
                  ),
          ),

          // Quick Actions Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'admin.quick_actions'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  CanManageGate(
                    fallback: const SizedBox.shrink(),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _QuickActionChip(
                          label: 'admin.assign_issues'.tr(),
                          icon: Icons.assignment_ind_rounded,
                          onTap: () => context.go('${RoutePaths.adminIssues}?tab=1'),
                        ),
                        _QuickActionChip(
                          label: 'admin.approve_work'.tr(),
                          icon: Icons.check_circle_rounded,
                          onTap: () => context.go('${RoutePaths.adminIssues}?tab=4'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Issues Requiring Attention Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'admin.attention_needed'.tr(),
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('${RoutePaths.adminIssues}?tab=0'),
                    child: Text('common.view_all'.tr()),
                  ),
                ],
              ),
            ),
          ),

          // Issue Cards
          SliverPadding(
            padding: AppSpacing.horizontalLg,
            sliver: issueListState.isInitialLoading && issueListState.issues.isEmpty
                ? const SliverAdminIssuesShimmer(itemCount: 5)
                : issuesRequiringAttention.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          'admin.no_attention'.tr(),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final issue = issuesRequiringAttention[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? AppSpacing.md : 0,
                          bottom: index < issuesRequiringAttention.length - 1
                              ? AppSpacing.lg
                              : AppSpacing.xl,
                        ),
                        child: _IssueCard(
                          title: issue.title,
                          priority: issue.priority,
                          status: issue.status,
                          timeAgo: issue.timeAgo,
                          onTap: () =>
                              context.push('/admin/issues/${issue.id}'),
                        ),
                      );
                    }, childCount: issuesRequiringAttention.length),
                  ),
          ),

          // Recent Activity Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                'admin.recent_activity'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.all(AppSpacing.lg),
            sliver: recentIssues.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'admin.no_recent'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= recentIssues.length) {
                          return SizedBox(height: AppSpacing.xxxl);
                        }
                        final issue = recentIssues[index];
                        return _ActivityItem(
                          icon: _getStatusIcon(issue.status),
                          text: '${issue.title} - ${issue.translatedStatusLabel}',
                          time: issue.timeAgo,
                          onTap: () =>
                              context.push('/admin/issues/${issue.id}'),
                        );
                      },
                      childCount:
                          recentIssues.length + 1, // +1 for bottom spacing
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Get icon for issue status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'assigned':
        return Icons.assignment_ind_rounded;
      case 'in_progress':
        return Icons.engineering_rounded;
      case 'on_hold':
        return Icons.pause_circle_rounded;
      case 'finished':
        return Icons.flag_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}

/// Stat card widget for displaying metrics
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLg,
            boxShadow: context.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(height: AppSpacing.md),
              Text(
                value,
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action chip for dashboard
class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickActionChip({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.primary.withValues(alpha: 0.1),
      borderRadius: AppRadius.allFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: context.colors.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Issue card for dashboard
class _IssueCard extends StatelessWidget {
  final String title;
  final IssuePriority priority;
  final IssueStatus status;
  final String timeAgo;
  final VoidCallback? onTap;

  const _IssueCard({
    required this.title,
    required this.priority,
    required this.status,
    required this.timeAgo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLg,
            boxShadow: context.cardShadow,
          ),
          child: Row(
            children: [
              // Priority indicator
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: context.priorityColor(priority),
                  borderRadius: AppRadius.allSm,
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: context.issueStatusBgColor(status),
                            borderRadius: AppRadius.allSm,
                          ),
                          child: Text(
                            status.label,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.issueStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      timeAgo,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Activity item for recent activity section
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final String time;
  final VoidCallback? onTap;

  const _ActivityItem({
    required this.icon,
    required this.text,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: AppRadius.allMd,
              ),
              child: Icon(icon, size: 16, color: context.colors.textSecondary),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Text(text, style: context.textTheme.bodyMedium)),
            Text(
              time,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
