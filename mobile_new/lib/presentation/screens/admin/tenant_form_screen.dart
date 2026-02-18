import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../providers/admin_tenant_provider.dart';

/// Tenant Form Screen
/// Create or edit tenant details
class TenantFormScreen extends ConsumerStatefulWidget {
  final String? tenantId;

  const TenantFormScreen({super.key, this.tenantId});

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _unitController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedBuilding;
  bool _isActive = true;
  bool _isLoadingData = false;
  bool _obscurePassword = true;

  // Profile photo state
  File? _selectedProfilePhoto;
  String? _existingProfilePhotoUrl;

  bool get _isEditing => widget.tenantId != null;
  int? get _tenantId => widget.tenantId != null ? int.tryParse(widget.tenantId!) : null;

  List<String> _buildings = ['Tower A', 'Tower B', 'Tower C', 'Villa Block D'];

  @override
  void initState() {
    super.initState();
    if (_isEditing && _tenantId != null) {
      _loadTenantData();
    }
  }

  Future<void> _loadTenantData() async {
    setState(() => _isLoadingData = true);

    try {
      final tenant = await ref.read(adminTenantDetailProvider(_tenantId!).future);
      if (tenant != null && mounted) {
        setState(() {
          _nameController.text = tenant.userName ?? '';
          _emailController.text = tenant.userEmail ?? '';
          _phoneController.text = tenant.userPhone ?? '';
          _unitController.text = tenant.unitNumber ?? '';
          // Add building to list if not present (fixes "Desert View" crash)
          if (tenant.buildingName != null &&
              tenant.buildingName!.isNotEmpty &&
              !_buildings.contains(tenant.buildingName!)) {
            _buildings.add(tenant.buildingName!);
          }
          _selectedBuilding = tenant.buildingName;
          _existingProfilePhotoUrl = tenant.profilePhotoUrl;
          _isActive = tenant.userIsActive;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('errors.load_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _unitController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final actionNotifier = ref.read(adminTenantActionProvider.notifier);
    bool success;

    if (_isEditing && _tenantId != null) {
      success = await actionNotifier.updateTenant(
        _tenantId!,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        unitNumber: _unitController.text.trim(),
        buildingName: _selectedBuilding,
        password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        isActive: _isActive,
        profilePhoto: _selectedProfilePhoto,
      );
    } else {
      success = await actionNotifier.createTenant(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        unitNumber: _unitController.text.trim(),
        buildingName: _selectedBuilding!,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        profilePhoto: _selectedProfilePhoto,
      );
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'tenant_form.updated'.tr() : 'tenant_form.created'.tr(),
            ),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(adminTenantActionProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'errors.save_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  /// Get the profile image provider
  ImageProvider? _getProfileImage() {
    if (_selectedProfilePhoto != null) {
      return FileImage(_selectedProfilePhoto!);
    }
    if (_existingProfilePhotoUrl != null && _existingProfilePhotoUrl!.isNotEmpty) {
      return NetworkImage(_existingProfilePhotoUrl!);
    }
    return null;
  }

  /// Show image picker options bottom sheet
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: context.colors.primary),
              ),
              title: Text('tenant_form.take_photo'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: context.colors.primary),
              ),
              title: Text('tenant_form.choose_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedProfilePhoto != null || _existingProfilePhotoUrl != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete, color: context.colors.error),
                ),
                title: Text(
                  'tenant_form.remove_photo'.tr(),
                  style: TextStyle(color: context.colors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedProfilePhoto = null;
                    _existingProfilePhotoUrl = null;
                  });
                },
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 70,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedProfilePhoto = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('errors.image_pick_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminTenantActionProvider);
    final isSubmitting = actionState.isLoading;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'tenants_list.edit'.tr() : 'tenants_list.add'.tr()),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: AppSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Section
                    Center(
                      child: GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: context.colors.primary.withOpacity(0.1),
                              backgroundImage: _getProfileImage(),
                              child: _selectedProfilePhoto == null && _existingProfilePhotoUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: context.colors.primary,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: context.colors.primary,
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
                    ),

                    AppSpacing.vGapXxl,

                    // Personal Information Section
                    _SectionHeader(title: 'tenant_form.personal_info'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'tenant_form.full_name'.tr(),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'tenant_form.name_required'.tr();
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vGapLg,
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'tenant_form.email'.tr(),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'tenant_form.email_required'.tr();
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
                              labelText: 'tenant_form.phone'.tr(),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Unit Information Section
                    _SectionHeader(title: 'tenant_form.unit_info'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedBuilding,
                            decoration: InputDecoration(
                              labelText: 'tenant_form.building'.tr(),
                              prefixIcon: const Icon(Icons.apartment),
                            ),
                            items: _buildings.map((building) {
                              return DropdownMenuItem(
                                value: building,
                                child: Text(building),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedBuilding = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'tenant_form.building_required'.tr();
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vGapLg,
                          TextFormField(
                            controller: _unitController,
                            decoration: InputDecoration(
                              labelText: 'tenant_form.unit_number'.tr(),
                              prefixIcon: const Icon(Icons.door_front_door_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'tenant_form.unit_required'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    // Password Section
                    AppSpacing.vGapXl,
                    _SectionHeader(
                      title: _isEditing
                          ? 'tenant_form.change_password'.tr()
                          : 'tenant_form.account_setup'.tr(),
                    ),
                    AppSpacing.vGapMd,
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditing)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'tenant_form.password_optional'.tr(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'tenant_form.password'.tr(),
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
                                return 'tenant_form.password_required'.tr();
                              }
                              if (value != null && value.isNotEmpty && value.length < 6) {
                                return 'tenant_form.password_min_length'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Status Section
                    _SectionHeader(title: 'issue.status'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: SwitchListTile(
                        title: Text('common.active'.tr()),
                        subtitle: Text(
                          _isActive
                              ? 'tenant_form.active_desc'.tr()
                              : 'tenant_form.inactive_desc'.tr(),
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
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(context.colors.onPrimary),
                                ),
                              )
                            : Text(_isEditing ? 'tenant_form.update'.tr() : 'tenant_form.create'.tr()),
                      ),
                    ),

                    AppSpacing.vGapXxl,
                  ],
                ),
              ),
            ),
    );
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
