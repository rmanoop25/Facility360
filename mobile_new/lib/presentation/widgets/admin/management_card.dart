import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';

/// Management card widget for the Management Hub grid
/// Displays an icon, title, count, and optional badge
class ManagementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final Color? color;
  final String? badge;
  final VoidCallback? onTap;

  const ManagementCard({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
    this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? context.colors.primary;

    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLg,
            boxShadow: context.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      borderRadius: AppRadius.allMd,
                    ),
                    child: Icon(icon, color: cardColor, size: 24),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.warning.withOpacity(0.1),
                        borderRadius: AppRadius.badgeRadius,
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: context.colors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.vGapXs,
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact management card for smaller layouts
class ManagementCardCompact extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const ManagementCardCompact({
    super.key,
    required this.title,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? context.colors.primary;

    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLg,
            boxShadow: context.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: AppRadius.allMd,
                ),
                child: Icon(icon, color: cardColor, size: 24),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header for management hub
class ManagementSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const ManagementSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Text('common.view_all'.tr()),
            ),
        ],
      ),
    );
  }
}
