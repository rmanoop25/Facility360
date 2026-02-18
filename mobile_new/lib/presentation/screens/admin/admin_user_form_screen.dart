import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../domain/enums/user_role.dart';
import '../../widgets/admin/role_badge.dart';

/// Admin User Form Screen
/// Create or edit admin users (Super Admin only)
class AdminUserFormScreen extends ConsumerStatefulWidget {
  final String? userId;

  const AdminUserFormScreen({super.key, this.userId});

  @override
  ConsumerState<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends ConsumerState<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.viewer;
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  bool get _isEditing => widget.userId != null;

  final _adminRoles = [UserRole.superAdmin, UserRole.manager, UserRole.viewer];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // Load existing user data (mock)
      _nameController.text = 'Manager';
      _emailController.text = 'manager@facility.com';
      _phoneController.text = '+971502222222';
      _selectedRole = UserRole.manager;
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'admin_form.updated'.tr()
                : 'admin_form.created'.tr(),
          ),
          backgroundColor: context.colors.success,
        ),
      );

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'admin_form.edit'.tr() : 'admin_form.add'.tr()),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: _getRoleColor(context, _selectedRole).withOpacity(0.1),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 50,
                        color: _getRoleColor(context, _selectedRole),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(context, _selectedRole),
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.onPrimary, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: context.colors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.vGapXxl,

              // Personal Information Section
              _SectionHeader(title: 'admin_form.personal_info'.tr()),
              AppSpacing.vGapMd,

              _FormCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'admin_form.full_name'.tr(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'admin_form.name_required'.tr();
                        }
                        return null;
                      },
                    ),
                    AppSpacing.vGapLg,
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'admin_form.email'.tr(),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'admin_form.email_required'.tr();
                        }
                        if (!value.contains('@')) {
                          return 'validation.invalid_email'.tr();
                        }
                        return null;
                      },
                    ),
                    AppSpacing.vGapLg,
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'admin_form.phone_optional'.tr(),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.vGapXl,

              // Role Section
              _SectionHeader(title: 'admin_form.role_permissions'.tr()),
              AppSpacing.vGapMd,

              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin_form.select_role'.tr(),
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    AppSpacing.vGapMd,
                    ..._adminRoles.map((role) {
                      final isSelected = _selectedRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Material(
                          color: isSelected
                              ? _getRoleColor(context, role).withOpacity(0.05)
                              : Colors.transparent,
                          borderRadius: AppRadius.allMd,
                          child: InkWell(
                            onTap: () => setState(() => _selectedRole = role),
                            borderRadius: AppRadius.allMd,
                            child: Container(
                              padding: AppSpacing.allMd,
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.allMd,
                                border: Border.all(
                                  color: isSelected
                                      ? _getRoleColor(context, role)
                                      : context.colors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<UserRole>(
                                    value: role,
                                    groupValue: _selectedRole,
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedRole = value);
                                      }
                                    },
                                    activeColor: _getRoleColor(context, role),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              role.label,
                                              style: context.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            AppSpacing.gapSm,
                                            RoleBadge(
                                              role: role,
                                              size: RoleBadgeSize.small,
                                              showIcon: false,
                                            ),
                                          ],
                                        ),
                                        AppSpacing.vGapXs,
                                        Text(
                                          _getRoleDescription(role),
                                          style: context.textTheme.bodySmall?.copyWith(
                                            color: context.colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Password Section (only for new users)
              if (!_isEditing) ...[
                AppSpacing.vGapXl,
                _SectionHeader(title: 'admin_form.account_setup'.tr()),
                AppSpacing.vGapMd,
                _FormCard(
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'admin_form.password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (!_isEditing && (value == null || value.isEmpty)) {
                        return 'admin_form.password_required'.tr();
                      }
                      if (value != null && value.isNotEmpty && value.length < 6) {
                        return 'admin_form.password_min_length'.tr();
                      }
                      return null;
                    },
                  ),
                ),
              ],

              AppSpacing.vGapXl,

              // Status Section
              _SectionHeader(title: 'common.status'.tr()),
              AppSpacing.vGapMd,

              _FormCard(
                child: SwitchListTile(
                  title: Text('common.active'.tr()),
                  subtitle: Text(
                    _isActive
                        ? 'admin_form.active_desc'.tr()
                        : 'admin_form.inactive_desc'.tr(),
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              AppSpacing.vGapXxl,

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(context.colors.onPrimary),
                          ),
                        )
                      : Text(_isEditing ? 'admin_form.update'.tr() : 'admin_form.create'.tr()),
                ),
              ),

              AppSpacing.vGapXxl,
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(BuildContext context, UserRole role) {
    return switch (role) {
      UserRole.superAdmin => const Color(0xFF7C3AED),
      UserRole.manager => context.colors.statusAssigned,
      UserRole.viewer => context.colors.textSecondary,
      _ => context.colors.primary,
    };
  }

  String _getRoleDescription(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => 'admin_form.super_admin_desc'.tr(),
      UserRole.manager => 'admin_form.manager_desc'.tr(),
      UserRole.viewer => 'admin_form.viewer_desc'.tr(),
      _ => '',
    };
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    );
  }
}

/// Form card wrapper
class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: child,
    );
  }
}
