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
import '../../../domain/enums/proof_type.dart';
import '../../../data/models/tenant_model.dart';
import '../../providers/admin_issue_provider.dart';
import '../../widgets/category/multi_category_selector.dart';
import '../../widgets/common/media_picker_dialog.dart';
import '../common/map_picker_screen.dart';

/// Admin create issue screen - create issues on behalf of tenants
class AdminCreateIssueScreen extends ConsumerStatefulWidget {
  const AdminCreateIssueScreen({super.key});

  @override
  ConsumerState<AdminCreateIssueScreen> createState() =>
      _AdminCreateIssueScreenState();
}

class _AdminCreateIssueScreenState
    extends ConsumerState<AdminCreateIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Tenant selection
  TenantModel? _selectedTenant;

  // Form state
  IssuePriority _selectedPriority = IssuePriority.medium;
  final Set<int> _selectedCategoryIds = {};
  final List<MediaPickerResult> _attachedMedia = [];

  // Location state (optional for admin)
  bool _includeLocation = false;
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoadingLocation = false;
  bool _isLoadingAddress = false;
  String? _locationError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Capture current location when toggled on
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

        // Fetch address in background
        _fetchAddress(position.latitude, position.longitude);
      } else {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'admin.create_issue.location_error'.tr();
        });
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'admin.create_issue.location_timeout'.tr();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'admin.create_issue.location_error'.tr();
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
    // Check connectivity
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.create_issue.requires_connection'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Validate tenant selection
    if (_selectedTenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.create_issue.tenant_required'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    // Validate category selection
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('create_issue.category_required'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    final success =
        await ref.read(adminIssueActionProvider.notifier).createIssue(
              tenantId: _selectedTenant!.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              categoryIds: _selectedCategoryIds.toList(),
              priority: _selectedPriority.value,
              latitude: _includeLocation ? _latitude : null,
              longitude: _includeLocation ? _longitude : null,
              address: _includeLocation ? _address : null,
              mediaFiles: _attachedMedia.isNotEmpty
                  ? _attachedMedia.map((r) => r.file).toList()
                  : null,
            );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: context.colors.onPrimary,
              ),
              const SizedBox(width: 8),
              Text('admin.create_issue.success'.tr()),
            ],
          ),
          backgroundColor: context.colors.success,
        ),
      );

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminIssueActionProvider);
    final isOnline = ref.watch(isOnlineProvider);

    // Show error from action state
    ref.listen<AdminIssueActionState>(adminIssueActionProvider, (previous, next) {
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
      appBar: AppBar(
        title: Text('admin.create_issue.title'.tr()),
      ),
      body: !isOnline
          ? _buildOfflineMessage(context)
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.screen,
                children: [
                  // Connectivity warning banner
                  Container(
                    padding: AppSpacing.allSm,
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
                            'admin.create_issue.info_note'.tr(),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.vGapLg,

                  // Tenant selection
                  _FormSection(
                    title: 'admin.create_issue.select_tenant'.tr(),
                    required: true,
                    child: _TenantPickerField(
                      selectedTenant: _selectedTenant,
                      onChanged: (tenant) {
                        setState(() => _selectedTenant = tenant);
                      },
                    ),
                  ),

                  AppSpacing.vGapXl,

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
                    onChanged: (ids) => setState(() {
                      _selectedCategoryIds.clear();
                      _selectedCategoryIds.addAll(ids);
                    }),
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

                  // Location toggle (optional for admin)
                  _FormSection(
                    title: 'create_issue.location'.tr(),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _includeLocation,
                          onChanged: (value) {
                            setState(() => _includeLocation = value);
                            if (value && _latitude == null) {
                              _captureLocation();
                            }
                          },
                          title: Text(
                            'admin.create_issue.include_location'.tr(),
                            style: context.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            'admin.create_issue.location_subtitle'.tr(),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_includeLocation) ...[
                          AppSpacing.vGapSm,
                          _LocationSection(
                            latitude: _latitude,
                            longitude: _longitude,
                            address: _address,
                            isLoading: _isLoadingLocation,
                            isLoadingAddress: _isLoadingAddress,
                            error: _locationError,
                            onRefresh: _captureLocation,
                            onMapPicker: _openMapPicker,
                          ),
                        ],
                      ],
                    ),
                  ),

                  AppSpacing.vGapXl,

                  // Media attachments
                  _FormSection(
                    title: 'create_issue.add_media'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'create_issue.supported_types_hint'.tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                        AppSpacing.vGapSm,
                        if (_attachedMedia.isNotEmpty) ...[
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              ..._attachedMedia.asMap().entries.map((entry) {
                                return _MediaThumbnail(
                                  result: entry.value,
                                  onRemove: () {
                                    setState(() {
                                      _attachedMedia.removeAt(entry.key);
                                    });
                                  },
                                );
                              }),
                              _AddMediaButton(
                                onTap: () => _showMediaPicker(context),
                              ),
                            ],
                          ),
                        ] else ...[
                          _EmptyMediaPicker(
                            onTap: () => _showMediaPicker(context),
                          ),
                        ],
                      ],
                    ),
                  ),

                  AppSpacing.vGapXxl,
                ],
              ),
            ),
      bottomNavigationBar: isOnline
          ? Container(
              padding: AppSpacing.allLg,
              decoration: BoxDecoration(
                color: context.colors.card,
                boxShadow: context.bottomNavShadow,
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: actionState.isLoading ? null : _submitIssue,
                    child: actionState.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  context.colors.onPrimary),
                            ),
                          )
                        : Text('admin.create_issue.submit'.tr()),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildOfflineMessage(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.allXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: context.colors.textTertiary,
            ),
            AppSpacing.vGapLg,
            Text(
              'admin.create_issue.offline_title'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapSm,
            Text(
              'admin.create_issue.requires_connection'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMediaPicker(BuildContext context) async {
    final result = await MediaPickerDialog.show(context);
    if (result != null && mounted) {
      setState(() {
        _attachedMedia.add(result);
      });
    }
  }
}

/// Tappable field that opens the searchable tenant picker sheet
class _TenantPickerField extends StatelessWidget {
  final TenantModel? selectedTenant;
  final ValueChanged<TenantModel?> onChanged;

  const _TenantPickerField({
    required this.selectedTenant,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedTenant != null;
    return InkWell(
      onTap: () async {
        final result = await showModalBottomSheet<TenantModel>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _TenantPickerSheet(),
        );
        if (result != null) {
          onChanged(result);
        }
      },
      borderRadius: AppRadius.allMd,
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.person_outline_rounded),
          suffixIcon: const Icon(Icons.search_rounded),
          hintText: 'admin.create_issue.select_tenant_hint'.tr(),
        ),
        child: hasSelection
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedTenant!.userName ?? 'common.na'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${selectedTenant!.unitNumber} - ${selectedTenant!.buildingName}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Bottom sheet for searching and selecting a tenant with lazy pagination
class _TenantPickerSheet extends ConsumerStatefulWidget {
  const _TenantPickerSheet();

  @override
  ConsumerState<_TenantPickerSheet> createState() => _TenantPickerSheetState();
}

class _TenantPickerSheetState extends ConsumerState<_TenantPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tenantPickerProvider.notifier).filterByActive(true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(tenantPickerProvider.notifier).search(query);
    });
  }

  void _onScroll(ScrollController scrollController) {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      ref.read(tenantPickerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantPickerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        scrollController.addListener(() => _onScroll(scrollController));

        return Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: AppRadius.allFull,
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Text(
                  'admin.create_issue.select_tenant'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'common.search'.tr(),
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  ),
                ),
              ),

              AppSpacing.vGapSm,

              // List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null && state.tenants.isEmpty
                        ? _buildError(context, state.error!)
                        : state.tenants.isEmpty
                            ? _buildEmpty(context)
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: state.tenants.length +
                                    (state.isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == state.tenants.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  final tenant = state.tenants[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: context.colors.primary
                                          .withOpacity(0.12),
                                      child: Text(
                                        (tenant.userName ?? '?')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      tenant.userName ?? 'common.na'.tr(),
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      '${tenant.unitNumber} · ${tenant.buildingName}',
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                              color:
                                                  context.colors.textSecondary),
                                    ),
                                    onTap: () => Navigator.of(context).pop(tenant),
                                  );
                                },
                              ),
              ),

              // Safe area padding
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: context.colors.error),
          AppSpacing.vGapMd,
          Text('admin.create_issue.tenant_load_error'.tr(),
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: context.colors.error)),
          AppSpacing.vGapMd,
          TextButton.icon(
            onPressed: () =>
                ref.read(tenantPickerProvider.notifier).filterByActive(true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              size: 48, color: context.colors.textTertiary),
          AppSpacing.vGapMd,
          Text('common.no_results'.tr(),
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary)),
        ],
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
          icon: Icon(
            Icons.refresh_rounded,
            color: context.colors.primary,
          ),
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
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text('common.retry'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
          ),
        ),
      ],
    );
  }
}

/// Media thumbnail widget
class _MediaThumbnail extends StatelessWidget {
  final MediaPickerResult result;
  final VoidCallback onRemove;

  const _MediaThumbnail({
    required this.result,
    required this.onRemove,
  });

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
            child: _buildContent(context),
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
                  Icons.close_rounded,
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

  Widget _buildContent(BuildContext context) {
    switch (result.type) {
      case ProofType.photo:
        return Image.file(
          result.file,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stackTrace) => Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: ctx.colors.textTertiary,
              size: 32,
            ),
          ),
        );
      case ProofType.video:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_rounded, color: context.colors.textSecondary, size: 28),
              const SizedBox(height: 2),
              Text('MP4', style: TextStyle(color: context.colors.textTertiary, fontSize: 10)),
            ],
          ),
        );
      case ProofType.audio:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.audio_file_rounded, color: context.colors.textSecondary, size: 28),
              const SizedBox(height: 2),
              Text('MP3', style: TextStyle(color: context.colors.textTertiary, fontSize: 10)),
            ],
          ),
        );
      case ProofType.pdf:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: context.colors.error, size: 28),
              const SizedBox(height: 2),
              Text('PDF', style: TextStyle(color: context.colors.textTertiary, fontSize: 10)),
            ],
          ),
        );
    }
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
        child: Icon(
          Icons.add,
          color: context.colors.primary,
          size: 32,
        ),
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
                Icons.add_photo_alternate_outlined,
                color: context.colors.primary,
                size: 28,
              ),
            ),
            AppSpacing.vGapMd,
            Text(
              'create_issue.add_photos_videos'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            AppSpacing.vGapXs,
            Text(
              'create_issue.tap_to_attach'.tr(),
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

