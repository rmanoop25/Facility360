import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/time_extension_request_model.dart';
import '../../providers/time_extension_provider.dart';
import '../../widgets/admin/permission_gate.dart';
import '../../widgets/common/error_placeholder.dart';

/// Admin screen for managing time extension requests
class TimeExtensionsScreen extends ConsumerStatefulWidget {
  const TimeExtensionsScreen({super.key});

  @override
  ConsumerState<TimeExtensionsScreen> createState() =>
      _TimeExtensionsScreenState();
}

class _TimeExtensionsScreenState extends ConsumerState<TimeExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionBasedGate(
      permission: 'view_time_extensions',
      child: Scaffold(
        appBar: AppBar(
          title: Text('extensions.title'.tr()),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'common.all'.tr()),
              Tab(text: 'extensions.status.pending'.tr()),
              Tab(text: 'extensions.status.approved'.tr()),
              Tab(text: 'extensions.status.rejected'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _ExtensionsList(status: null),
            _ExtensionsList(status: 'pending'),
            _ExtensionsList(status: 'approved'),
            _ExtensionsList(status: 'rejected'),
          ],
        ),
      ),
    );
  }
}

/// Extension list widget with filtering
class _ExtensionsList extends ConsumerWidget {
  final String? status;

  const _ExtensionsList({this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extensionsAsync = ref.watch(adminExtensionRequestsProvider(status));

    return extensionsAsync.when(
      data: (extensions) {
        if (extensions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: context.colors.textSecondary.withAlpha(77),
                ),
                AppSpacing.vGapMd,
                Text(
                  'extensions.no_requests'.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminExtensionRequestsProvider(status));
          },
          child: ListView.separated(
            padding: AppSpacing.allLg,
            itemCount: extensions.length,
            separatorBuilder: (_, __) => AppSpacing.vGapMd,
            itemBuilder: (context, index) {
              final extension = extensions[index];
              return _ExtensionCard(extension: extension);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorPlaceholder(
        isFullScreen: false,
        onRetry: () => ref.invalidate(adminExtensionRequestsProvider(status)),
      ),
    );
  }
}

/// Extension request card
class _ExtensionCard extends StatelessWidget {
  final TimeExtensionRequestModel extension;

  const _ExtensionCard({required this.extension});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          context.push('/admin/time-extensions/${extension.id}');
        },
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assignment #${extension.assignmentId}',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSpacing.vGapXs,
                        Text(
                          extension.requesterName ?? 'Unknown SP',
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: extension.status.color.withAlpha(26),
                      borderRadius: AppRadius.badgeRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          extension.status.icon,
                          size: 16,
                          color: extension.status.color,
                        ),
                        AppSpacing.gapXs,
                        Text(
                          extension.status.label,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: extension.status.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.vGapMd,
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: context.colors.textSecondary),
                  AppSpacing.gapXs,
                  Text(
                    '+${extension.requestedMinutes} minutes',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AppSpacing.gapLg,
                  Icon(Icons.calendar_today_outlined, size: 16, color: context.colors.textSecondary),
                  AppSpacing.gapXs,
                  Text(
                    DateFormat('MMM d, yyyy').format(extension.requestedAt),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
              if (extension.reason.isNotEmpty) ...[
                AppSpacing.vGapSm,
                Text(
                  extension.reason.length > 100
                      ? '${extension.reason.substring(0, 100)}...'
                      : extension.reason,
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
      ),
    );
  }
}
