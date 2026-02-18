import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';
import '../../domain/enums/issue_status.dart';
import '../../domain/enums/assignment_status.dart';
import '../../domain/enums/issue_priority.dart';
import '../../domain/enums/sync_status.dart';

/// Extension methods on BuildContext for easy access to theme tokens
/// Usage: context.colors.primary, context.spacing.lg, etc.
extension ContextExtensions on BuildContext {
  // =============================================================
  // THEME ACCESSORS
  // =============================================================

  /// Access the current theme
  ThemeData get theme => Theme.of(this);

  /// Access the color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Access the text theme
  TextTheme get textTheme => theme.textTheme;

  /// Check if dark mode is enabled
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // =============================================================
  // SHADOW HELPERS (Dark mode aware)
  // =============================================================

  /// Get card shadow - no glossy effect in dark mode
  /// Usage: boxShadow: context.cardShadow
  List<BoxShadow> get cardShadow => isDarkMode ? [] : AppShadows.card;

  /// Get card shadow small - no glossy effect in dark mode
  List<BoxShadow> get cardShadowSm => isDarkMode ? [] : AppShadows.sm;

  /// Get elevated card shadow - subtle in dark mode
  List<BoxShadow> get cardShadowMd => isDarkMode ? [] : AppShadows.md;

  /// Get bottom nav shadow - no glossy effect in dark mode
  List<BoxShadow> get bottomNavShadow => isDarkMode ? [] : AppShadows.bottomNav;

  /// Get top nav shadow - no glossy effect in dark mode
  List<BoxShadow> get topNavShadow => isDarkMode ? [] : AppShadows.topNav;

  // =============================================================
  // CUSTOM THEME EXTENSIONS
  // =============================================================

  /// Access semantic color tokens
  /// Usage: context.colors.primary, context.colors.statusPending
  AppColorsExtension get colors =>
      theme.extension<AppColorsExtension>() ?? AppColorsExtension.light;

  /// Access spacing tokens
  /// Usage: context.spacing.lg, context.spacing.screenPaddingH
  AppSpacingExtension get spacing =>
      theme.extension<AppSpacingExtension>() ?? AppSpacingExtension.standard;

  // =============================================================
  // MEDIA QUERY HELPERS
  // =============================================================

  /// Screen size
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Screen width
  double get screenWidth => screenSize.width;

  /// Screen height
  double get screenHeight => screenSize.height;

  /// Safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.paddingOf(this);

  /// Bottom safe area (for FAB positioning)
  double get bottomSafeArea => safeAreaPadding.bottom;

  /// Top safe area (for app bar)
  double get topSafeArea => safeAreaPadding.top;

  /// Check if keyboard is visible
  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;

  /// Keyboard height
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;

  // =============================================================
  // RESPONSIVE HELPERS
  // =============================================================

  /// Check if screen is mobile sized (< 600)
  bool get isMobile => screenWidth < 600;

  /// Check if screen is tablet sized (600 - 1024)
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// Check if screen is desktop sized (>= 1024)
  bool get isDesktop => screenWidth >= 1024;

  // =============================================================
  // NAVIGATION HELPERS
  // =============================================================

  /// Check if can pop (use GoRouter's context.pop() for actual navigation)
  bool get canPopNav => Navigator.of(this).canPop();

  // =============================================================
  // STATUS COLOR HELPERS
  // =============================================================

  /// Get color for issue status
  Color issueStatusColor(IssueStatus status) {
    return switch (status) {
      IssueStatus.pending => colors.statusPending,
      IssueStatus.assigned => colors.statusAssigned,
      IssueStatus.inProgress => colors.statusInProgress,
      IssueStatus.onHold => colors.statusOnHold,
      IssueStatus.finished => colors.statusFinished,
      IssueStatus.completed => colors.statusCompleted,
      IssueStatus.cancelled => colors.statusCancelled,
    };
  }

  /// Get background color for issue status
  Color issueStatusBgColor(IssueStatus status) {
    return switch (status) {
      IssueStatus.pending => colors.statusPendingBg,
      IssueStatus.assigned => colors.statusAssignedBg,
      IssueStatus.inProgress => colors.statusInProgressBg,
      IssueStatus.onHold => colors.statusOnHoldBg,
      IssueStatus.finished => colors.statusFinishedBg,
      IssueStatus.completed => colors.statusCompletedBg,
      IssueStatus.cancelled => colors.statusCancelledBg,
    };
  }

  /// Get color for assignment status
  Color assignmentStatusColor(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => colors.statusAssigned,
      AssignmentStatus.inProgress => colors.statusInProgress,
      AssignmentStatus.onHold => colors.statusOnHold,
      AssignmentStatus.finished => colors.statusFinished,
      AssignmentStatus.completed => colors.statusCompleted,
    };
  }

  /// Get background color for assignment status
  Color assignmentStatusBgColor(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => colors.statusAssignedBg,
      AssignmentStatus.inProgress => colors.statusInProgressBg,
      AssignmentStatus.onHold => colors.statusOnHoldBg,
      AssignmentStatus.finished => colors.statusFinishedBg,
      AssignmentStatus.completed => colors.statusCompletedBg,
    };
  }

  /// Get color for priority
  Color priorityColor(IssuePriority priority) {
    return switch (priority) {
      IssuePriority.low => colors.priorityLow,
      IssuePriority.medium => colors.priorityMedium,
      IssuePriority.high => colors.priorityHigh,
    };
  }

  /// Get background color for priority
  Color priorityBgColor(IssuePriority priority) {
    return switch (priority) {
      IssuePriority.low => colors.priorityLowBg,
      IssuePriority.medium => colors.priorityMediumBg,
      IssuePriority.high => colors.priorityHighBg,
    };
  }

  /// Get color for sync status
  Color syncStatusColor(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => colors.syncSynced,
      SyncStatus.pending => colors.syncPending,
      SyncStatus.syncing => colors.syncSyncing,
      SyncStatus.failed => colors.syncFailed,
    };
  }

  // =============================================================
  // SNACKBAR HELPERS
  // =============================================================

  /// Show a success snackbar
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colors.success),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.successBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an error snackbar
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: colors.error),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.errorBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an info snackbar
  void showInfoSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_rounded, color: colors.info),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.infoBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a warning snackbar
  void showWarningSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_rounded, color: colors.warning),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors.warningBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =============================================================
  // FOCUS HELPERS
  // =============================================================

  /// Unfocus current focus (dismiss keyboard)
  void unfocus() => FocusScope.of(this).unfocus();
}

/// Extension methods for EdgeInsets directional
extension EdgeInsetsExtensions on double {
  /// All sides padding
  EdgeInsets get all => EdgeInsets.all(this);

  /// Horizontal padding
  EdgeInsets get horizontal => EdgeInsets.symmetric(horizontal: this);

  /// Vertical padding
  EdgeInsets get vertical => EdgeInsets.symmetric(vertical: this);

  /// Top padding only
  EdgeInsets get top => EdgeInsets.only(top: this);

  /// Bottom padding only
  EdgeInsets get bottom => EdgeInsets.only(bottom: this);

  /// Left padding only
  EdgeInsets get left => EdgeInsets.only(left: this);

  /// Right padding only
  EdgeInsets get right => EdgeInsets.only(right: this);

  /// Directional start padding
  EdgeInsetsDirectional get start => EdgeInsetsDirectional.only(start: this);

  /// Directional end padding
  EdgeInsetsDirectional get end => EdgeInsetsDirectional.only(end: this);

  /// SizedBox with this width
  SizedBox get widthBox => SizedBox(width: this);

  /// SizedBox with this height
  SizedBox get heightBox => SizedBox(height: this);
}

/// Extension methods for Duration
extension DurationExtensions on Duration {
  /// Format as HH:MM:SS
  String get formatted {
    final hours = inHours.toString().padLeft(2, '0');
    final minutes = (inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Format as MM:SS (for short durations)
  String get shortFormatted {
    final minutes = inMinutes.toString().padLeft(2, '0');
    final seconds = (inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
