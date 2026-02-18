import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../../core/theme/app_spacing.dart';

/// A banner that displays when the app is offline.
///
/// Shows connectivity status and pending sync count.
/// Automatically hides when online.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    if (isOnline) {
      return const SizedBox.shrink();
    }

    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.warning,
        boxShadow: context.cardShadowSm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: context.colors.onPrimary,
              size: 18,
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                'connectivity.offline_message'.tr(),
                style: TextStyle(
                  color: context.colors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            pendingCountAsync.when(
              data: (count) => count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: context.colors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sliver version of the offline banner for use in CustomScrollView
class SliverOfflineBanner extends ConsumerWidget {
  const SliverOfflineBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    if (isOnline) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return const SliverToBoxAdapter(
      child: OfflineBanner(),
    );
  }
}

/// A compact offline indicator for app bars
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    if (isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.warningBg,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: context.colors.warning, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: context.colors.warning,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'connectivity.offline_short'.tr(),
            style: TextStyle(
              color: context.colors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that shows syncing progress indicator
class SyncingIndicator extends ConsumerWidget {
  const SyncingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(syncQueueServiceProvider);

    if (!syncService.isProcessing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.infoBg,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: context.colors.syncSyncing, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.syncSyncing,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'connectivity.syncing'.tr(),
            style: TextStyle(
              color: context.colors.syncSyncing,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
