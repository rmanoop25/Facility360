import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

enum ExtensionStatus {
  pending,
  approved,
  rejected;

  String get value {
    switch (this) {
      case ExtensionStatus.pending:
        return 'pending';
      case ExtensionStatus.approved:
        return 'approved';
      case ExtensionStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case ExtensionStatus.pending:
        return 'extensions.status.pending'.tr();
      case ExtensionStatus.approved:
        return 'extensions.status.approved'.tr();
      case ExtensionStatus.rejected:
        return 'extensions.status.rejected'.tr();
    }
  }

  Color get color {
    switch (this) {
      case ExtensionStatus.pending:
        return const Color(0xFFFFA726); // AppColors.warning
      case ExtensionStatus.approved:
        return const Color(0xFF66BB6A); // AppColors.success
      case ExtensionStatus.rejected:
        return const Color(0xFFEF5350); // AppColors.error
    }
  }

  IconData get icon {
    switch (this) {
      case ExtensionStatus.pending:
        return Icons.pending_outlined;
      case ExtensionStatus.approved:
        return Icons.check_circle_outline_rounded;
      case ExtensionStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  static ExtensionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return ExtensionStatus.approved;
      case 'rejected':
        return ExtensionStatus.rejected;
      default:
        return ExtensionStatus.pending;
    }
  }
}
