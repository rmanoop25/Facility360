import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../domain/enums/user_role.dart';

/// Badge size options for RoleBadge.
enum RoleBadgeSize { small, medium, large }

/// A badge widget for displaying user roles.
///
/// Displays the role with appropriate color coding based on the user role.
/// Super Admin gets a special purple color treatment.
///
/// Example usage:
/// ```dart
/// RoleBadge(role: UserRole.superAdmin)
/// RoleBadge(role: UserRole.manager, size: RoleBadgeSize.small)
/// ```
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    this.size = RoleBadgeSize.medium,
    this.showIcon = true,
  });

  final UserRole role;
  final RoleBadgeSize size;
  final bool showIcon;

  Color _getBackgroundColor(BuildContext context) {
    return switch (role) {
      UserRole.superAdmin => context.colors.primary, // Purple - highest authority
      UserRole.manager => context.colors.statusAssigned,   // Blue
      UserRole.viewer => context.colors.textSecondary,     // Gray
      UserRole.tenant => context.colors.statusInProgress,  // Purple
      UserRole.serviceProvider => context.colors.success,  // Green
    };
  }

  Color _getBgColor(BuildContext context) {
    return switch (role) {
      UserRole.superAdmin => context.colors.primaryLight.withOpacity(0.3), // Light purple
      UserRole.manager => context.colors.statusAssignedBg, // Light blue
      UserRole.viewer => context.colors.surfaceVariant,     // Light gray
      UserRole.tenant => context.colors.statusInProgressBg,
      UserRole.serviceProvider => context.colors.successBg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final padding = switch (size) {
      RoleBadgeSize.small => EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2.0,
      ),
      RoleBadgeSize.medium => EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      RoleBadgeSize.large => EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
    };

    final fontSize = switch (size) {
      RoleBadgeSize.small => 10.0,
      RoleBadgeSize.medium => 12.0,
      RoleBadgeSize.large => 14.0,
    };

    final iconSize = switch (size) {
      RoleBadgeSize.small => 12.0,
      RoleBadgeSize.medium => 14.0,
      RoleBadgeSize.large => 16.0,
    };

    final bgColor = _getBackgroundColor(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _getBgColor(context),
        borderRadius: AppRadius.allFull,
        border: Border.all(
          color: bgColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              role.icon,
              color: bgColor,
              size: iconSize,
            ),
            SizedBox(width: size == RoleBadgeSize.small ? 4 : 6),
          ],
          Text(
            role.label,
            style: TextStyle(
              color: bgColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simpler role indicator chip without icon.
class RoleChip extends StatelessWidget {
  const RoleChip({
    super.key,
    required this.role,
    this.selected = false,
    this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback? onTap;

  Color _getColor(BuildContext context) {
    return switch (role) {
      UserRole.superAdmin => context.colors.primary,
      UserRole.manager => context.colors.statusAssigned,
      UserRole.viewer => context.colors.textSecondary,
      UserRole.tenant => context.colors.statusInProgress,
      UserRole.serviceProvider => context.colors.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);

    return Material(
      color: selected ? color : Colors.transparent,
      borderRadius: AppRadius.allFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allFull,
            border: Border.all(
              color: color,
              width: 1,
            ),
          ),
          child: Text(
            role.label,
            style: TextStyle(
              color: selected ? context.colors.onPrimary : color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
