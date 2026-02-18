import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/media_model.dart';
import '../../../data/models/timeline_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/issue_provider.dart';
import '../../widgets/common/assignment_card.dart';
import '../../widgets/common/error_placeholder.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/shimmer/shimmer.dart';
import '../../widgets/common/sync_status_indicator.dart';
import '../../widgets/common/media_gallery_viewer.dart';
import '../../widgets/common/media_thumbnail_item.dart';

/// Issue detail screen showing full issue information and timeline
class IssueDetailScreen extends ConsumerStatefulWidget {
  final String issueId;
  final bool isLocalId;

  const IssueDetailScreen({
    super.key,
    required this.issueId,
    this.isLocalId = false,
  });

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle local issue (created offline, not yet synced)
    if (widget.isLocalId) {
      return _buildLocalIssueView(context);
    }

    final issueId = int.tryParse(widget.issueId);

    if (issueId == null || issueId <= 0) {
      return Scaffold(
        appBar: AppBar(title: Text('issue_detail.title'.tr())),
        body: Center(child: Text('issue_detail.invalid_id_error'.tr())),
      );
    }

    final issueAsync = ref.watch(issueDetailProvider(issueId));
    final cancelState = ref.watch(cancelIssueProvider);

    return issueAsync.when(
      data: (issue) => _buildContent(context, issue, cancelState),
      loading: () => Scaffold(
        appBar: AppBar(title: Text('issue_detail.title'.tr())),
        body: const IssueDetailShimmer(),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('issue_detail.title'.tr())),
        body: ErrorPlaceholder(
          onRetry: () => ref.invalidate(issueDetailProvider(issueId)),
        ),
      ),
    );
  }

  /// Build view for locally-created issues (not yet synced to server)
  Widget _buildLocalIssueView(BuildContext context) {
    final issueAsync = ref.watch(issueByLocalIdProvider(widget.issueId));

    return issueAsync.when(
      data: (issue) {
        if (issue == null) {
          return Scaffold(
            appBar: AppBar(title: Text('issue_detail.title'.tr())),
            body: Center(
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
                    'issue_detail.not_found'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  AppSpacing.vGapMd,
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('common.go_back'.tr()),
                  ),
                ],
              ),
            ),
          );
        }
        // Build content without cancel functionality (local issues can't be cancelled)
        return _buildLocalIssueContent(context, issue);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text('issue_detail.title'.tr())),
        body: const IssueDetailShimmer(),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('issue_detail.title'.tr())),
        body: ErrorPlaceholder(
          onRetry: () => ref.invalidate(issueByLocalIdProvider(widget.issueId)),
        ),
      ),
    );
  }

  /// Build content for local issue (similar to _buildContent but without cancel)
  Widget _buildLocalIssueContent(BuildContext context, IssueModel issue) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          // Offline banner
          const SliverOfflineBanner(),

          // App Bar with status - pinned header
          SliverAppBar(
            pinned: true,
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            toolbarHeight: 100,
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and sync badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.onPrimary.withOpacity(0.2),
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
                    SyncStatusIndicator(status: issue.syncStatus),
                  ],
                ),
                AppSpacing.vGapSm,
                // Local issue indicator
                Text(
                  'issue_detail.local_issue'.tr(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onPrimary.withOpacity(0.8),
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
                  // Pending sync info card
                  Container(
                    padding: AppSpacing.allMd,
                    decoration: BoxDecoration(
                      color: context.colors.warning.withOpacity(0.1),
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                        color: context.colors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          color: context.colors.warning,
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: Text(
                            'issue_detail.pending_sync_info'.tr(),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Title & Priority
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue.title,
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _PriorityBadge(priority: issue.priority),
                          ],
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
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Categories
                  if (issue.categories.isNotEmpty) ...[
                    _InfoCard(
                      title: 'issue_detail.categories'.tr(),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: issue.categories.map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primaryLight.withAlpha(26),
                              borderRadius: AppRadius.badgeRadius,
                              border: Border.all(
                                color: context.colors.primaryLight.withAlpha(
                                  77,
                                ),
                              ),
                            ),
                            child: Text(
                              cat.localizedName(context.locale.languageCode),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    AppSpacing.vGapLg,
                  ],

                  // Details
                  _InfoCard(
                    title: 'issue_detail.details'.tr(),
                    child: Column(
                      children: [
                        if (issue.createdAt != null) ...[
                          _DetailRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'issue_detail.created'.tr(),
                            value: _formatDate(issue.createdAt!),
                          ),
                          AppSpacing.vGapMd,
                        ],
                        _DetailRow(
                          icon: Icons.flag_outlined,
                          label: 'issue_detail.priority'.tr(),
                          value: issue.priority.label,
                          valueColor: context.priorityColor(issue.priority),
                        ),
                        AppSpacing.vGapMd,
                        _DetailRow(
                          icon: Icons.sync_outlined,
                          label: 'issue_detail.sync_status'.tr(),
                          value: issue.syncStatus.label,
                          valueColor: _getSyncColor(context, issue.syncStatus),
                        ),
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
                                _DetailRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'issue_detail.address'.tr(),
                                  value: issue.address!,
                                ),
                              ] else ...[
                                _DetailRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'issue_detail.coordinates'.tr(),
                                  value:
                                      '${issue.latitude?.toStringAsFixed(4)}, ${issue.longitude?.toStringAsFixed(4)}',
                                ),
                              ],
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

                  // Media attachments (local issue - offline created)
                  _InfoCard(
                    title: 'issue_detail.media_attachments'.tr(),
                    child: issue.media.isNotEmpty
                        ? SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: issue.media.length,
                              separatorBuilder: (_, i) => AppSpacing.gapMd,
                              itemBuilder: (context, index) {
                                final media = issue.media[index];
                                return GestureDetector(
                                  onTap: () {
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
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 20,
                                color: context.colors.textTertiary,
                              ),
                              AppSpacing.gapMd,
                              Text(
                                'issue_detail.no_photos'.tr(),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),

                  AppSpacing.vGapXxl,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    IssueModel issue,
    CancelIssueState cancelState,
  ) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          // Offline banner
          const SliverOfflineBanner(),

          // App Bar with status - pinned header
          SliverAppBar(
            pinned: true,
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            toolbarHeight: 100,
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and sync badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.onPrimary.withOpacity(0.2),
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
                    if (issue.syncStatus != SyncStatus.synced) ...[
                      AppSpacing.gapSm,
                      SyncStatusIndicator(status: issue.syncStatus),
                    ],
                  ],
                ),
                AppSpacing.vGapSm,
                // Issue ID
                Text(
                  'Issue #${issue.id}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onPrimary.withOpacity(0.8),
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
                  // Title & Priority
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue.title,
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _PriorityBadge(priority: issue.priority),
                          ],
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
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Categories
                  if (issue.categories.isNotEmpty) ...[
                    _InfoCard(
                      title: 'issue_detail.categories'.tr(),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: issue.categories.map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primaryLight.withAlpha(26),
                              borderRadius: AppRadius.badgeRadius,
                              border: Border.all(
                                color: context.colors.primaryLight.withAlpha(
                                  77,
                                ),
                              ),
                            ),
                            child: Text(
                              cat.localizedName(context.locale.languageCode),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    AppSpacing.vGapLg,
                  ],

                  // Details
                  _InfoCard(
                    title: 'issue_detail.details'.tr(),
                    child: Column(
                      children: [
                        if (issue.createdAt != null) ...[
                          _DetailRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'issue_detail.created'.tr(),
                            value: _formatDate(issue.createdAt!),
                          ),
                          AppSpacing.vGapMd,
                        ],
                        _DetailRow(
                          icon: Icons.flag_outlined,
                          label: 'issue_detail.priority'.tr(),
                          value: issue.priority.label,
                          valueColor: context.priorityColor(issue.priority),
                        ),
                        AppSpacing.vGapMd,
                        _DetailRow(
                          icon: Icons.sync_outlined,
                          label: 'issue_detail.sync_status'.tr(),
                          value: issue.syncStatus.label,
                          valueColor: _getSyncColor(context, issue.syncStatus),
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Location Card - Always show
                  _InfoCard(
                    title: 'issue_detail.location'.tr(),
                    child: issue.hasLocation
                        ? issue.address != null
                            ? _DetailRow(
                                icon: Icons.location_on_rounded,
                                label: 'issue_detail.address'.tr(),
                                value: issue.address!,
                              )
                            : _DetailRow(
                                icon: Icons.location_on_rounded,
                                label: 'issue_detail.location'.tr(),
                                value: '${issue.latitude}, ${issue.longitude}',
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

                  // Media/Photos - Always show
                  _InfoCard(
                    title: 'issue_detail.photos'.tr(),
                    child: issue.media.isNotEmpty
                        ? SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: issue.media.length,
                              separatorBuilder: (_, i) => AppSpacing.gapMd,
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
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 20,
                                color: context.colors.textTertiary,
                              ),
                              AppSpacing.gapMd,
                              Text(
                                'issue_detail.no_photos'.tr(),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),

                  AppSpacing.vGapLg,

                  // Assignments Section
                  _InfoCard(
                    title: 'issue_detail.assignments'.tr(),
                    child: issue.assignments.isNotEmpty
                        ? Column(
                            children: issue.assignments.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final assignment = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == issue.assignments.length - 1
                                      ? 0
                                      : AppSpacing.md,
                                ),
                                child: AssignmentCard(
                                  assignment: assignment,
                                  showWorkProgress: true,
                                  locale: context.locale.languageCode,
                                ),
                              );
                            }).toList(),
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 20,
                                color: context.colors.textTertiary,
                              ),
                              AppSpacing.gapMd,
                              Text(
                                'issue_detail.assignment_card.no_assignments'
                                    .tr(),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),

                  AppSpacing.vGapLg,

                  // Timeline
                  _InfoCard(
                    title: 'issue_detail.timeline'.tr(),
                    child: issue.timeline.isNotEmpty
                        ? Column(
                            children: issue.timeline.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final timeline = entry.value;
                              return _TimelineItem(
                                timeline: timeline,
                                isFirst: index == 0,
                                isLast: index == issue.timeline.length - 1,
                              );
                            }).toList(),
                          )
                        : _buildDefaultTimeline(issue),
                  ),

                  // Bottom spacing for cancel button
                  if (issue.status.isActive) ...[AppSpacing.vGapXxl],
                ],
              ),
            ),
          ),
        ],
      ),
      // Cancel button for active issues
      bottomNavigationBar: issue.status.isActive
          ? Container(
              padding: AppSpacing.allLg,
              decoration: BoxDecoration(
                color: context.colors.card,
                boxShadow: context.bottomNavShadow,
              ),
              child: SafeArea(
                child: OutlinedButton.icon(
                  onPressed: cancelState.isLoading
                      ? null
                      : () => _showCancelDialog(),
                  icon: cancelState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    cancelState.isLoading
                        ? 'issue_detail.cancelling'.tr()
                        : 'issue_detail.cancel_issue'.tr(),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.error,
                    side: BorderSide(color: context.colors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDefaultTimeline(IssueModel issue) {
    // Fallback timeline when no timeline data from API
    return Column(
      children: [
        _TimelineItemSimple(
          icon: Icons.add_circle_outline,
          title: 'issue_detail.tl_created'.tr(),
          subtitle: 'issue_detail.tl_created_desc'.tr(),
          time: issue.createdAt != null ? _formatTimeAgo(issue.createdAt!) : '',
          isFirst: true,
          isLast: issue.status == IssueStatus.pending,
        ),
        if (issue.status != IssueStatus.pending) ...[
          _TimelineItemSimple(
            icon: Icons.assignment_ind_outlined,
            title: 'issue_detail.tl_assigned'.tr(),
            subtitle: 'issue_detail.tl_assigned_desc'.tr(),
            time: '',
            isFirst: false,
            isLast: issue.status == IssueStatus.assigned,
          ),
        ],
        if (issue.status == IssueStatus.inProgress) ...[
          _TimelineItemSimple(
            icon: Icons.engineering_outlined,
            title: 'issue_detail.tl_in_progress'.tr(),
            subtitle: 'issue_detail.tl_in_progress_desc'.tr(),
            time: '',
            isFirst: false,
            isLast: true,
          ),
        ],
        if (issue.status == IssueStatus.completed) ...[
          _TimelineItemSimple(
            icon: Icons.check_circle_outline,
            title: 'issue_detail.tl_completed'.tr(),
            subtitle: 'issue_detail.tl_completed_desc'.tr(),
            time: '',
            isFirst: false,
            isLast: true,
            isSuccess: true,
          ),
        ],
        if (issue.status == IssueStatus.cancelled) ...[
          _TimelineItemSimple(
            icon: Icons.cancel_outlined,
            title: 'issue_detail.tl_cancelled'.tr(),
            subtitle: 'issue_detail.tl_cancelled_desc'.tr(),
            time: '',
            isFirst: false,
            isLast: true,
            isError: true,
          ),
        ],
      ],
    );
  }

  Color _getSyncColor(BuildContext context, SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => context.colors.success,
      SyncStatus.pending => context.colors.warning,
      SyncStatus.syncing => context.colors.info,
      SyncStatus.failed => context.colors.error,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'time_format.days_ago'.tr(
        namedArgs: {'count': '${difference.inDays}'},
      );
    } else if (difference.inHours > 0) {
      return 'time_format.hours_ago'.tr(
        namedArgs: {'count': '${difference.inHours}'},
      );
    } else if (difference.inMinutes > 0) {
      return 'time_format.minutes_ago'.tr(
        namedArgs: {'count': '${difference.inMinutes}'},
      );
    }
    return 'time_format.just_now'.tr();
  }

  void _showCancelDialog() {
    final issueId = int.tryParse(widget.issueId);
    if (issueId == null) return;

    _reasonController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('issue_detail.cancel_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('issue_detail.cancel_confirm'.tr()),
            AppSpacing.vGapLg,
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'issue_detail.reason'.tr(),
                hintText: 'issue_detail.reason_hint'.tr(),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('issue_detail.no_keep'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelIssue(issueId);
            },
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text('issue_detail.yes_cancel'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelIssue(int issueId) async {
    final success = await ref
        .read(cancelIssueProvider.notifier)
        .cancelIssue(
          issueId,
          reason: _reasonController.text.trim().isNotEmpty
              ? _reasonController.text.trim()
              : null,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('issue_detail.cancelled_success'.tr()),
          backgroundColor: context.colors.success,
        ),
      );
      // Refresh the issue detail
      ref.invalidate(issueDetailProvider(issueId));
      // Refresh the issue list to reflect the updated status
      ref.read(issueListProvider.notifier).refresh();
      // Optionally navigate back
      context.pop();
    } else if (mounted) {
      final error = ref.read(cancelIssueProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'issue_detail.cancel_failed'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
    }
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

/// Priority badge
class _PriorityBadge extends StatelessWidget {
  final IssuePriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = context.priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: AppRadius.badgeRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            priority == IssuePriority.high
                ? Icons.arrow_upward
                : priority == IssuePriority.low
                ? Icons.arrow_downward
                : Icons.remove,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.textTertiary),
        AppSpacing.gapMd,
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Timeline item widget using TimelineModel
class _TimelineItem extends StatelessWidget {
  final TimelineModel timeline;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.timeline,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = timeline.isPositive
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
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(timeline.action.icon, size: 16, color: color),
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
                          timeline.action.label,
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
                    timeline.performerName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (timeline.hasNotes) ...[
                    AppSpacing.vGapXs,
                    Text(
                      timeline.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
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

/// Simple timeline item widget (fallback when no API timeline)
class _TimelineItemSimple extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool isFirst;
  final bool isLast;
  final bool isSuccess;
  final bool isError;

  const _TimelineItemSimple({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isFirst,
    required this.isLast,
    this.isSuccess = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? context.colors.error
        : isSuccess
        ? context.colors.statusCompleted
        : context.colors.primary;

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
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
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
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        AppSpacing.gapMd,
                        Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.colors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
