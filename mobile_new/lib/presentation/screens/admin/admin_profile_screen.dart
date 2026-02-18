import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/admin/role_badge.dart';

/// Admin Profile Screen
/// User profile, settings, and logout - matches tenant/SP profile style
class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeNotifier = ref.watch(themeProvider.notifier);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDarkMode = themeNotifier.isDarkMode(platformBrightness);
    final notificationsEnabled = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          // Floating App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: context.colors.background,
            title: Text(
              'profile.title'.tr(),
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Card
                  _ProfileHeaderCard(
                    name: user?.name ?? 'common.admin_user'.tr(),
                    email: user?.email ?? 'common.na'.tr(),
                    phone: user?.phone ?? 'common.not_set'.tr(),
                    role: user?.role ?? UserRole.viewer,
                    profilePhotoUrl: user?.profilePhoto,
                  ),

                  AppSpacing.vGapXl,

                  // Role Info Section
                  Text(
                    'profile.role_info'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  AppSpacing.vGapMd,

                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'profile.role'.tr(),
                        value: user?.role.label ?? 'Admin',
                      ),
                      _InfoRow(
                        icon: Icons.security_rounded,
                        label: 'profile.access_level'.tr(),
                        value: _getAccessLevel(user?.role ?? UserRole.viewer),
                      ),
                      _InfoRow(
                        icon: Icons.checklist_rounded,
                        label: 'profile.permissions'.tr(),
                        value: _getPermissionsSummary(user?.role ?? UserRole.viewer),
                        isLast: true,
                      ),
                    ],
                  ),

                  AppSpacing.vGapXl,

                  // Settings Section
                  Text(
                    'profile.settings'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
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
                        isLast: true,
                      ),
                    ],
                  ),

                  AppSpacing.vGapXl,

                  // Support Section
                  Text(
                    'profile.support'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  AppSpacing.vGapMd,

                  _SettingsCard(
                    children: [
                      // Help center option hidden
                      // _SettingsTile(
                      //   icon: Icons.help_outline,
                      //   title: 'profile.help_center'.tr(),
                      //   onTap: () {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       SnackBar(content: Text('profile.help_soon'.tr())),
                      //     );
                      //   },
                      // ),
                      _SettingsTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'profile.privacy_policy'.tr(),
                        onTap: () => context.push(RoutePaths.privacyPolicy),
                      ),
                      _SettingsTile(
                        icon: Icons.description_rounded,
                        title: 'profile.terms'.tr(),
                        onTap: () => context.push(RoutePaths.termsOfService),
                        isLast: true,
                      ),
                    ],
                  ),

                  AppSpacing.vGapXl,

                  // App Version
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'app.name'.tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                        Text(
                          'app.version'.tr(),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context, ref),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text('auth.logout'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.error),
                      ),
                    ),
                  ),

                  AppSpacing.vGapXxl,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAccessLevel(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => 'profile.full_access'.tr(),
      UserRole.manager => 'profile.standard_access'.tr(),
      UserRole.viewer => 'profile.read_only'.tr(),
      _ => 'N/A',
    };
  }

  String _getPermissionsSummary(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => 'profile.all_permissions'.tr(),
      UserRole.manager => 'profile.manage_permissions'.tr(),
      UserRole.viewer => 'profile.view_only'.tr(),
      _ => 'N/A',
    };
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final isArabic = context.locale.languageCode == 'ar';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.vGapLg,
              Text(
                'profile.select_language'.tr(),
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.vGapLg,
              _LanguageOption(
                flag: '🇺🇸',
                language: 'profile.english'.tr(),
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
                language: 'profile.arabic'.tr(),
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
      title: Text('auth.logout'.tr()),
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
                child: Text('auth.logout'.tr()),
              ),
            ],
    );
  }
}

/// Profile Header Card - Avatar on left, info on right
class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? profilePhotoUrl;

  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profilePhotoUrl,
  });

  Color _getRoleColor(BuildContext context) => switch (role) {
    UserRole.superAdmin => const Color(0xFF7C3AED),
    UserRole.manager => context.colors.statusAssigned,
    UserRole.viewer => context.colors.textSecondary,
    _ => context.colors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(context);
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar with gradient ring
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  roleColor,
                  roleColor.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: context.colors.card,
              backgroundImage: profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                  ? NetworkImage(profilePhotoUrl!)
                  : null,
              child: profilePhotoUrl == null || profilePhotoUrl!.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    )
                  : null,
            ),
          ),
          AppSpacing.gapLg,
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RoleBadge(role: role),
                  ],
                ),
                AppSpacing.vGapXs,
                Row(
                  children: [
                    Icon(
                      Icons.email_rounded,
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
                      Icons.phone_rounded,
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
        ],
      ),
    );
  }
}

/// Info Card with multiple rows
class _InfoCard extends StatelessWidget {
  final List<_InfoRow> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.allSm,
                ),
                child: Icon(icon, size: 18, color: context.colors.primary),
              ),
              AppSpacing.gapMd,
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

/// Settings Card with tiles
class _SettingsCard extends StatelessWidget {
  final List<_SettingsTile> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(children: children),
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
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(12))
                : null,
            child: Padding(
              padding: AppSpacing.allMd,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withOpacity(0.1),
                      borderRadius: AppRadius.allSm,
                    ),
                    child: Icon(icon, size: 20, color: context.colors.primary),
                  ),
                  AppSpacing.gapMd,
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
                              color: context.colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing ?? Icon(Icons.chevron_right, color: context.colors.textTertiary),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 60),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}

/// Language option widget for bottom sheet
class _LanguageOption extends StatelessWidget {
  final String flag;
  final String language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? context.colors.primary.withOpacity(0.1) : Colors.transparent,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: AppSpacing.allMd,
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              AppSpacing.gapMd,
              Expanded(
                child: Text(
                  language,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: context.colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
