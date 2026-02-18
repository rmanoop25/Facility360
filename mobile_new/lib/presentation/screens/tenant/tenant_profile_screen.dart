import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/theme_provider.dart';

/// Tenant profile screen with settings
class TenantProfileScreen extends ConsumerWidget {
  const TenantProfileScreen({super.key});

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
                    name: user?.name ?? 'Tenant User',
                    email: user?.email ?? 'tenant@example.com',
                    phone: user?.phone ?? '+1 234 567 8900',
                    profilePhotoUrl: user?.profilePhoto,
                  ),

                  AppSpacing.vGapLg,

                  // Unit Info Card
                  _InfoCard(
                    title: 'tenant.my_unit'.tr(),
                    children: [
                      _InfoRow(
                        icon: Icons.home_rounded,
                        label: 'tenant.unit_number'.tr(),
                        value: user?.tenant?.unitNumber ?? 'A-101',
                      ),
                      _InfoRow(
                        icon: Icons.apartment_rounded,
                        label: 'tenant.building'.tr(),
                        value: user?.tenant?.buildingName ?? 'Tower A',
                      ),
                    ],
                  ),

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
                        subtitle: context.locale.languageCode == 'ar'
                            ? 'profile.arabic'.tr()
                            : 'profile.english'.tr(),
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
  final String? profilePhotoUrl;

  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.phone,
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
                AppSpacing.vGapXs,
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: context.colors.textTertiary,
                    ),
                    AppSpacing.gapXs,
                    Text(
                      phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
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
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: context.colors.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Info card widget
class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapMd,
          ...children,
        ],
      ),
    );
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.primary.withOpacity(0.1),
              borderRadius: AppRadius.allMd,
            ),
            child: Icon(
              icon,
              color: context.colors.primary,
              size: 20,
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: trailing == null ? onTap : null,
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
