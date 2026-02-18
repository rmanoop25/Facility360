import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Screen for picking a location on a Google Map
/// Returns a Map<String, dynamic> with 'latitude', 'longitude', and 'address' keys
class MapPickerScreen extends ConsumerStatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  // Selected location
  LatLng? _selectedLocation;
  String? _selectedAddress;

  // Loading states
  bool _isSearching = false;
  bool _isFetchingAddress = false;
  bool _isLoadingCurrentLocation = false;

  // Default location (can be customized per deployment)
  static const LatLng _defaultLocation = LatLng(25.2048, 55.2708); // Dubai

  @override
  void initState() {
    super.initState();
    // Initialize with provided location or default
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _selectedAddress = widget.initialAddress;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Handle map tap to select location
  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isFetchingAddress = true;
    });

    try {
      // Fetch address for selected location
      final locationService = ref.read(locationServiceProvider);
      final address = await locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isFetchingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('MapPickerScreen: _onMapTap error - $e');
      if (mounted) {
        setState(() {
          _selectedAddress = null;
          _isFetchingAddress = false;
        });
        context.showErrorSnackBar('create_issue.address_fetch_failed'.tr());
      }
    }
  }

  /// Search for location by address
  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    context.unfocus();

    setState(() {
      _isSearching = true;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final coords = await locationService.getCoordinatesFromAddress(query);

      if (coords != null && mounted) {
        final position = LatLng(coords.latitude, coords.longitude);

        setState(() {
          _selectedLocation = position;
          _selectedAddress = query;
          _isSearching = false;
        });

        // Animate camera to new position
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(position, 16),
        );
      } else if (mounted) {
        setState(() {
          _isSearching = false;
        });
        context.showErrorSnackBar('create_issue.location_not_found'.tr());
      }
    } catch (e) {
      debugPrint('MapPickerScreen: _searchLocation error - $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        context.showErrorSnackBar('create_issue.location_not_found'.tr());
      }
    }
  }

  /// Get current device location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentLocation();

      if (position != null && mounted) {
        final latLng = LatLng(position.latitude, position.longitude);

        setState(() {
          _selectedLocation = latLng;
          _isFetchingAddress = true;
          _isLoadingCurrentLocation = false;
        });

        // Animate camera to current position
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16),
        );

        // Fetch address
        try {
          final address = await locationService.getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (mounted) {
            setState(() {
              _selectedAddress = address;
              _isFetchingAddress = false;
            });
          }
        } catch (e) {
          debugPrint('MapPickerScreen: reverse geocoding error - $e');
          if (mounted) {
            setState(() {
              _selectedAddress = null;
              _isFetchingAddress = false;
            });
          }
        }
      } else if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
        context.showErrorSnackBar('create_issue.location_fetch_failed'.tr());
      }
    } catch (e) {
      debugPrint('MapPickerScreen: _getCurrentLocation error - $e');
      if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
          _isFetchingAddress = false;
        });
        context.showErrorSnackBar('create_issue.location_fetch_failed'.tr());
      }
    }
  }

  /// Confirm selected location and return to previous screen
  void _confirmLocation() {
    if (_selectedLocation == null) {
      context.showWarningSnackBar('create_issue.select_location_first'.tr());
      return;
    }

    Navigator.of(context).pop({
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'address': _selectedAddress,
    });
  }

  /// Get dark mode map style
  String get _darkMapStyle => '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
]
''';

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDarkMode = context.isDarkMode;

    // Initial camera position
    final initialPosition = _selectedLocation ?? _defaultLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text('create_issue.pick_on_map'.tr()),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: _selectedLocation != null ? 16 : 12,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Apply dark mode style if needed
              if (isDarkMode) {
                try {
                  controller.setMapStyle(_darkMapStyle);
                } catch (e) {
                  debugPrint('MapPickerScreen: setMapStyle error - $e');
                }
              }
            },
            onTap: _onMapTap,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                      infoWindow: InfoWindow(
                        title: 'create_issue.selected_location'.tr(),
                        snippet: _selectedAddress,
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Search bar at top
          Positioned(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.inputRadius,
                boxShadow: context.cardShadow,
              ),
              child: TextField(
                controller: _searchController,
                enabled: isOnline,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchLocation(),
                decoration: InputDecoration(
                  hintText: 'create_issue.search_location'.tr(),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.colors.textSecondary,
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: AppSpacing.allMd,
                          child: SizedBox(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.primary,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.send_rounded,
                            color: context.colors.primary,
                          ),
                          onPressed: isOnline ? _searchLocation : null,
                        ),
                  border: InputBorder.none,
                  contentPadding: AppSpacing.allLg,
                ),
              ),
            ),
          ),

          // Address preview at bottom
          Positioned(
            bottom: AppSpacing.xxxl + AppSpacing.xl,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Container(
              padding: AppSpacing.allLg,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.cardRadius,
                boxShadow: context.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: context.colors.primary,
                        size: 20,
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'create_issue.selected_location'.tr(),
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapSm,
                  if (_isFetchingAddress)
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        AppSpacing.gapSm,
                        Text(
                          'create_issue.fetching_address'.tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else if (_selectedAddress != null)
                    Text(
                      _selectedAddress!,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (_selectedLocation != null)
                    Text(
                      '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    )
                  else
                    Text(
                      'create_issue.tap_to_select'.tr(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  AppSpacing.vGapLg,
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selectedLocation != null ? _confirmLocation : null,
                      icon: const Icon(Icons.check_rounded),
                      label: Text('create_issue.confirm_location'.tr()),
                      style: FilledButton.styleFrom(
                        padding: AppSpacing.verticalLg,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FAB for current location
          Positioned(
            bottom: AppSpacing.xxxl + AppSpacing.xl + 180,
            right: AppSpacing.lg,
            child: FloatingActionButton(
              heroTag: 'my_location',
              onPressed: isOnline && !_isLoadingCurrentLocation
                  ? _getCurrentLocation
                  : null,
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.primary,
              elevation: 4,
              child: _isLoadingCurrentLocation
                  ? SizedBox(
                      width: AppSpacing.xl,
                      height: AppSpacing.xl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.primary,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          // Offline banner
          if (!isOnline)
            Positioned(
              top: AppSpacing.lg + 60,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                padding: AppSpacing.allMd,
                decoration: BoxDecoration(
                  color: context.colors.warningBg,
                  borderRadius: AppRadius.allSm,
                  border: Border.all(color: context.colors.warning),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: context.colors.warning,
                      size: 18,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'common.offline_mode'.tr(),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
