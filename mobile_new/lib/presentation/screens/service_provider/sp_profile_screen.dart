import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums/assignment_status.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/theme_provider.dart';

/// Service Provider profile screen with settings
class SPProfileScreen extends ConsumerWidget {
  const SPProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeNotifier = ref.watch(themeProvider.notifier);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDarkMode = themeNotifier.isDarkMode(platformBrightness);
    final notificationsEnabled = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar - consistent with other screens
            SliverAppBar(
              floating: true,
              backgroundColor: context.colors.background,
              title: Text(
                'profile.title'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('profile.not_editable'.tr()),
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),

            // Content
            SliverPadding(
              padding: AppSpacing.screen,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile Header Card - Avatar left, info right
                  _ProfileHeaderCard(
                    name: user?.name ?? 'sp.service_provider'.tr(),
                    email: user?.email ?? 'common.na'.tr(),
                    phone: user?.phone ?? 'common.na'.tr(),
                    category: user?.serviceProvider?.categories.firstOrNull?.localizedName(context.locale.languageCode) ?? 'sp.service_provider'.tr(),
                    profilePhotoUrl: user?.profilePhoto,
                  ),

                  AppSpacing.vGapLg,

                  // Stats Card
                  const _StatsCard(),

                  AppSpacing.vGapLg,

                  // Settings Section
                  Text(
                    'profile.settings'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vGapMd,

                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: 'profile.language'.tr(),
                        subtitle: context.locale.languageCode == 'ar' ? 'profile.arabic'.tr() : 'profile.english'.tr(),
                        onTap: () => _showLanguageSheet(context, ref),
                      ),
                      _SettingsTile(
                        icon: notificationsEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        title: 'profile.notifications'.tr(),
                        subtitle: notificationsEnabled
                            ? 'common.enabled'.tr()
                            : 'common.disabled'.tr(),
                        trailing: Switch.adaptive(
                          value: notificationsEnabled,
                          onChanged: (value) {
                            ref.read(notificationSettingsProvider.notifier).setEnabled(value);
                          },
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.schedule_rounded,
                        title: 'profile.working_hours'.tr(),
                        subtitle: 'profile.working_hours_placeholder'.tr(),
                        enabled: false,
                      ),
                      _SettingsTile(
                        icon: isDarkMode ? Icons.dark_mode_rounded : Icons.dark_mode_rounded,
                        title: 'profile.dark_mode'.tr(),
                        subtitle: isDarkMode ? 'common.on'.tr() : 'common.off'.tr(),
                        trailing: Switch.adaptive(
                          value: isDarkMode,
                          onChanged: (value) {
                            ref.read(themeProvider.notifier).toggleTheme(platformBrightness);
                          },
                        ),
                      ),
                    ],
                  ),

                  AppSpacing.vGapLg,

                  // Support Section
                  Text(
                    'profile.support'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vGapMd,

                  _SettingsCard(
                    children: [
                      // Help center option hidden
                      // _SettingsTile(
                      //   icon: Icons.help_outline,
                      //   title: 'profile.help_center'.tr(),
                      //   onTap: () {},
                      // ),
                      _SettingsTile(
                        icon: Icons.policy_rounded,
                        title: 'profile.privacy_policy'.tr(),
                        onTap: () => context.push(RoutePaths.privacyPolicy),
                      ),
                      _SettingsTile(
                        icon: Icons.description_rounded,
                        title: 'profile.terms'.tr(),
                        onTap: () => context.push(RoutePaths.termsOfService),
                      ),
                    ],
                  ),

                  AppSpacing.vGapLg,

                  // App Info
                  Center(
                    child: Text(
                      '${'app.name'.tr()} v1.0.0',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),

                  AppSpacing.vGapXl,

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context, ref),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text('auth.log_out'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.error),
                      ),
                    ),
                  ),

                  AppSpacing.vGapXxl,
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final isArabic = context.locale.languageCode == 'ar';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: sheetContext.colors.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.colors.border,
                  borderRadius: AppRadius.allFull,
                ),
              ),
              AppSpacing.vGapLg,
              Text(
                'profile.select_language'.tr(),
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.vGapLg,
              _LanguageOption(
                flag: '🇺🇸',
                name: 'profile.english'.tr(),
                isSelected: !isArabic,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (isArabic) {
                    ref.read(localeProvider.notifier).setLocale(const Locale('en'), context);
                  }
                },
              ),
              AppSpacing.vGapSm,
              _LanguageOption(
                flag: '🇸🇦',
                name: 'profile.arabic'.tr(),
                isSelected: isArabic,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!isArabic) {
                    ref.read(localeProvider.notifier).setLocale(const Locale('ar'), context);
                  }
                },
              ),
              AppSpacing.vGapLg,
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LogoutDialog(
        onLogout: () async {
          await ref.read(authStateProvider.notifier).logout();
          if (context.mounted) {
            context.go(RoutePaths.login);
          }
        },
      ),
    );
  }
}

/// Logout dialog with loading state
class _LogoutDialog extends StatefulWidget {
  final Future<void> Function() onLogout;

  const _LogoutDialog({required this.onLogout});

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('auth.log_out'.tr()),
      content: _isLoggingOut
          ? Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('auth.logging_out'.tr()),
              ],
            )
          : Text('auth.logout_confirm'.tr()),
      actions: _isLoggingOut
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: _handleLogout,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
                child: Text('auth.log_out'.tr()),
              ),
            ],
    );
  }
}

/// Profile header card with avatar on left and info on right
class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String category;
  final String? profilePhotoUrl;

  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.category,
    this.profilePhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar on left
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: profilePhotoUrl == null || profilePhotoUrl!.isEmpty
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.primary,
                        context.colors.primaryDark,
                      ],
                    )
                  : null,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      profilePhotoUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildInitial(context),
                    ),
                  )
                : _buildInitial(context),
          ),
          AppSpacing.gapLg,
          // Info on right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.vGapXs,
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.badgeRadius,
                  ),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppSpacing.vGapXs,
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: context.colors.textTertiary,
                    ),
                    AppSpacing.gapXs,
                    Expanded(
                      child: Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chevron hidden - no details page yet
          // Icon(
          //   Icons.chevron_right,
          //   color: context.colors.textTertiary,
          // ),
        ],
      ),
    );
  }

  Widget _buildInitial(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.primary,
            context.colors.primaryDark,
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: context.colors.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Stats card widget
class _StatsCard extends ConsumerWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentState = ref.watch(assignmentListProvider);
    final assignments = assignmentState.assignments;

    // Calculate completed assignments
    final completedAssignments = assignments
        .where((a) => a.status == AssignmentStatus.completed)
        .toList();
    final completedCount = completedAssignments.length;

    // Calculate assignments completed this month
    final now = DateTime.now();
    final thisMonthCount = completedAssignments
        .where((a) =>
            a.completedAt != null &&
            a.completedAt!.year == now.year &&
            a.completedAt!.month == now.month)
        .length;

    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          _StatItem(label: 'sp.completed'.tr(), value: completedCount.toString(), icon: Icons.check_circle_outline),
          _VerticalDivider(),
          // Rating stat hidden - not implemented yet
          // _StatItem(label: 'sp.rating'.tr(), value: '4.8', icon: Icons.star_outline),
          // _VerticalDivider(),
          _StatItem(label: 'sp.this_month'.tr(), value: thisMonthCount.toString(), icon: Icons.calendar_today_outlined),
        ],
      ),
    );
  }
}

/// Stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: context.colors.primary, size: 20),
          AppSpacing.vGapXs,
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.primary,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical divider widget
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      color: context.colors.border,
    );
  }
}

/// Settings card widget
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

/// Settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled && trailing == null ? onTap : null,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: AppSpacing.allLg,
          child: Row(
            children: [
              Icon(icon, color: context.colors.textSecondary, size: 22),
              AppSpacing.gapLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: context.colors.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Language option widget
class _LanguageOption extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            AppSpacing.gapMd,
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? context.colors.primary : context.colors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.colors.primary),
          ],
        ),
      ),
    );
  }
}
