import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/issue_provider.dart';
import '../../widgets/common/issue_success_dialog.dart';
import '../../widgets/common/media_picker_dialog.dart';
import '../../widgets/category/multi_category_selector.dart';
import '../common/map_picker_screen.dart';

/// Create issue screen with form for reporting new issues
class CreateIssueScreen extends ConsumerStatefulWidget {
  const CreateIssueScreen({super.key});

  @override
  ConsumerState<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

/// Media item with type information
class _MediaItem {
  final File file;
  final ProofType type;

  _MediaItem({required this.file, required this.type});
}

class _CreateIssueScreenState extends ConsumerState<CreateIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  IssuePriority _selectedPriority = IssuePriority.medium;
  Set<int> _selectedCategoryIds = {};
  final List<_MediaItem> _attachedMedia = [];

  // Location state
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoadingLocation = false;
  bool _isLoadingAddress = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Capture current location automatically
  Future<void> _captureLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
      _address = null;
    });

    final locationService = ref.read(locationServiceProvider);

    try {
      final position = await locationService.getCurrentLocation();

      if (!mounted) return;

      if (position != null) {
        setState(() {
          _isLoadingLocation = false;
          _latitude = position.latitude;
          _longitude = position.longitude;
        });

        // Fetch address in background (non-blocking)
        _fetchAddress(position.latitude, position.longitude);
      } else {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'create_issue.location_error'.tr();
        });
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'create_issue.location_timeout'.tr();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'create_issue.location_error'.tr();
      });
    }
  }

  /// Fetch address from coordinates (non-blocking)
  Future<void> _fetchAddress(double lat, double lng) async {
    setState(() => _isLoadingAddress = true);

    final locationService = ref.read(locationServiceProvider);
    final address = await locationService.getAddressFromCoordinates(lat, lng);

    if (mounted) {
      setState(() {
        _address = address;
        _isLoadingAddress = false;
      });
    }
  }

  /// Open map picker screen
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _address,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _address = result['address'] as String?;
        _locationError = null;
      });
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if at least one category is selected
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('create_issue.category_required'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    final success = await ref
        .read(createIssueProvider.notifier)
        .createIssue(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          categoryIds: _selectedCategoryIds.toList(),
          priority: _selectedPriority.value,
          latitude: _latitude,
          longitude: _longitude,
          address: _address,
          mediaFiles: _attachedMedia.isNotEmpty
              ? _attachedMedia.map((m) => m.file).toList()
              : null,
        );

    if (mounted && success) {
      final isOnline = ref.read(isOnlineProvider);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => IssueSuccessDialog(
          isOnline: isOnline,
          onDismiss: () {
            Navigator.of(dialogContext).pop();
            context.pop();
          },
        ),
      );
    }
  }

  Future<void> _addMedia() async {
    final result = await MediaPickerDialog.show(
      context,
      allowVideo: true,
      allowAudio: true,
      allowPdf: true,
    );

    if (result != null && mounted) {
      setState(() {
        _attachedMedia.add(_MediaItem(
          file: result.file,
          type: result.type,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createIssueProvider);

    // Show error from create state
    ref.listen<CreateIssueState>(createIssueProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: context.colors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text('create_issue.title'.tr())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            // Title field
            _FormSection(
              title: 'create_issue.issue_title'.tr(),
              required: true,
              child: TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'create_issue.title_hint'.tr(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'create_issue.title_required'.tr();
                  }
                  if (value.trim().length < 5) {
                    return 'create_issue.title_min_length'.tr();
                  }
                  return null;
                },
              ),
            ),

            AppSpacing.vGapXl,

            // Description field
            _FormSection(
              title: 'create_issue.description'.tr(),
              child: TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'create_issue.description_hint'.tr(),
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
              ),
            ),

            AppSpacing.vGapXl,

            // Category selection with multi-select
            MultiCategorySelector(
              selectedIds: _selectedCategoryIds,
              onChanged: (ids) => setState(() => _selectedCategoryIds = ids),
              required: true,
              label: 'create_issue.category'.tr(),
            ),

            AppSpacing.vGapXl,

            // Priority selection
            _FormSection(
              title: 'create_issue.priority'.tr(),
              child: Row(
                children: IssuePriority.values.map((priority) {
                  final isSelected = _selectedPriority == priority;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: priority != IssuePriority.high
                            ? AppSpacing.sm
                            : 0,
                      ),
                      child: _PriorityOption(
                        priority: priority,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedPriority = priority);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            AppSpacing.vGapXl,

            // Location section
            _FormSection(
              title: 'create_issue.location'.tr(),
              child: _LocationSection(
                latitude: _latitude,
                longitude: _longitude,
                address: _address,
                isLoading: _isLoadingLocation,
                isLoadingAddress: _isLoadingAddress,
                error: _locationError,
                onRefresh: _captureLocation,
                onMapPicker: _openMapPicker,
              ),
            ),

            AppSpacing.vGapXl,

            // Media attachments
            _FormSection(
              title: 'create_issue.photos_videos'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attached media grid
                  if (_attachedMedia.isNotEmpty) ...[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ..._attachedMedia.asMap().entries.map((entry) {
                          return _MediaThumbnail(
                            mediaItem: entry.value,
                            onRemove: () {
                              setState(() {
                                _attachedMedia.removeAt(entry.key);
                              });
                            },
                          );
                        }),
                        _AddMediaButton(onTap: _addMedia),
                      ],
                    ),
                  ] else ...[
                    // Empty state - large add button
                    _EmptyMediaPicker(onTap: _addMedia),
                  ],
                ],
              ),
            ),

            AppSpacing.vGapXl,

            // Info card
            Container(
              padding: AppSpacing.allMd,
              decoration: BoxDecoration(
                color: context.colors.infoBg,
                borderRadius: AppRadius.allMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.colors.info,
                    size: 20,
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Text(
                      'create_issue.offline_note'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.vGapXxl,
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: context.colors.card,
          boxShadow: context.bottomNavShadow,
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: createState.isLoading ? null : _submitIssue,
              child: createState.isLoading
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
                  : Text('create_issue.submit_issue'.tr()),
            ),
          ),
        ),
      ),
    );
  }

}

/// Form section wrapper
class _FormSection extends StatelessWidget {
  final String title;
  final bool required;
  final Widget child;

  const _FormSection({
    required this.title,
    this.required = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: context.colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        AppSpacing.vGapSm,
        child,
      ],
    );
  }
}

/// Priority option widget
class _PriorityOption extends StatelessWidget {
  final IssuePriority priority;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityOption({
    required this.priority,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.priorityColor(priority);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : context.colors.card,
          borderRadius: AppRadius.allMd,
          border: Border.all(
            color: isSelected ? color : context.colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              priority == IssuePriority.high
                  ? Icons.arrow_upward
                  : priority == IssuePriority.low
                  ? Icons.arrow_downward
                  : Icons.remove,
              color: isSelected ? color : context.colors.textTertiary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              priority.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? color : context.colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Media thumbnail widget
class _MediaThumbnail extends StatelessWidget {
  final _MediaItem mediaItem;
  final VoidCallback onRemove;

  const _MediaThumbnail({required this.mediaItem, required this.onRemove});

  Widget _buildPreview(BuildContext context) {
    switch (mediaItem.type) {
      case ProofType.photo:
        return Image.file(
          mediaItem.file,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stackTrace) => Icon(
            Icons.broken_image,
            color: ctx.colors.textTertiary,
            size: 32,
          ),
        );
      case ProofType.video:
        return Center(
          child: Icon(
            Icons.videocam_rounded,
            color: context.colors.textTertiary,
            size: 32,
          ),
        );
      case ProofType.pdf:
        return Center(
          child: Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.red.shade700,
            size: 32,
          ),
        );
      case ProofType.audio:
        return Center(
          child: Icon(
            Icons.audiotrack_rounded,
            color: context.colors.textTertiary,
            size: 32,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: AppRadius.allMd,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildPreview(context),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.colors.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: context.colors.onPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add media button
class _AddMediaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMediaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.allMd,
          border: Border.all(
            color: context.colors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(Icons.add, color: context.colors.primary, size: 32),
      ),
    );
  }
}

/// Empty media picker
class _EmptyMediaPicker extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyMediaPicker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.allXl,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: context.colors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                color: context.colors.primary,
                size: 28,
              ),
            ),
            AppSpacing.vGapMd,
            Text(
              'create_issue.add_photos_videos'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            AppSpacing.vGapXs,
            Text(
              'create_issue.tap_attach'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location section widget
class _LocationSection extends ConsumerWidget {
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isLoading;
  final bool isLoadingAddress;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback? onMapPicker;

  const _LocationSection({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.isLoading,
    this.isLoadingAddress = false,
    required this.error,
    required this.onRefresh,
    this.onMapPicker,
  });

  bool get hasLocation => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: hasLocation
                  ? context.colors.success.withOpacity(0.5)
                  : context.colors.border,
            ),
          ),
          child: isLoading
              ? _buildLoadingState(context)
              : hasLocation
              ? _buildLocationCaptured(context)
              : _buildLocationError(context),
        ),
        if (onMapPicker != null) ...[
          AppSpacing.vGapMd,
          OutlinedButton.icon(
            onPressed: isOnline ? onMapPicker : null,
            icon: const Icon(Icons.map_rounded, size: 18),
            label: Text('create_issue.pick_on_map'.tr()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.buttonRadius,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(context.colors.primary),
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Text(
            'create_issue.getting_location'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCaptured(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.colors.success.withOpacity(0.1),
            borderRadius: AppRadius.allMd,
          ),
          child: Icon(
            Icons.location_on_rounded,
            color: context.colors.success,
            size: 22,
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'create_issue.location_captured'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.colors.success,
                ),
              ),
              if (isLoadingAddress)
                Text(
                  'create_issue.fetching_address'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (address != null)
                Text(
                  address!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  'create_issue.address_fetched'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: Icon(Icons.refresh, color: context.colors.primary),
          tooltip: 'create_issue.refresh_location'.tr(),
        ),
      ],
    );
  }

  Widget _buildLocationError(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.colors.warning.withOpacity(0.1),
            borderRadius: AppRadius.allMd,
          ),
          child: Icon(
            Icons.location_off_rounded,
            color: context.colors.warning,
            size: 22,
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'create_issue.location_not_available'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.colors.warning,
                ),
              ),
              Text(
                error ?? 'create_issue.enable_location'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text('common.retry'.tr()),
          style: TextButton.styleFrom(foregroundColor: context.colors.primary),
        ),
      ],
    );
  }
}
