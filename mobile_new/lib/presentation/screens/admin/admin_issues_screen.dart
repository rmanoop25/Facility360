import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/issue_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/admin_issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/error_placeholder.dart';
import '../../widgets/common/offline_banner.dart';

/// Admin Issues Screen with filters and actions
class AdminIssuesScreen extends ConsumerStatefulWidget {
  const AdminIssuesScreen({super.key});

  @override
  ConsumerState<AdminIssuesScreen> createState() => _AdminIssuesScreenState();
}

class _AdminIssuesScreenState extends ConsumerState<AdminIssuesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _scrollController.addListener(_onScroll);

    // Set initial tab from query parameter if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouter.of(context).routeInformationProvider.value.uri;
      final tabParam = uri.queryParameters['tab'];
      if (tabParam != null) {
        final tabIndex = int.tryParse(tabParam);
        if (tabIndex != null && tabIndex >= 0 && tabIndex < 6) {
          _tabController.animateTo(tabIndex);
        }
      }
    });
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
      ref.read(adminIssueListProvider.notifier).loadMore();
    }
  }

  void _onSearchSubmitted(String query) {
    ref.read(adminIssueListProvider.notifier).setSearchQuery(
          query.isNotEmpty ? query : null,
        );
  }

  List<IssueModel> _getFilteredIssues(
      List<IssueModel> issues, int tabIndex) {
    var filtered = issues;

    // Filter by tab
    filtered = switch (tabIndex) {
      0 => filtered, // All
      1 => filtered.where((i) => i.status == IssueStatus.pending).toList(),
      2 => filtered.where((i) => i.status == IssueStatus.assigned).toList(), // Assigned
      3 => filtered.where((i) => i.status == IssueStatus.inProgress).toList(), // Active
      4 => filtered.where((i) => i.status == IssueStatus.finished).toList(),
      5 => filtered.where((i) => i.status == IssueStatus.completed).toList(),
      _ => filtered,
    };

    // Filter by search (local filter)
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((i) {
        final title = i.title.toLowerCase();
        final description = (i.description ?? '').toLowerCase();
        return title.contains(_searchQuery) ||
            description.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  Future<void> _onRefresh() async {
    await ref.read(adminIssueListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role.canManageIssues ?? false;
    final issueState = ref.watch(adminIssueListProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: (user?.canCreateIssues ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/issues/create'),
              icon: const Icon(Icons.add_rounded),
              label: Text('admin.create_issue.fab'.tr()),
            )
          : null,
      appBar: AppBar(
        title: Text('nav.issues'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'admin.all'.tr()),
            Tab(text: 'common.pending'.tr()),
            Tab(text: 'common.assigned'.tr()),
            Tab(text: 'common.active'.tr()),
            Tab(text: 'admin.finished'.tr()),
            Tab(text: 'common.completed'.tr()),
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
                hintText: 'admin.search_issues'.tr(),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchSubmitted('');
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
              onSubmitted: _onSearchSubmitted,
            ),
          ),

          // Issue list
          Expanded(
            // Only show loading if we have NO cached data
            child: issueState.issues.isEmpty && issueState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : issueState.error != null && issueState.issues.isEmpty
                    ? ErrorPlaceholder(
                        isFullScreen: false,
                        onRetry: () =>
                            ref.read(adminIssueListProvider.notifier).loadIssues(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(6, (tabIndex) {
                          final filteredIssues = _getFilteredIssues(
                              issueState.issues, tabIndex);

                          if (filteredIssues.isEmpty &&
                              !issueState.isLoading) {
                            return _EmptyState(tabIndex: tabIndex);
                          }

                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              controller:
                                  tabIndex == 0 ? _scrollController : null,
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
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md),
                                  child: _AdminIssueCard(
                                    issue: issue,
                                    canManage: canManage,
                                    onTap: () =>
                                        context.push('/admin/issues/${issue.id}'),
                                    onAssign: canManage &&
                                            issue.status == IssueStatus.pending
                                        ? () => context.push(
                                            '/admin/issues/${issue.id}/assign')
                                        : null,
                                    onApprove: canManage &&
                                            issue.status == IssueStatus.finished
                                        ? () => context.push(
                                            '/admin/issues/${issue.id}/approve')
                                        : null,
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

/// Admin issue card with action buttons
class _AdminIssueCard extends StatelessWidget {
  final IssueModel issue;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback? onAssign;
  final VoidCallback? onApprove;

  const _AdminIssueCard({
    required this.issue,
    required this.canManage,
    required this.onTap,
    this.onAssign,
    this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final status = issue.status;
    final priority = issue.priority;

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
                      color: context.priorityColor(priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  AppSpacing.gapSm,
                  // Category
                  Expanded(
                    child: Text(
                      issue.getCategoryNames('en'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

              AppSpacing.vGapXs,

              // Unit info and time
              Row(
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    size: 14,
                    color: context.colors.textTertiary,
                  ),
                  AppSpacing.gapXs,
                  Expanded(
                    child: Text(
                      issue.tenantAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Assignment count badge
                  if (issue.assignments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: context.colors.primaryLight.withAlpha(51),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 12,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            issue.assignments.length == 1
                                ? 'admin.assignment_count_one'.tr()
                                : 'admin.assignment_count'.tr(namedArgs: {'count': '${issue.assignments.length}'}),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    issue.timeAgo,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                  ),
                ],
              ),

              // Action buttons (only for managers/admins)
              if (onAssign != null || onApprove != null) ...[
                AppSpacing.vGapMd,
                const Divider(height: 1),
                AppSpacing.vGapMd,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onAssign != null)
                      TextButton.icon(
                        onPressed: onAssign,
                        icon: const Icon(Icons.assignment_ind_rounded, size: 18),
                        label: Text('admin.assign_btn'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.primary,
                        ),
                      ),
                    if (onApprove != null)
                      TextButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text('admin.approve'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.success,
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
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tabIndex) {
      0 => (
          Icons.inbox_rounded,
          'admin.no_issues'.tr(),
          'admin.all_appear'.tr()
        ),
      1 => (
          Icons.pending_actions_rounded,
          'admin.no_pending'.tr(),
          'admin.pending_appear'.tr()
        ),
      2 => (
          Icons.assignment_ind_rounded,
          'admin.no_assigned'.tr(),
          'admin.assigned_appear'.tr()
        ),
      3 => (
          Icons.engineering_rounded,
          'admin.no_active'.tr(),
          'admin.active_appear'.tr()
        ),
      4 => (
          Icons.fact_check_rounded,
          'admin.no_finished'.tr(),
          'admin.finished_appear'.tr()
        ),
      5 => (
          Icons.check_circle_rounded,
          'admin.no_completed'.tr(),
          'tenant.completed_appear'.tr()
        ),
      _ => (Icons.inbox_rounded, 'admin.no_issues'.tr(), 'admin.all_appear'.tr()),
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

