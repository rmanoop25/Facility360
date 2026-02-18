import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../providers/admin_service_provider_provider.dart';
import '../../providers/category_provider.dart';

/// Service Provider Form Screen
/// Create or edit service provider details
class SPFormScreen extends ConsumerStatefulWidget {
  final String? spId;

  const SPFormScreen({super.key, this.spId});

  @override
  ConsumerState<SPFormScreen> createState() => _SPFormScreenState();
}

class _SPFormScreenState extends ConsumerState<SPFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imagePicker = ImagePicker();

  List<int> _selectedCategoryIds = [];
  bool _isAvailable = true;
  bool _isActive = true;
  bool _isLoadingData = false;
  bool _obscurePassword = true;
  
  // Profile photo state
  File? _selectedProfilePhoto;
  String? _existingProfilePhotoUrl;

  bool get _isEditing => widget.spId != null;
  int? get _spId => widget.spId != null ? int.tryParse(widget.spId!) : null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && _spId != null) {
      _loadSPData();
    }
  }

  Future<void> _loadSPData() async {
    setState(() => _isLoadingData = true);

    try {
      final sp = await ref.read(adminServiceProviderDetailProvider(_spId!).future);
      if (sp != null && mounted) {
        setState(() {
          _nameController.text = sp.userName ?? '';
          _emailController.text = sp.userEmail ?? '';
          _phoneController.text = sp.userPhone ?? '';
          _selectedCategoryIds = sp.categories.map((c) => c.id).toList();
          _isAvailable = sp.isAvailable;
          _isActive = true; // Default to active, user status is managed separately
          _existingProfilePhotoUrl = sp.userProfilePhotoUrl;
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sp_form.category_required'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    final actionNotifier = ref.read(adminServiceProviderActionProvider.notifier);
    bool success;

    if (_isEditing && _spId != null) {
      success = await actionNotifier.updateServiceProvider(
        _spId!,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        categoryIds: _selectedCategoryIds,
        password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        isAvailable: _isAvailable,
        isActive: _isActive,
        profilePhoto: _selectedProfilePhoto,
      );
    } else {
      success = await actionNotifier.createServiceProvider(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        categoryIds: _selectedCategoryIds,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        isAvailable: _isAvailable,
        profilePhoto: _selectedProfilePhoto,
      );
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'sp_form.updated'.tr() : 'sp_form.created'.tr(),
            ),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(adminServiceProviderActionProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'errors.save_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  void _showCategorySelector() {
    final categoriesState = ref.read(categoriesStateProvider);
    final categories = categoriesState.activeCategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Title
                    Padding(
                      padding: AppSpacing.horizontalLg,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'sp_form.select_categories'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('common.done'.tr()),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Category list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategoryIds.contains(category.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (selected) {
                              setModalState(() {
                                if (selected == true) {
                                  _selectedCategoryIds.add(category.id);
                                } else {
                                  _selectedCategoryIds.remove(category.id);
                                }
                              });
                              setState(() {}); // Update parent state
                            },
                            title: Text(category.localizedName(context.locale.languageCode)),
                            subtitle: Text(category.nameAr),
                            secondary: Icon(
                              _getCategoryIcon(category.icon ?? 'general'),
                              color: context.colors.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.allLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: this.context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'sp_form.select_photo'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vGapLg,
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: this.context.colors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: this.context.colors.primary,
                    ),
                  ),
                  title: Text('sp_form.take_photo'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: this.context.colors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: this.context.colors.primary,
                    ),
                  ),
                  title: Text('sp_form.choose_from_gallery'.tr()),
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
                        color: this.context.colors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_rounded,
                        color: this.context.colors.error,
                      ),
                    ),
                    title: Text(
                      'sp_form.remove_photo'.tr(),
                      style: TextStyle(color: this.context.colors.error),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedProfilePhoto = null;
                        _existingProfilePhotoUrl = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
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
            content: Text('sp_form.photo_error'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminServiceProviderActionProvider);
    final isSubmitting = actionState.isLoading;
    final categoriesState = ref.watch(categoriesStateProvider);
    final categories = categoriesState.activeCategories;

    // Get selected category names for display
    final selectedCategoryNames = categories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .map((c) => c.localizedName(context.locale.languageCode))
        .toList();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'sp_list.edit'.tr() : 'sp_list.add'.tr()),
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
                                      Icons.engineering,
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
                                  Icons.camera_alt_rounded,
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
                    _SectionHeader(title: 'sp_form.personal_info'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'sp_form.full_name'.tr(),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'sp_form.name_required'.tr();
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vGapLg,
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'sp_form.email'.tr(),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'sp_form.email_required'.tr();
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
                              labelText: 'sp_form.phone'.tr(),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Category Section (Multi-select)
                    _SectionHeader(title: 'sp_form.categories'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categoriesState.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else ...[
                            InkWell(
                              onTap: _showCategorySelector,
                              borderRadius: AppRadius.cardRadius,
                              child: Container(
                                width: double.infinity,
                                padding: AppSpacing.allMd,
                                decoration: BoxDecoration(
                                  border: Border.all(color: context.colors.border),
                                  borderRadius: AppRadius.cardRadius,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      color: context.colors.textSecondary,
                                    ),
                                    AppSpacing.gapMd,
                                    Expanded(
                                      child: _selectedCategoryIds.isEmpty
                                          ? Text(
                                              'sp_form.select_categories'.tr(),
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: context.colors.textSecondary,
                                              ),
                                            )
                                          : Text(
                                              selectedCategoryNames.join(', '),
                                              style: Theme.of(context).textTheme.bodyMedium,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: context.colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_selectedCategoryIds.isNotEmpty) ...[
                              AppSpacing.vGapMd,
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedCategoryIds.map((id) {
                                  final category = categories.firstWhere(
                                    (c) => c.id == id,
                                    orElse: () => categories.first,
                                  );
                                  return Chip(
                                    label: Text(category.localizedName(context.locale.languageCode)),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedCategoryIds.remove(id);
                                      });
                                    },
                                    avatar: Icon(
                                      _getCategoryIcon(category.icon ?? 'general'),
                                      size: 18,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // Password Section
                    AppSpacing.vGapXl,
                    _SectionHeader(
                      title: _isEditing
                          ? 'sp_form.change_password'.tr()
                          : 'sp_form.account_setup'.tr(),
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
                                'sp_form.password_optional'.tr(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'sp_form.password'.tr(),
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
                                return 'sp_form.password_required'.tr();
                              }
                              if (value != null && value.isNotEmpty && value.length < 6) {
                                return 'sp_form.password_min_length'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.vGapXl,

                    // Availability & Status Section
                    _SectionHeader(title: 'sp_form.availability_status'.tr()),
                    AppSpacing.vGapMd,

                    _FormCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text('sp_form.available'.tr()),
                            subtitle: Text(
                              _isAvailable
                                  ? 'sp_form.available_desc'.tr()
                                  : 'sp_form.not_available_desc'.tr(),
                            ),
                            value: _isAvailable,
                            onChanged: (value) => setState(() => _isAvailable = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: Text('common.active'.tr()),
                            subtitle: Text(
                              _isActive
                                  ? 'sp_form.active_desc'.tr()
                                  : 'sp_form.inactive_desc'.tr(),
                            ),
                            value: _isActive,
                            onChanged: (value) => setState(() => _isActive = value),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),

                    // Time Slots Button (only for editing)
                    if (_isEditing) ...[
                      AppSpacing.vGapXl,
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('${RoutePaths.adminSPs}/${widget.spId}/slots'),
                          icon: const Icon(Icons.schedule),
                          label: Text('sp_list.manage_slots'.tr()),
                        ),
                      ),
                    ],

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
                            : Text(_isEditing ? 'sp_form.update'.tr() : 'sp_form.create'.tr()),
                      ),
                    ),

                    AppSpacing.vGapXxl,
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getCategoryIcon(String icon) {
    return switch (icon) {
      'plumbing' => Icons.plumbing,
      'electrical' => Icons.electrical_services,
      'hvac' => Icons.ac_unit,
      'carpentry' => Icons.carpenter,
      'painting' => Icons.format_paint,
      'general' => Icons.build,
      'cleaning' => Icons.cleaning_services,
      'landscaping' => Icons.grass,
      'security' => Icons.security,
      'elevator' => Icons.elevator,
      'pool' => Icons.pool,
      'gym' => Icons.fitness_center,
      _ => Icons.category,
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
