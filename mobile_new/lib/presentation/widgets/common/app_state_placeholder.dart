import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';

/// The type of state to display in [AppStatePlaceholder].
enum AppPlaceholderType {
  /// Generic API failure, server error, or unexpected exception.
  error,

  /// Permission denied or unauthorized access.
  permission,

  /// No internet connection.
  offline,

  /// No data available (shows an icon instead of the error image).
  empty,
}

/// A unified full/inline state placeholder widget.
///
/// Use this for system-level errors (API failures, permission issues, network
/// offline, unknown exceptions). Do NOT use it for form validation errors.
///
/// Set [isFullScreen] to `true` (default) when the widget occupies an entire
/// page. Set it to `false` when embedded inside a [TabBarView], [ListView],
/// or similar scrollable parent to avoid layout conflicts.
class AppStatePlaceholder extends StatelessWidget {
  const AppStatePlaceholder({
    super.key,
    this.type = AppPlaceholderType.error,
    this.title,
    this.message,
    this.onRetry,
    this.showRetry = true,
    this.isFullScreen = true,
  });

  /// The kind of state to display. Determines the default title and visual.
  final AppPlaceholderType type;

  /// Override the default title text.
  final String? title;

  /// Optional subtitle shown below the title.
  final String? message;

  /// Callback invoked when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Whether to show the retry button. Defaults to `true`.
  /// The button is only rendered when both [showRetry] is `true` and
  /// [onRetry] is non-null.
  final bool showRetry;

  /// When `true` (default), wraps the content in [SafeArea] + [SingleChildScrollView]
  /// + [Center], making it suitable for full-page error screens.
  ///
  /// When `false`, returns just a padded [Column] so it can be embedded inside
  /// a [TabBarView], [ListView], or [Card] without forcing unwanted constraints.
  final bool isFullScreen;

  String _defaultTitle() {
    return switch (type) {
      AppPlaceholderType.error => 'errors.generic'.tr(),
      AppPlaceholderType.permission => 'common.permission_denied'.tr(),
      AppPlaceholderType.offline => 'errors.no_connection'.tr(),
      AppPlaceholderType.empty => 'common.no_data'.tr(),
    };
  }

  Widget _buildContent(BuildContext context) {
    final isEmptyType = type == AppPlaceholderType.empty;

    return Padding(
      padding: AppSpacing.allXl,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isEmptyType) ...[
            Icon(
              Icons.inbox_rounded,
              size: 72,
              color: context.colors.textSecondary.withAlpha(100),
            ),
          ] else if (type == AppPlaceholderType.offline) ...[
            Lottie.asset(
              'assets/animations/internet_error.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
          ] else ...[
            Image.asset(
              'assets/images/something_went_wrong.png',
              width: 260,
              fit: BoxFit.contain,
            ),
          ],
          AppSpacing.vGapLg,
          Text(
            title ?? _defaultTitle(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            AppSpacing.vGapSm,
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (showRetry && onRetry != null) ...[
            AppSpacing.vGapXl,
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('common.retry'.tr()),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isFullScreen) {
      return SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Center(child: _buildContent(context)),
          ),
        ),
      );
    }

    return Center(child: _buildContent(context));
  }
}
