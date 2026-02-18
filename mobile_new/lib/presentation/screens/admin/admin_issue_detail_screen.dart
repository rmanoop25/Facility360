import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/issue_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/admin_issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/error_placeholder.dart';
import '../../widgets/shimmer/shimmer.dart';
import '../../widgets/common/media_gallery_viewer.dart';
import '../../widgets/common/media_thumbnail_item.dart';
import '../../../core/services/location_service.dart';

/// Admin Issue Detail Screen
/// Displays full issue details with admin actions (assign, approve, cancel)
class AdminIssueDetailScreen extends ConsumerWidget {
  final String issueId;

  const AdminIssueDetailScreen({super.key, required this.issueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role.canManageIssues ?? false;
    final issueIdInt = int.tryParse(issueId) ?? 0;
    final issueAsync = ref.watch(adminIssueDetailProvider(issueIdInt));
    final actionState = ref.watch(adminIssueActionProvider);

    return issueAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: Text('issue.details'.tr())),
        body: const IssueDetailShimmer(),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: Text('issue.details'.tr())),
        body: ErrorPlaceholder(
          onRetry: () => ref.invalidate(adminIssueDetailProvider(issueIdInt)),
        ),
      ),
      data: (issue) => _IssueDetailContent(
        issue: issue,
        canManage: canManage,
        isLoading: actionState.isLoading,
        onAssign: () => context.push('/admin/issues/$issueId/assign'),
        onApprove: () => context.push('/admin/issues/$issueId/approve'),
        onCancel: (reason) => _cancelIssue(context, ref, issue.id, reason),
      ),
    );
  }

  Future<void> _cancelIssue(
    BuildContext context,
    WidgetRef ref,
    int issueId,
    String reason,
  ) async {
    try {
      await ref
          .read(adminIssueActionProvider.notifier)
          .cancelIssue(issueId, reason: reason);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('issue_detail.cancelled'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'issue_detail.cancel_failed'.tr(
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: context.colors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

/// Issue detail content widget
class _IssueDetailContent extends ConsumerWidget {
  final IssueModel issue;
  final bool canManage;
  final bool isLoading;
  final VoidCallback onAssign;
  final VoidCallback onApprove;
  final Function(String) onCancel;

  const _IssueDetailContent({
    required this.issue,
    required this.canManage,
    required this.isLoading,
    required this.onAssign,
    required this.onApprove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = context.issueStatusColor(issue.status);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          // Offline banner
          const SliverToBoxAdapter(child: OfflineBanner()),

          // App Bar with status gradient - pinned header
          SliverAppBar(
            pinned: true,
            backgroundColor: statusColor,
            foregroundColor: context.colors.onPrimary,
            toolbarHeight: 100,
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final canUpdate = ref.watch(canUpdateIssuesProvider);
                  if (!canUpdate) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'common.edit'.tr(),
                    onPressed: () => context.push(
                      '/admin/issues/${issue.id}/edit',
                      extra: issue,
                    ),
                  );
                },
              ),
            ],
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and priority badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.onPrimary.withAlpha(51),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Text(
                        issue.status.label,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AppSpacing.gapSm,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context
                            .priorityColor(issue.priority)
                            .withAlpha(51),
                        borderRadius: AppRadius.badgeRadius,
                        border: Border.all(
                          color: context.colors.onPrimary.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getPriorityIcon(issue.priority),
                            size: 12,
                            color: context.colors.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            issue.priority.label,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSpacing.vGapSm,
                Text(
                  'issue.issue_number'.tr(namedArgs: {'id': issue.id.toString()}),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onPrimary.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Issue Info Card
                  _InfoCard(
                    title: 'issue.details'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (issue.description != null &&
                            issue.description!.isNotEmpty) ...[
                          AppSpacing.vGapMd,
                          Text(
                            issue.description!,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                        AppSpacing.vGapMd,
                        // Categories
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: issue.categories.map((cat) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primaryLight.withAlpha(
                                  26,
                                ),
                                borderRadius: AppRadius.badgeRadius,
                                border: Border.all(
                                  color: context.colors.primaryLight.withAlpha(
                                    77,
                                  ),
                                ),
                              ),
                              child: Text(
                                cat.nameEn,
                                style: context.textTheme.labelMedium?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        AppSpacing.vGapMd,
                        // Created info
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: context.colors.textTertiary,
                            ),
                            AppSpacing.gapSm,
                            Text(
                              'issue.created_at_info'.tr(namedArgs: {'time': issue.timeAgo}),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Tenant Info Card
                  _InfoCard(
                    title: 'issue_detail.tenant_info'.tr(),
                    child: Column(
                      children: [
                        _TenantInfoRow(
                          icon: Icons.person_outline,
                          label: 'issue_detail.name'.tr(),
                          value: issue.tenantName,
                        ),
                        AppSpacing.vGapMd,
                        _TenantInfoRow(
                          icon: Icons.apartment,
                          label: 'issue_detail.unit'.tr(),
                          value: issue.tenantAddress,
                        ),
                        if (issue.tenantPhone != null) ...[
                          AppSpacing.vGapMd,
                          _TenantInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'issue_detail.phone'.tr(),
                            value: issue.tenantPhone!,
                            trailing: IconButton(
                              onPressed: () =>
                                  _callPhone(context, issue.tenantPhone),
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.colors.success.withAlpha(26),
                                  borderRadius: AppRadius.allMd,
                                ),
                                child: Icon(
                                  Icons.call,
                                  color: context.colors.success,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Location Card
                  _InfoCard(
                    title: 'issue_detail.location'.tr(),
                    child: issue.hasLocation
                        ? Column(
                            children: [
                              if (issue.address != null) ...[
                                _TenantInfoRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'issue_detail.address'.tr(),
                                  value: issue.address!,
                                ),
                                AppSpacing.vGapLg,
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final locationService = ref.read(
                                      locationServiceProvider,
                                    );
                                    final success = await locationService
                                        .openMapsNavigation(
                                          issue.latitude!,
                                          issue.longitude!,
                                        );
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'issue_detail.maps_error'.tr(),
                                          ),
                                          backgroundColor: context.colors.error,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.directions_outlined),
                                  label: Text(
                                    'issue_detail.get_directions'.tr(),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 20,
                                color: context.colors.textTertiary,
                              ),
                              AppSpacing.gapMd,
                              Expanded(
                                child: Text(
                                  'issue_detail.no_location'.tr(),
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  AppSpacing.vGapLg,

                  // Media Attachments (if any)
                  if (issue.hasMedia) ...[
                    _InfoCard(
                      title: 'issue_detail.media_attachments'.tr(),
                      child: SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: issue.media.length,
                          separatorBuilder: (_, __) => AppSpacing.gapMd,
                          itemBuilder: (context, index) {
                            final media = issue.media[index];
                            return GestureDetector(
                              onTap: () {
                                // Open media gallery viewer with all media
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MediaGalleryViewer(
                                      mediaItems: issue.media,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: MediaThumbnailItem(media: media),
                            );
                          },
                        ),
                      ),
                    ),
                    AppSpacing.vGapLg,
                  ],

                  // Assignment History Card
                  if (issue.assignments.isNotEmpty) ...[
                    _InfoCard(
                      title: 'issue_detail.assignment_history'.tr(),
                      child: Column(
                        children: issue.assignments.map((assignment) {
                          return _AssignmentCard(
                            assignment: assignment,
                            onEdit:
                                canManage &&
                                    assignment.status ==
                                        AssignmentStatus.assigned
                                ? () => context.push(
                                    '/admin/issues/${issue.id}/assignments/${assignment.id}/edit',
                                  )
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                    AppSpacing.vGapLg,
                  ],

                  // Timeline Card
                  if (issue.timeline.isNotEmpty) ...[
                    _InfoCard(
                      title: 'issue.timeline'.tr(),
                      child: Column(
                        children: issue.timeline.asMap().entries.map((entry) {
                          final index = entry.key;
                          final timeline = entry.value;
                          final isLast = index == issue.timeline.length - 1;
                          return _TimelineItem(
                            timeline: timeline,
                            isLast: isLast,
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Bottom spacing for action buttons
                  SizedBox(
                    height: canManage && issue.status.isActive
                        ? 100
                        : AppSpacing.xl,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Action Buttons (role-based)
      bottomNavigationBar: canManage && issue.status.isActive
          ? Container(
              padding: AppSpacing.allLg,
              decoration: BoxDecoration(
                color: context.colors.card,
                boxShadow: context.bottomNavShadow,
              ),
              child: SafeArea(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(children: _buildBottomActions(context)),
              ),
            )
          : null,
    );
  }

  IconData _getPriorityIcon(IssuePriority priority) {
    return switch (priority) {
      IssuePriority.high => Icons.arrow_upward,
      IssuePriority.medium => Icons.remove,
      IssuePriority.low => Icons.arrow_downward,
    };
  }

  List<Widget> _buildBottomActions(BuildContext context) {
    switch (issue.status) {
      case IssueStatus.pending:
        return [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(context),
              icon: const Icon(Icons.cancel_outlined),
              label: Text('common.cancel'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(color: context.colors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.assignment_ind),
              label: Text('admin.assign_btn'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ];
      case IssueStatus.assigned:
      case IssueStatus.inProgress:
        return [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(context),
              icon: const Icon(Icons.cancel_outlined),
              label: Text('common.cancel'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(color: context.colors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.person_add),
              label: Text('admin.add_assignment'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ];
      case IssueStatus.finished:
        return [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRejectDialog(context),
              icon: const Icon(Icons.cancel_outlined),
              label: Text('approve.reject_work'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(color: context.colors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('admin.approve'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'assign':
        onAssign();
        break;
      case 'approve':
        onApprove();
        break;
      case 'cancel':
        _showCancelDialog(context);
        break;
    }
  }

  void _showCancelDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('issue_detail.cancel_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('issue_detail.cancel_reason_prompt'.tr()),
            AppSpacing.vGapMd,
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'issue_detail.cancel_reason_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('issue_detail.no_keep'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('issue_detail.min_chars_error'.tr()),
                    backgroundColor: context.colors.error,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              onCancel(reasonController.text);
            },
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text('issue_detail.yes_cancel'.tr()),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('approve.reject_work'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('approve.rejection_reason_prompt'.tr()),
            AppSpacing.vGapMd,
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'approve.rejection_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('approve.work_rejected'.tr()),
                  backgroundColor: context.colors.warning,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text('approve.reject'.tr()),
          ),
        ],
      ),
    );
  }

  void _callPhone(BuildContext context, String? phone) {
    if (phone == null) return;
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('common.phone_copied'.tr(namedArgs: {'phone': phone})),
        action: SnackBarAction(label: 'common.ok'.tr(), onPressed: () {}),
      ),
    );
  }

}

/// Info card wrapper
class _InfoCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _InfoCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            AppSpacing.vGapMd,
          ],
          child,
        ],
      ),
    );
  }
}

/// Tenant info row
class _TenantInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _TenantInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.textTertiary),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[AppSpacing.gapMd, trailing!],
      ],
    );
  }
}

/// Assignment card widget
class _AssignmentCard extends StatelessWidget {
  final dynamic assignment;
  final VoidCallback? onEdit;

  const _AssignmentCard({required this.assignment, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final status = assignment.status as AssignmentStatus;

    return Container(
      padding: AppSpacing.allMd,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.allMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: context.colors.primary.withAlpha(26),
                backgroundImage: assignment.serviceProvider?.userProfilePhotoUrl != null &&
                        assignment.serviceProvider!.userProfilePhotoUrl!.isNotEmpty
                    ? NetworkImage(assignment.serviceProvider!.userProfilePhotoUrl!)
                    : null,
                child: assignment.serviceProvider?.userProfilePhotoUrl == null ||
                        assignment.serviceProvider!.userProfilePhotoUrl!.isEmpty
                    ? Text(
                        (assignment.serviceProviderName ?? 'SP')[0].toUpperCase(),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.serviceProviderName ??
                          'sp.service_provider'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      assignment.getCategoryName(context.locale.languageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(context, status).withAlpha(26),
                  borderRadius: AppRadius.badgeRadius,
                ),
                child: Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(context, status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Edit button for editable assignments
              if (onEdit != null && status == AssignmentStatus.assigned) ...[
                AppSpacing.gapSm,
                InkWell(
                  onTap: onEdit,
                  borderRadius: AppRadius.buttonRadius,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (assignment.scheduledDate != null) ...[
            AppSpacing.vGapSm,
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
                AppSpacing.gapXs,
                // Show date range for multi-day, single date otherwise
                Expanded(
                  child: Text(
                    assignment.isMultiDay && assignment.scheduledDateRange != null
                        ? '${'admin.assign.scheduled_label'.tr()}: ${assignment.scheduledDateRange}'
                        : '${'admin.assign.scheduled_label'.tr()}: ${assignment.scheduledDateFormatted}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                // Multi-day badge
                if (assignment.isMultiDay) ...[
                  AppSpacing.gapSm,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withAlpha(26),
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Text(
                      '${assignment.spanDays} ${'time.days'.tr()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Time slot display (multi-slot aware)
          if (assignment.timeSlotId != null || assignment.hasMultipleSlots) ...[
            AppSpacing.vGapSm,
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
                AppSpacing.gapXs,
                if (assignment.hasMultipleSlots) ...[
                  // Multi-slot display
                  Text(
                    'admin.assign.slots_selected'.tr(namedArgs: {
                      'count': assignment.timeSlotCount.toString(),
                    }),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.info.withAlpha(26),
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Text(
                      'admin.assign.multi_slot'.tr(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ] else if (assignment.timeSlotDisplay != null) ...[
                  // Single slot display
                  Text(
                    assignment.timeSlotDisplay!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Time range override display
          if (assignment.assignedTimeRange != null) ...[
            AppSpacing.vGapSm,
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
                AppSpacing.gapXs,
                Text(
                  '${'admin.assign.work_time_range'.tr()}: ${assignment.assignedTimeRange}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (assignment.notes != null && assignment.notes!.isNotEmpty) ...[
            AppSpacing.vGapSm,
            Text(
              'common.notes_label'.tr(namedArgs: {'text': assignment.notes ?? ''}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (assignment.consumables.isNotEmpty) ...[
            AppSpacing.vGapSm,
            Text(
              'assignment.materials_used'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vGapXs,
            ...assignment.consumables.map(
              (c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: context.colors.textTertiary,
                    ),
                    AppSpacing.gapXs,
                    Expanded(
                      child: Text(
                        c.getDisplayName(context.locale.languageCode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => context.colors.statusAssigned,
      AssignmentStatus.inProgress => context.colors.statusInProgress,
      AssignmentStatus.onHold => context.colors.warning,
      AssignmentStatus.finished => context.colors.info,
      AssignmentStatus.completed => context.colors.statusCompleted,
    };
  }
}

/// Timeline item widget
class _TimelineItem extends StatelessWidget {
  final dynamic timeline;
  final bool isLast;

  const _TimelineItem({required this.timeline, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final action = timeline.action as TimelineAction;
    final color = action.isPositive
        ? context.colors.primary
        : context.colors.error;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: context.colors.border,
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Text(
                        timeline.timeAgo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    timeline.getDescription(context.locale.languageCode),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (timeline.hasNotes) ...[
                    AppSpacing.vGapXs,
                    Text(
                      '"${timeline.notes}"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
