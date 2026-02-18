import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../../core/theme/app_spacing.dart';

/// A badge that shows the number of pending sync operations.
///
/// Useful in app bars or navigation items to indicate pending uploads.
class PendingSyncBadge extends ConsumerWidget {
  const PendingSyncBadge({
    super.key,
    this.child,
    this.showZero = false,
    this.showIcon = true,
    this.position = BadgePosition.topRight,
  });

  /// Optional child widget to wrap with the badge
  final Widget? child;

  /// Whether to show the badge when count is zero
  final bool showZero;

  /// Whether to show the sync icon in the badge
  final bool showIcon;

  /// Position of the badge relative to child
  final BadgePosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    return pendingCountAsync.when(
      data: (count) {
        if (count == 0 && !showZero) {
          return child ?? const SizedBox.shrink();
        }

        final badge = _buildBadge(context, count);

        if (child == null) {
          return badge;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            Positioned(
              top: position == BadgePosition.topRight ? -4 : null,
              bottom: position == BadgePosition.bottomRight ? -4 : null,
              right: -4,
              child: badge,
            ),
          ],
        );
      },
      loading: () => child ?? const SizedBox.shrink(),
      error: (_, __) => child ?? const SizedBox.shrink(),
    );
  }

  Widget _buildBadge(BuildContext context, int count) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? AppSpacing.sm : AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.syncPending,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: context.colors.syncPending.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(
        minWidth: 18,
        minHeight: 18,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.sync_rounded,
              size: 10,
              color: context.colors.onPrimary,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            count > 99 ? '99+' : '$count',
            style: TextStyle(
              color: context.colors.onPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Position of the badge
enum BadgePosition {
  topRight,
  bottomRight,
}

/// A simple count display for pending sync operations.
///
/// Shows only the count without the badge styling.
class PendingSyncCount extends ConsumerWidget {
  const PendingSyncCount({
    super.key,
    this.style,
    this.prefix = '',
    this.suffix,
  });

  /// Text style for the count
  final TextStyle? style;

  /// Prefix text before the count
  final String prefix;

  /// Suffix text after the count (defaults to localized ' pending')
  final String? suffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    return pendingCountAsync.when(
      data: (count) {
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Text(
          '$prefix$count${suffix ?? ' ${'common.pending'.tr()}'}',
          style: style ??
              TextStyle(
                color: context.colors.syncPending,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
