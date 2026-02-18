import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';
import '../common/error_placeholder.dart';

/// A reusable error state widget for admin screens.
///
/// @deprecated Use [ErrorPlaceholder] instead.
@Deprecated('Use ErrorPlaceholder instead')
class AdminErrorState extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;
  final IconData icon;
  final String? title;
  final String? message;

  const AdminErrorState({
    super.key,
    this.error,
    this.onRetry,
    this.icon = Icons.error_rounded,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorPlaceholder(
      onRetry: onRetry,
      showRetry: onRetry != null,
      isFullScreen: false,
      message: message ?? error,
    );
  }
}

/// A smaller inline error widget for use in lists or cards
class AdminInlineError extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;

  const AdminInlineError({
    super.key,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: context.colors.error,
            size: 20,
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              error ?? 'errors.try_again'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('common.retry'.tr()),
            ),
        ],
      ),
    );
  }
}

/// An offline indicator widget
class AdminOfflineIndicator extends StatelessWidget {
  const AdminOfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: context.colors.warningBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: context.colors.warning,
          ),
          AppSpacing.gapSm,
          Text(
            'connectivity.offline_short'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading more indicator for pagination
class AdminLoadingMoreIndicator extends StatelessWidget {
  const AdminLoadingMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.allMd,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
          ),
        ),
      ),
    );
  }
}
