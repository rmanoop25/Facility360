import 'package:flutter/material.dart';

import 'app_state_placeholder.dart';

/// A convenience wrapper around [AppStatePlaceholder] for generic API/system errors.
///
/// Internally renders [AppStatePlaceholder] with [AppPlaceholderType.error] and the
/// `SomethingWentWrong` illustration. For other error types (permission denied,
/// offline) use [AppStatePlaceholder] directly.
///
/// Example — full-screen (default):
/// ```dart
/// error: (e, _) => Scaffold(
///   appBar: AppBar(...),
///   body: ErrorPlaceholder(onRetry: () => ref.invalidate(...)),
/// )
/// ```
///
/// Example — inline inside TabBarView:
/// ```dart
/// state.error != null
///   ? ErrorPlaceholder(isFullScreen: false, onRetry: () => ...)
///   : TabBarView(...)
/// ```
class ErrorPlaceholder extends StatelessWidget {
  const ErrorPlaceholder({
    super.key,
    this.onRetry,
    this.showRetry = true,
    this.isFullScreen = true,
    this.message,
  });

  /// Callback invoked when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Whether to show the retry button. Defaults to `true`.
  final bool showRetry;

  /// When `true` (default), uses full-screen layout with [SafeArea] + [Center].
  /// Set to `false` when embedded inside [TabBarView], [ListView], or [Card].
  final bool isFullScreen;

  /// Optional subtitle message shown below the title.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AppStatePlaceholder(
      type: AppPlaceholderType.error,
      onRetry: onRetry,
      showRetry: showRetry,
      isFullScreen: isFullScreen,
      message: message,
    );
  }
}
