import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/issue_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/issue_provider.dart';
import '../../widgets/common/error_placeholder.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/sync_status_indicator.dart';
import '../../widgets/shimmer/shimmer.dart';

/// Issue list screen with filtering tabs
class IssueListScreen extends ConsumerStatefulWidget {
  const IssueListScreen({super.key});

  @override
  ConsumerState<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends ConsumerState<IssueListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    // No-op: Tab filtering is done locally via _getFilteredIssues
    // This prevents unnecessary API calls and loading spinners
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(issueListProvider.notifier).loadMore();
    }
  }

  List<IssueModel> _getFilteredIssues(List<IssueModel> issues, int tabIndex) {
    return switch (tabIndex) {
      0 => issues, // All
      1 => issues.where((i) => i.status.isActive).toList(), // Active
      2 => issues.where((i) => i.status == IssueStatus.completed).toList(),
      3 => issues.where((i) => i.status == IssueStatus.cancelled).toList(),
      _ => issues,
    };
  }

  Future<void> _onRefresh() async {
    await ref.read(issueListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final issueState = ref.watch(issueListProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('tenant.my_issues'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'admin.all'.tr()),
            Tab(text: 'common.active'.tr()),
            Tab(text: 'common.completed'.tr()),
            Tab(text: 'common.cancelled'.tr()),
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
                hintText: 'common.search'.tr(),
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

          // Issue list
          Expanded(
            // Only show shimmer if we have NO cached data
            child: issueState.issues.isEmpty && issueState.isLoading
                ? Padding(
                    padding: AppSpacing.horizontalLg,
                    child: const IssueListShimmer(itemCount: 6),
                  )
                : issueState.error != null && issueState.issues.isEmpty
                    ? ErrorPlaceholder(
                        isFullScreen: false,
                        onRetry: () =>
                            ref.read(issueListProvider.notifier).loadIssues(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(4, (tabIndex) {
                          final filteredIssues =
                              _getFilteredIssues(issueState.issues, tabIndex);

                          // Handle empty states
                          if (filteredIssues.isEmpty) {
                            // If we have issues but filter excludes all, show filter-specific empty
                            if (issueState.issues.isNotEmpty) {
                              return _EmptyFilteredState(tabIndex: tabIndex);
                            }
                            // If truly no issues at all and not loading, show create prompt
                            if (!issueState.isLoading) {
                              return _EmptyState(tabIndex: tabIndex);
                            }
                          }

                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              controller: tabIndex == 0 ? _scrollController : null,
                              padding: AppSpacing.horizontalLg,
                              itemCount: filteredIssues.length +
                                  (issueState.isLoadingMore && tabIndex == 0
                                      ? 1
                                      : 0),
                              itemBuilder: (context, index) {
                                // Loading indicator at the end
                                if (index >= filteredIssues.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(AppSpacing.lg),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final issue = filteredIssues[index];
                                return Padding(
                                  key: ValueKey('issue_${issue.id}_${issue.localId ?? ''}'),
                                  padding:
                                      const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: _IssueListItem(
                                    issue: issue,
                                    onTap: () {
                                      // Navigate based on whether it's local or server issue
                                      if (issue.id > 0) {
                                        context.push('/tenant/issues/${issue.id}');
                                      } else if (issue.localId != null) {
                                        // For local-only issues, navigate to local detail view
                                        context.push('/tenant/issues/local/${issue.localId}');
                                      }
                                    },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.tenantCreateIssue),
        icon: const Icon(Icons.add),
        label: Text('tenant.new_issue'.tr()),
      ),
    );
  }
}

/// Issue list item widget
class _IssueListItem extends StatelessWidget {
  final IssueModel issue;
  final VoidCallback onTap;

  const _IssueListItem({
    required this.issue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = issue.categories.isNotEmpty
        ? issue.categories.first.localizedName(context.locale.languageCode)
        : 'common.na'.tr();
    final description = issue.description ?? '';

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
                  // Priority dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.priorityColor(issue.priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  AppSpacing.gapSm,
                  // Category
                  Expanded(
                    child: Text(
                      categoryName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppSpacing.gapSm,
                  // Sync status indicator (if not synced)
                  if (issue.syncStatus != SyncStatus.synced)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: SyncStatusIndicator(status: issue.syncStatus),
                    ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.issueStatusBgColor(issue.status),
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Text(
                      issue.status.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.issueStatusColor(issue.status),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),

              AppSpacing.vGapMd,

              // Title
              Text(
                issue.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              if (description.isNotEmpty) ...[
                AppSpacing.vGapXs,
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              AppSpacing.vGapMd,

              // Footer - time ago
              if (issue.createdAt != null)
                Text(
                  _formatTimeAgo(issue.createdAt!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'common.ago'.tr(namedArgs: {'time': '$years ${years == 1 ? 'time.year'.tr() : 'time.years'.tr()}'});
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'common.ago'.tr(namedArgs: {'time': '$months ${months == 1 ? 'time.month'.tr() : 'time.months'.tr()}'});
    } else if (difference.inDays > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${difference.inDays} ${difference.inDays == 1 ? 'time.day'.tr() : 'time.days'.tr()}'});
    } else if (difference.inHours > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${difference.inHours} ${difference.inHours == 1 ? 'time.hour'.tr() : 'time.hours'.tr()}'});
    } else if (difference.inMinutes > 0) {
      return 'common.ago'.tr(namedArgs: {'time': '${difference.inMinutes} ${difference.inMinutes == 1 ? 'time.minute'.tr() : 'time.minutes'.tr()}'});
    } else {
      return 'common.just_now'.tr();
    }
  }
}

/// Empty state widget - shown when truly no issues exist
class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tabIndex) {
      0 => (Icons.inbox_outlined, 'tenant.no_issues'.tr(), 'tenant.create_first'.tr()),
      1 => (Icons.pending_actions_outlined, 'tenant.no_active'.tr(), 'tenant.all_resolved'.tr()),
      2 => (Icons.check_circle_outline, 'tenant.no_completed'.tr(), 'tenant.completed_appear'.tr()),
      3 => (Icons.cancel_outlined, 'tenant.no_cancelled'.tr(), 'tenant.cancelled_appear'.tr()),
      _ => (Icons.inbox_outlined, 'tenant.no_issues'.tr(), 'tenant.create_first'.tr()),
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

/// Empty filtered state widget - shown when issues exist but filter excludes all
class _EmptyFilteredState extends StatelessWidget {
  final int tabIndex;

  const _EmptyFilteredState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (tabIndex) {
      1 => (Icons.pending_actions_outlined, 'tenant.no_active_filtered'.tr()),
      2 => (Icons.check_circle_outline, 'tenant.no_completed_filtered'.tr()),
      3 => (Icons.cancel_outlined, 'tenant.no_cancelled_filtered'.tr()),
      _ => (Icons.inbox_outlined, 'tenant.no_filtered'.tr()),
    };

    return Center(
      child: Padding(
        padding: AppSpacing.allXxl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: context.colors.textTertiary),
            AppSpacing.vGapMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

