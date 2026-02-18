import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../domain/enums/sync_status.dart';

/// A compact indicator showing the sync status of an item.
///
/// Shows an icon with appropriate color based on sync state.
/// For [SyncStatus.syncing], the icon animates to indicate progress.
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({
    super.key,
    required this.status,
    this.size = 16,
    this.showLabel = false,
    this.locale = 'en',
  });

  /// The sync status to display
  final SyncStatus status;

  /// Icon size (default: 16)
  final double size;

  /// Whether to show the label next to the icon
  final bool showLabel;

  /// Locale for label (en/ar)
  final String locale;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.status == SyncStatus.syncing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SyncStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == SyncStatus.syncing) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor(BuildContext context) {
    return switch (widget.status) {
      SyncStatus.synced => context.colors.syncSynced,
      SyncStatus.pending => context.colors.syncPending,
      SyncStatus.syncing => context.colors.syncSyncing,
      SyncStatus.failed => context.colors.syncFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final icon = widget.status.icon;

    Widget iconWidget = Icon(
      icon,
      size: widget.size,
      color: color,
    );

    // Animate for syncing status
    if (widget.status == SyncStatus.syncing) {
      iconWidget = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * 3.14159,
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    if (!widget.showLabel) {
      return iconWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        AppSpacing.gapXs,
        Text(
          widget.status.label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// A badge version of sync status for use in cards and list items
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.status,
    this.locale = 'en',
  });

  final SyncStatus status;
  final String locale;

  Color _getColor(BuildContext context) {
    return switch (status) {
      SyncStatus.synced => context.colors.syncSynced,
      SyncStatus.pending => context.colors.syncPending,
      SyncStatus.syncing => context.colors.syncSyncing,
      SyncStatus.failed => context.colors.syncFailed,
    };
  }

  Color _getBackgroundColor(BuildContext context) {
    return switch (status) {
      SyncStatus.synced => context.colors.successBg,
      SyncStatus.pending => context.colors.warningBg,
      SyncStatus.syncing => context.colors.infoBg,
      SyncStatus.failed => context.colors.errorBg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final bgColor = _getBackgroundColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 14,
            color: color,
          ),
          AppSpacing.gapXs,
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
