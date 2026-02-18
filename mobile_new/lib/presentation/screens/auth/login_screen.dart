import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../providers/auth_provider.dart';

/// Login screen with demo role selection
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _loadingButton; // 'tenant', 'sp', or 'signin'

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate input
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.email_password_required'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    // Clear any previous error
    ref.read(authStateProvider.notifier).clearError();

    setState(() => _loadingButton = 'signin');
    final success = await ref
        .read(authStateProvider.notifier)
        .login(email, password);

    if (mounted) {
      setState(() => _loadingButton = null);
      if (success) {
        final user = ref.read(authStateProvider).user;
        if (user != null) {
          context.go(user.role.homeRoute);
        }
      }
    }
  }

  Future<void> _loginAsTenant() async {
    ref.read(authStateProvider.notifier).clearError();
    setState(() => _loadingButton = 'tenant');
    final success = await ref.read(authStateProvider.notifier).loginAsTenant();
    if (mounted) {
      setState(() => _loadingButton = null);
      if (success) {
        final user = ref.read(authStateProvider).user;
        if (user != null) {
          context.go(user.role.homeRoute);
        }
      }
    }
  }

  Future<void> _loginAsServiceProvider() async {
    ref.read(authStateProvider.notifier).clearError();
    setState(() => _loadingButton = 'sp');
    final success = await ref
        .read(authStateProvider.notifier)
        .loginAsServiceProvider();
    if (mounted) {
      setState(() => _loadingButton = null);
      if (success) {
        final user = ref.read(authStateProvider).user;
        if (user != null) {
          context.go(user.role.homeRoute);
        }
      }
    }
  }

  Future<void> _loginAsSuperAdmin() async {
    ref.read(authStateProvider.notifier).clearError();
    setState(() => _loadingButton = 'superadmin');
    final success = await ref
        .read(authStateProvider.notifier)
        .loginAsSuperAdmin();
    if (mounted) {
      setState(() => _loadingButton = null);
      if (success) {
        final user = ref.read(authStateProvider).user;
        if (user != null) {
          context.go(user.role.homeRoute);
        }
      }
    }
  }

  Future<void> _loginAsManager() async {
    ref.read(authStateProvider.notifier).clearError();
    setState(() => _loadingButton = 'manager');
    final success = await ref.read(authStateProvider.notifier).loginAsManager();
    if (mounted) {
      setState(() => _loadingButton = null);
      if (success) {
        final user = ref.read(authStateProvider).user;
        if (user != null) {
          context.go(user.role.homeRoute);
        }
      }
    }
  }

  Future<void> _loginAsViewer() async {
    ref.read(authStateProvider.notifier).clearError();
    setState(() => _loadingButton = 'viewer');
    final success = await ref.read(authStateProvider.notifier).loginAsViewer();
    if (mounted) {
      setState(() => _loadingButton = null);
      if (success) {
        final user = ref.read(authStateProvider).user;
        if (user != null) {
          context.go(user.role.homeRoute);
        }
      }
    }
  }

  void _showDemoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('auth.quick_demo'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tenant demo button
              _DialogDemoButton(
                title: 'auth.login_tenant'.tr(),
                subtitle: 'auth.tenant_desc'.tr(),
                icon: Icons.home_rounded,
                color: context.colors.statusAssigned,
                isLoading: _loadingButton == 'tenant',
                onTap: _loadingButton == null ? _loginAsTenant : null,
              ),

              AppSpacing.vGapMd,

              // Service Provider demo button
              _DialogDemoButton(
                title: 'auth.login_sp'.tr(),
                subtitle: 'auth.sp_desc'.tr(),
                icon: Icons.engineering_rounded,
                color: context.colors.primary,
                isLoading: _loadingButton == 'sp',
                onTap: _loadingButton == null ? _loginAsServiceProvider : null,
              ),

              AppSpacing.vGapLg,

              // Admin section header
              Text(
                'auth.admin_access'.tr(),
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              AppSpacing.vGapMd,

              // Super Admin demo button
              _DialogDemoButton(
                title: 'auth.login_super_admin'.tr(),
                subtitle: 'auth.super_admin_desc'.tr(),
                icon: Icons.admin_panel_settings_rounded,
                color: context.colors.primary,
                isLoading: _loadingButton == 'superadmin',
                onTap: _loadingButton == null ? _loginAsSuperAdmin : null,
              ),

              AppSpacing.vGapMd,

              // Manager demo button
              _DialogDemoButton(
                title: 'auth.login_manager'.tr(),
                subtitle: 'auth.manager_desc'.tr(),
                icon: Icons.manage_accounts_rounded,
                color: context.colors.statusAssigned,
                isLoading: _loadingButton == 'manager',
                onTap: _loadingButton == null ? _loginAsManager : null,
              ),

              AppSpacing.vGapMd,

              // Viewer demo button
              _DialogDemoButton(
                title: 'auth.login_viewer'.tr(),
                subtitle: 'auth.viewer_desc'.tr(),
                icon: Icons.visibility_rounded,
                color: context.colors.textSecondary,
                isLoading: _loadingButton == 'viewer',
                onTap: _loadingButton == null ? _loginAsViewer : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lottie animation and title
              Center(
                child: Column(
                  children: [
                    Lottie.asset(
                      'assets/animations/maintain.json',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      repeat: false,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Column(
                        children: [
                          Text(
                            'auth.welcome_back'.tr(),
                            style: context.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          AppSpacing.vGapSm,
                          Text(
                            'auth.sign_in_continue'.tr(),
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.vGapXxxl,

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'auth.email'.tr(),
                  hintText: 'auth.email_hint'.tr(),
                  prefixIcon: const Icon(Icons.email_rounded),
                ),
              ),

              AppSpacing.vGapLg,

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'auth.password'.tr(),
                  hintText: 'auth.password_hint'.tr(),
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),

              AppSpacing.vGapXl,

              // Error message
              if (authState.error != null) ...[
                Container(
                  padding: AppSpacing.allMd,
                  decoration: BoxDecoration(
                    color: context.colors.errorBg,
                    borderRadius: AppRadius.allMd,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_rounded, color: context.colors.error),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Text(
                          // Translate the error message if it's a translation key, otherwise display as-is
                          authState.error!.startsWith('auth.')
                              ? authState.error!.tr()
                              : authState.error!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vGapLg,
              ],

              // Login button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loadingButton == null ? _handleLogin : null,
                  child: _loadingButton == 'signin'
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colors.onPrimary,
                            ),
                          ),
                        )
                      : Text('auth.sign_in'.tr()),
                ),
              ),

              AppSpacing.vGapXl,

              // Demo button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loadingButton == null ? _showDemoDialog : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary.withOpacity(0.1),
                    foregroundColor: context.colors.primary,
                    side: BorderSide(color: context.colors.primary),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text('auth.demo_button'.tr()),
                ),
              ),

              AppSpacing.vGapXl,

              // Demo credentials hint - Hidden temporarily
              // if (false) ...[
              //   Container(
              //     padding: AppSpacing.allMd,
              //     decoration: BoxDecoration(
              //       color: context.colors.infoBg,
              //       borderRadius: AppRadius.allMd,
              //     ),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Row(
              //           children: [
              //             Icon(
              //               Icons.info_outline,
              //               color: context.colors.info,
              //               size: 20,
              //             ),
              //             AppSpacing.gapSm,
              //             Text(
              //               'auth.demo_credentials'.tr(),
              //               style: context.textTheme.labelLarge?.copyWith(
              //                 color: context.colors.info,
              //               ),
              //             ),
              //           ],
              //         ),
              //         AppSpacing.vGapSm,
              //         Text(
              //           'auth.demo_info'.tr(),
              //           style: context.textTheme.bodySmall?.copyWith(
              //             color: context.colors.textSecondary,
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog demo login card widget
class _DialogDemoButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _DialogDemoButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppRadius.allMd,
                ),
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      )
                    : Icon(icon, color: color, size: 20),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
