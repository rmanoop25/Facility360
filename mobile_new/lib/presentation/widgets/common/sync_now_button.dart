import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../../core/theme/app_spacing.dart';

/// A button to manually trigger sync operations.
///
/// Shows sync status and allows users to force sync when online.
class SyncNowButton extends ConsumerWidget {
  const SyncNowButton({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  /// Whether to show the label text
  final bool showLabel;

  /// Whether to use compact styling
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncService = ref.watch(syncQueueServiceProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    return pendingCountAsync.when(
      data: (pendingCount) {
        final isProcessing = syncService.isProcessing;
        final hasPending = pendingCount > 0;

        if (compact) {
          return _buildCompactButton(
            context,
            ref,
            isOnline: isOnline,
            isProcessing: isProcessing,
            hasPending: hasPending,
            pendingCount: pendingCount,
          );
        }

        return _buildFullButton(
          context,
          ref,
          isOnline: isOnline,
          isProcessing: isProcessing,
          hasPending: hasPending,
          pendingCount: pendingCount,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    WidgetRef ref, {
    required bool isOnline,
    required bool isProcessing,
    required bool hasPending,
    required int pendingCount,
  }) {
    return IconButton(
      onPressed: isOnline && hasPending && !isProcessing
          ? () => _triggerSync(ref)
          : null,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          isProcessing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.syncSyncing,
                  ),
                )
              : Icon(
                  Icons.sync_rounded,
                  color: isOnline
                      ? (hasPending
                          ? context.colors.syncPending
                          : context.colors.textSecondary)
                      : context.colors.textDisabled,
                ),
          if (hasPending && !isProcessing)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.colors.syncPending,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  pendingCount > 9 ? '9+' : '$pendingCount',
                  style: TextStyle(
                    color: context.colors.onPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      tooltip: isOnline
          ? (hasPending
              ? 'sync.tap_to_sync'.tr()
              : 'sync.all_synced'.tr())
          : 'sync.offline_cannot_sync'.tr(),
    );
  }

  Widget _buildFullButton(
    BuildContext context,
    WidgetRef ref, {
    required bool isOnline,
    required bool isProcessing,
    required bool hasPending,
    required int pendingCount,
  }) {
    final buttonColor = isProcessing
        ? context.colors.syncSyncing
        : (hasPending ? context.colors.syncPending : context.colors.success);

    final isEnabled = isOnline && hasPending && !isProcessing;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? () => _triggerSync(ref) : null,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isEnabled
                ? buttonColor.withOpacity(0.1)
                : context.colors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(
              color: isEnabled ? buttonColor : context.colors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.syncSyncing,
                  ),
                )
              else
                Icon(
                  hasPending ? Icons.sync_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: isEnabled ? buttonColor : context.colors.textDisabled,
                ),
              if (showLabel) ...[
                AppSpacing.gapSm,
                Text(
                  _getLabel(
                    isOnline: isOnline,
                    isProcessing: isProcessing,
                    hasPending: hasPending,
                    pendingCount: pendingCount,
                  ),
                  style: TextStyle(
                    color:
                        isEnabled ? buttonColor : context.colors.textDisabled,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getLabel({
    required bool isOnline,
    required bool isProcessing,
    required bool hasPending,
    required int pendingCount,
  }) {
    if (!isOnline) {
      return 'sync.offline'.tr();
    }
    if (isProcessing) {
      return 'sync.syncing'.tr();
    }
    if (hasPending) {
      return 'sync.sync_now'.tr(namedArgs: {'count': '$pendingCount'});
    }
    return 'sync.all_synced'.tr();
  }

  void _triggerSync(WidgetRef ref) {
    ref.read(syncQueueServiceProvider).processQueue();
  }
}

/// A floating action button variant for sync
class SyncFloatingButton extends ConsumerWidget {
  const SyncFloatingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncService = ref.watch(syncQueueServiceProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    return pendingCountAsync.when(
      data: (pendingCount) {
        final isProcessing = syncService.isProcessing;
        final hasPending = pendingCount > 0;

        // Hide if nothing to sync
        if (!hasPending && !isProcessing) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.small(
          onPressed: isOnline && hasPending && !isProcessing
              ? () => ref.read(syncQueueServiceProvider).processQueue()
              : null,
          backgroundColor: isProcessing
              ? context.colors.syncSyncing
              : context.colors.syncPending,
          child: isProcessing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onPrimary,
                  ),
                )
              : Badge(
                  label: Text(
                    pendingCount > 9 ? '9+' : '$pendingCount',
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontSize: 9,
                    ),
                  ),
                  backgroundColor: context.colors.error,
                  child: Icon(
                    Icons.sync_rounded,
                    color: context.colors.onPrimary,
                  ),
                ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
