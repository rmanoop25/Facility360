import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// A success dialog shown after a tenant successfully reports an issue.
///
/// Displays a large, visible confirmation with a reassuring message
/// to let users know their issue has been received.
class IssueSuccessDialog extends StatelessWidget {
  const IssueSuccessDialog({
    super.key,
    required this.isOnline,
    required this.onDismiss,
  });

  /// Whether the device is currently online
  final bool isOnline;

  /// Callback when the user dismisses the dialog
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: AppSpacing.allLg,
      child: Container(
        padding: AppSpacing.allXl,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.dialogRadius,
          boxShadow: context.cardShadowMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success animation
            SizedBox(
              width: 120,
              height: 120,
              child: isOnline
                  ? Lottie.asset(
                      'assets/animations/success_checkmark.json',
                      repeat: false,
                      fit: BoxFit.contain,
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: context.colors.successBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_rounded,
                        size: 56,
                        color: context.colors.success,
                      ),
                    ),
            ),

            AppSpacing.vGapXl,

            // Title
            Text(
              isOnline
                  ? 'create_issue.success_title'.tr()
                  : 'create_issue.success_title_offline'.tr(),
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            AppSpacing.vGapMd,

            // Reassuring message
            Text(
              isOnline
                  ? 'create_issue.success_message'.tr()
                  : 'create_issue.success_message_offline'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            AppSpacing.vGapXl,

            // Dismiss button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.success,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                child: Text(
                  'create_issue.success_dismiss'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
