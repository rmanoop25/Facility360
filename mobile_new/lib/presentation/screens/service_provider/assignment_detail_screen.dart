import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/assignment_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/assignment_provider.dart';
import '../../widgets/common/error_placeholder.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/shimmer/shimmer.dart';
import '../../widgets/common/sync_status_indicator.dart';
import '../../widgets/common/media_gallery_viewer.dart';
import '../../widgets/assignment/time_tracking_card.dart';
import '../../widgets/dialogs/request_extension_dialog.dart';

/// Assignment detail screen showing full assignment information
class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final String assignmentId; // This is actually the issueId

  const AssignmentDetailScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final issueId = int.tryParse(widget.assignmentId);

    if (issueId == null || issueId <= 0) {
      return Scaffold(
        appBar: AppBar(title: Text('assignment.job_details'.tr())),
        body: Center(child: Text('errors.invalid_assignment_id'.tr())),
      );
    }

    final assignmentAsync = ref.watch(assignmentDetailProvider(issueId));

    return assignmentAsync.when(
      data: (assignment) => _buildContent(context, assignment),
      loading: () => Scaffold(
        appBar: AppBar(title: Text('assignment.job_details'.tr())),
        body: const AssignmentDetailShimmer(),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('assignment.job_details'.tr())),
        body: ErrorPlaceholder(
          onRetry: () => ref.invalidate(assignmentDetailProvider(issueId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AssignmentModel assignment) {
    final issueId = int.tryParse(widget.assignmentId);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          if (issueId != null) {
            ref.invalidate(assignmentDetailProvider(issueId));
            // Wait for the provider to refresh
            await ref.read(assignmentDetailProvider(issueId).future);
          }
        },
        child: CustomScrollView(
          slivers: [
            // Offline banner
            const SliverOfflineBanner(),

            // App Bar with status - pinned header
            SliverAppBar(
              pinned: true,
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              toolbarHeight: 100,
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and sync badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.onPrimary.withAlpha(51),
                          borderRadius: AppRadius.badgeRadius,
                        ),
                        child: Text(
                          assignment.status.label,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (assignment.syncStatus != SyncStatus.synced) ...[
                        AppSpacing.gapSm,
                        SyncStatusIndicator(status: assignment.syncStatus),
                      ],
                    ],
                  ),
                  AppSpacing.vGapSm,
                  // Assignment ID
                  Text(
                    'sp.job_number'.tr(namedArgs: {'id': '${assignment.id}'}),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onPrimary.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Issue Info Card
                    _InfoCard(
                      title: 'assignment.issue_details'.tr(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.issueTitle ?? 'common.no_title'.tr(),
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (assignment.issueDescription != null &&
                              assignment.issueDescription!.isNotEmpty) ...[
                            AppSpacing.vGapSm,
                            Text(
                              assignment.issueDescription!,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                          AppSpacing.vGapMd,
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primaryLight.withAlpha(26),
                              borderRadius: AppRadius.badgeRadius,
                            ),
                            child: Text(
                              assignment.getCategoryName(
                                context.locale.languageCode,
                              ),
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Issue Photos (if any)
                    if (assignment.issueMedia.isNotEmpty) ...[
                      AppSpacing.vGapLg,
                      _InfoCard(
                        title: 'assignment.issue_photos'.tr(),
                        child: SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: assignment.issueMedia.length,
                            separatorBuilder: (_, i) => AppSpacing.gapMd,
                            itemBuilder: (context, index) {
                              final media = assignment.issueMedia[index];
                              return GestureDetector(
                                onTap: () {
                                  // Open media gallery viewer with all media
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MediaGalleryViewer(
                                        mediaItems: assignment.issueMedia,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: AppRadius.inputRadius,
                                  child: media.isPhoto
                                      ? Image.network(
                                          media.filePath,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: 100,
                                                    height: 100,
                                                    color: context.colors.surface,
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                        )
                                      : Container(
                                          width: 100,
                                          height: 100,
                                          color: context.colors.surfaceVariant,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                media.isVideo
                                                    ? Icons.videocam
                                                    : media.type == MediaType.audio
                                                        ? Icons.audiotrack
                                                        : Icons.picture_as_pdf,
                                                size: 40,
                                                color: context.colors.textTertiary,
                                              ),
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withAlpha(153),
                                                    borderRadius: AppRadius.badgeRadius,
                                                  ),
                                                  child: Text(
                                                    media.type.label.toUpperCase(),
                                                    style: context.textTheme.labelSmall?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    // Other Assignments Section (if any sibling assignments exist)
                    if (assignment.siblingAssignmentsCount > 0) ...[
                      AppSpacing.vGapLg,
                      _InfoCard(
                        title: 'sp.other_assignments'.tr(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info text
                            Container(
                              padding: AppSpacing.allSm,
                              decoration: BoxDecoration(
                                color: context.colors.infoBg,
                                borderRadius: AppRadius.inputRadius,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: context.colors.info,
                                  ),
                                  AppSpacing.gapSm,
                                  Expanded(
                                    child: Text(
                                      'sp.other_assignments_info'.tr(
                                        namedArgs: {
                                          'count':
                                              '${assignment.siblingAssignmentsCount}',
                                        },
                                      ),
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context.colors.info,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.vGapMd,
                            // List sibling assignments
                            ...assignment.siblingAssignments.map(
                              (sibling) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SiblingAssignmentCard(sibling: sibling),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    AppSpacing.vGapLg,

                    // Schedule Card
                    _InfoCard(
                      title: 'assignment.schedule'.tr(),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: assignment.isMultiDay
                                ? Icons.date_range_outlined
                                : Icons.calendar_today_outlined,
                            label: 'assignment.date'.tr(),
                            value: assignment.isMultiDay &&
                                    assignment.scheduledDateRange != null
                                ? assignment.scheduledDateRange!
                                : (assignment.isScheduledToday
                                    ? 'time.today'.tr()
                                    : assignment.scheduledDateFormatted ??
                                        'assignment.not_scheduled'.tr()),
                          ),
                          if (assignment.isMultiDay) ...[
                            AppSpacing.vGapMd,
                            _DetailRow(
                              icon: Icons.event_available_outlined,
                              label: 'assignment.duration'.tr(),
                              value:
                                  '${assignment.spanDays} ${'common.days'.tr()}',
                            ),
                          ],
                          if (!assignment.hasMultipleSlots &&
                              assignment.timeSlotDisplay != null) ...[
                            AppSpacing.vGapMd,
                            _DetailRow(
                              icon: Icons.schedule_outlined,
                              label: 'assignment.time_slot'.tr(),
                              value: assignment.timeSlotDisplay!,
                            ),
                          ],
                          if (assignment.assignedTimeRange != null) ...[
                            AppSpacing.vGapMd,
                            _DetailRow(
                              icon: Icons.access_time_outlined,
                              label: 'assignment.time_range'.tr(),
                              value: assignment.assignedTimeRange!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Multi-Slot Card (if applicable)
                    if (assignment.hasMultipleSlots) ...[
                      AppSpacing.vGapLg,
                      _buildMultiSlotCard(context, assignment),
                    ],

                    // Work Type & Duration Card
                    if (assignment.workType != null ||
                        assignment.allocatedDurationMinutes != null) ...[
                      AppSpacing.vGapLg,
                      _WorkTypeCard(assignment: assignment),
                    ],

                    // Time Tracking Card (only when work in progress)
                    if (assignment.status == AssignmentStatus.inProgress &&
                        assignment.allocatedDurationMinutes != null) ...[
                      AppSpacing.vGapLg,
                      TimeTrackingCard(
                        assignment: assignment,
                        onRequestExtension: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) =>
                                RequestExtensionDialog(assignment: assignment),
                          );
                          if (result == true && mounted) {
                            // Refresh assignment after extension request
                            final issueId = int.tryParse(widget.assignmentId);
                            if (issueId != null) {
                              ref.invalidate(assignmentDetailProvider(issueId));
                            }
                          }
                        },
                      ),
                    ],

                    // Extension Requests Card (if any exist)
                    if (assignment.extensionRequests.isNotEmpty) ...[
                      AppSpacing.vGapLg,
                      _ExtensionRequestsCard(requests: assignment.extensionRequests),
                    ],

                    AppSpacing.vGapLg,

                    // Location Card
                    _InfoCard(
                      title: 'assignment.location'.tr(),
                      child: Column(
                        children: [
                          if (assignment.tenantBuilding != null) ...[
                            _DetailRow(
                              icon: Icons.apartment_outlined,
                              label: 'assignment.building'.tr(),
                              value: assignment.tenantBuilding!,
                            ),
                            AppSpacing.vGapMd,
                          ],
                          if (assignment.tenantUnit != null) ...[
                            _DetailRow(
                              icon: Icons.door_front_door_outlined,
                              label: 'assignment.unit'.tr(),
                              value: assignment.tenantUnit!,
                            ),
                            AppSpacing.vGapLg,
                          ],
                          // Get Directions Button (if has location)
                          if (assignment.hasLocation)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final locationService = ref.read(
                                    locationServiceProvider,
                                  );
                                  final success = await locationService
                                      .openMapsNavigation(
                                        assignment.latitude!,
                                        assignment.longitude!,
                                      );
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'errors.maps_failed'.tr(),
                                        ),
                                        backgroundColor: context.colors.error,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.directions_outlined),
                                label: Text('assignment.get_directions'.tr()),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Work Progress (if started)
                    if (assignment.status != AssignmentStatus.assigned) ...[
                      AppSpacing.vGapLg,
                      _InfoCard(
                        title: 'assignment.work_progress'.tr(),
                        child: Column(
                          children: [
                            if (assignment.startedAt != null)
                              _DetailRow(
                                icon: Icons.play_circle_outline,
                                label: 'assignment.started'.tr(),
                                value: _formatTime(assignment.startedAt!, context.locale.languageCode),
                              ),
                            if (assignment.status ==
                                    AssignmentStatus.inProgress &&
                                assignment.workDuration != null) ...[
                              AppSpacing.vGapMd,
                              _DetailRow(
                                icon: Icons.timer_outlined,
                                label: 'assignment.duration'.tr(),
                                value: assignment.workDurationFormatted,
                                valueColor: context.colors.primary,
                              ),
                            ],
                            if (assignment.status == AssignmentStatus.onHold &&
                                assignment.heldAt != null) ...[
                              AppSpacing.vGapMd,
                              _DetailRow(
                                icon: Icons.pause_circle_outline,
                                label: 'assignment.on_hold_since'.tr(),
                                value: _formatTime(assignment.heldAt!, context.locale.languageCode),
                                valueColor: context.colors.warning,
                              ),
                            ],
                            if (assignment.status ==
                                    AssignmentStatus.finished ||
                                assignment.status ==
                                    AssignmentStatus.completed) ...[
                              if (assignment.finishedAt != null) ...[
                                AppSpacing.vGapMd,
                                _DetailRow(
                                  icon: Icons.check_circle_outline,
                                  label: 'admin.finished'.tr(),
                                  value: _formatTime(assignment.finishedAt!, context.locale.languageCode),
                                  valueColor: context.colors.statusCompleted,
                                ),
                              ],
                              AppSpacing.vGapMd,
                              _DetailRow(
                                icon: Icons.timer_outlined,
                                label: 'assignment.total_duration'.tr(),
                                value: assignment.workDurationFormatted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Consumables (if any)
                    if (assignment.consumables.isNotEmpty) ...[
                      AppSpacing.vGapLg,
                      _InfoCard(
                        title: 'assignment.materials_used'.tr(),
                        child: Column(
                          children: assignment.consumables
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c.getName(context.locale.languageCode),
                                        style: context.textTheme.bodyMedium,
                                      ),
                                      Text(
                                        'x${c.quantity}',
                                        style: context.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],

                    // Proofs (if any)
                    if (assignment.proofs.isNotEmpty) ...[
                      AppSpacing.vGapLg,
                      _InfoCard(
                        title: 'assignment.work_photos'.tr(),
                        child: SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: assignment.proofs.length,
                            separatorBuilder: (_, i) => AppSpacing.gapMd,
                            itemBuilder: (context, index) {
                              final proof = assignment.proofs[index];
                              return GestureDetector(
                                onTap: () {
                                  if (proof.filePath.isEmpty) return;
                                  final mediaItems = assignment.proofs
                                      .map((p) => p.toMediaModel())
                                      .toList();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MediaGalleryViewer(
                                        mediaItems: mediaItems,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: AppRadius.inputRadius,
                                  child: proof.isPhoto && proof.filePath.startsWith('http')
                                      ? Image.network(
                                          proof.filePath,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 100,
                                            height: 100,
                                            color: context.colors.surface,
                                            child: const Icon(Icons.broken_image_rounded),
                                          ),
                                        )
                                      : Container(
                                          width: 100,
                                          height: 100,
                                          color: context.colors.surfaceVariant,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                proof.isVideo
                                                    ? Icons.videocam_rounded
                                                    : proof.isAudio
                                                        ? Icons.audio_file_rounded
                                                        : proof.type.name == 'pdf'
                                                            ? Icons.picture_as_pdf_rounded
                                                            : Icons.photo_rounded,
                                                color: context.colors.textTertiary,
                                                size: 32,
                                              ),
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withAlpha(153),
                                                    borderRadius: AppRadius.badgeRadius,
                                                  ),
                                                  child: Text(
                                                    proof.isVideo
                                                        ? 'common.media_video'.tr()
                                                        : proof.isAudio
                                                            ? 'common.media_audio'.tr()
                                                            : proof.type.name == 'pdf'
                                                                ? 'common.media_pdf'.tr()
                                                                : 'common.media_photo'.tr(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    // Notes (if any)
                    if (assignment.notes != null &&
                        assignment.notes!.isNotEmpty) ...[
                      AppSpacing.vGapLg,
                      _InfoCard(
                        title: 'assignment.notes'.tr(),
                        child: Text(
                          assignment.notes!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],

                    // Bottom spacing
                    AppSpacing.vGapXxl,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Action buttons
      bottomNavigationBar: _buildBottomActions(context, assignment),
    );
  }

  /// Build multi-slot card showing all time slots for the assignment
  Widget _buildMultiSlotCard(BuildContext context, AssignmentModel assignment) {
    return _InfoCard(
      title: 'assignment.time_slots'.tr(),
      child: Column(
        children: [
          for (var i = 0; i < assignment.timeSlots.length; i++) ...[
            if (i > 0) AppSpacing.vGapMd,
            _buildTimeSlotRow(context, assignment.timeSlots[i]),
          ],
        ],
      ),
    );
  }

  /// Build a single time slot row with capacity indicator
  Widget _buildTimeSlotRow(BuildContext context, timeSlot) {
    return Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 18,
          color: context.colors.primary,
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeSlot.displayName ?? timeSlot.formattedRange ?? 'common.na'.tr(),
                style: context.textTheme.bodyMedium,
              ),
              if (timeSlot.availableMinutes != null &&
                  timeSlot.totalMinutes != null) ...[
                AppSpacing.vGapXs,
                Text(
                  'assignment.capacity'
                      .tr(namedArgs: {
                        'available': timeSlot.availableMinutes.toString(),
                        'total': timeSlot.totalMinutes.toString(),
                      }),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (timeSlot.utilizationPercent != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: timeSlot.hasCapacity ?? true
                  ? context.colors.successBg
                  : context.colors.errorBg,
              borderRadius: AppRadius.badgeRadius,
            ),
            child: Text(
              '${timeSlot.utilizationPercent}%',
              style: context.textTheme.labelSmall?.copyWith(
                color: timeSlot.hasCapacity ?? true
                    ? context.colors.success
                    : context.colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime, String locale) {
    return DateFormat.jm(locale).format(dateTime);
  }

  Widget? _buildBottomActions(
    BuildContext context,
    AssignmentModel assignment,
  ) {
    if (assignment.status == AssignmentStatus.completed ||
        assignment.status == AssignmentStatus.finished) {
      return null;
    }

    final workExecution = ref.watch(workExecutionProvider);
    final isLoading = workExecution.isLoading;

    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        boxShadow: context.bottomNavShadow,
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (assignment.status == AssignmentStatus.assigned) ...[
              // Start Work button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : () => _startWork(assignment),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      isLoading
                          ? 'assignment.starting'.tr()
                          : 'assignment.start_work'.tr(),
                    ),
                  ),
                ),
              ),
            ] else if (assignment.status == AssignmentStatus.inProgress) ...[
              // Put on Hold button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : () => _showHoldDialog(),
                    icon: const Icon(Icons.pause),
                    label: Text('common.hold'.tr()),
                  ),
                ),
              ),
              AppSpacing.gapMd,
              // Continue Work button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/sp/assignments/${widget.assignmentId}/work',
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text('assignment.continue_work'.tr()),
                  ),
                ),
              ),
            ] else if (assignment.status == AssignmentStatus.onHold) ...[
              // Resume Work button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : () => _resumeWork(assignment),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      isLoading
                          ? 'assignment.resuming'.tr()
                          : 'assignment.resume_work'.tr(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startWork(AssignmentModel assignment) async {
    ref.read(workExecutionProvider.notifier).initialize(assignment);
    final success = await ref.read(workExecutionProvider.notifier).startWork();

    if (success && mounted) {
      final issueId = int.tryParse(widget.assignmentId);
      if (issueId != null) {
        ref.invalidate(assignmentDetailProvider(issueId));
      }
      // Refresh assignment list to reflect the updated status
      ref.read(assignmentListProvider.notifier).refresh();
      // Navigate to work execution screen
      context.push('/sp/assignments/${widget.assignmentId}/work');
    } else if (mounted) {
      final error = ref.read(workExecutionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'assignment.start_failed'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  Future<void> _resumeWork(AssignmentModel assignment) async {
    ref.read(workExecutionProvider.notifier).initialize(assignment);
    final success = await ref.read(workExecutionProvider.notifier).resumeWork();

    if (success && mounted) {
      final issueId = int.tryParse(widget.assignmentId);
      if (issueId != null) {
        ref.invalidate(assignmentDetailProvider(issueId));
      }
      // Refresh assignment list to reflect the updated status
      ref.read(assignmentListProvider.notifier).refresh();
      // Navigate to work execution screen
      context.push('/sp/assignments/${widget.assignmentId}/work');
    } else if (mounted) {
      final error = ref.read(workExecutionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'assignment.resume_failed'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  void _showHoldDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('assignment.put_on_hold'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('assignment.hold_reason_prompt'.tr()),
            AppSpacing.vGapLg,
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'assignment.reason'.tr(),
                hintText: 'assignment.why_pausing'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _holdWork(reasonController.text.trim());
            },
            child: Text('common.put_on_hold'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _holdWork(String? reason) async {
    final issueId = int.tryParse(widget.assignmentId);
    if (issueId == null) return;

    final assignmentAsync = ref.read(assignmentDetailProvider(issueId));
    final assignment = assignmentAsync.valueOrNull;
    if (assignment == null) return;

    ref.read(workExecutionProvider.notifier).initialize(assignment);
    final success = await ref
        .read(workExecutionProvider.notifier)
        .holdWork(reason: reason?.isNotEmpty == true ? reason : null);

    if (success && mounted) {
      ref.invalidate(assignmentDetailProvider(issueId));
      // Refresh assignment list to reflect the updated status
      ref.read(assignmentListProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('assignment.work_on_hold'.tr()),
          backgroundColor: context.colors.warning,
        ),
      );
    } else if (mounted) {
      final error = ref.read(workExecutionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'assignment.hold_failed'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }
}

/// Info card wrapper
class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

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
              color: context.colors.textSecondary,
            ),
          ),
          AppSpacing.vGapMd,
          child,
        ],
      ),
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.textTertiary),
        AppSpacing.gapMd,
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Card for displaying sibling assignment info
class _SiblingAssignmentCard extends StatelessWidget {
  final SiblingAssignmentInfo sibling;

  const _SiblingAssignmentCard({required this.sibling});

  Color _getStatusColor(BuildContext context, String statusValue) {
    return switch (statusValue) {
      'assigned' => context.colors.statusAssigned,
      'in_progress' => context.colors.statusInProgress,
      'on_hold' => context.colors.warning,
      'finished' => context.colors.info,
      'completed' => context.colors.statusCompleted,
      _ => context.colors.textSecondary,
    };
  }

  Color _getStatusBgColor(BuildContext context, String statusValue) {
    return switch (statusValue) {
      'assigned' => context.colors.statusAssignedBg,
      'in_progress' => context.colors.statusInProgressBg,
      'on_hold' => context.colors.warningBg,
      'finished' => context.colors.infoBg,
      'completed' => context.colors.statusCompletedBg,
      _ => context.colors.surfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allSm,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.inputRadius,
      ),
      child: Row(
        children: [
          // Service provider avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: context.colors.primary.withAlpha(26),
            child: Text(
              (sibling.serviceProviderName ?? 'SP')[0].toUpperCase(),
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          AppSpacing.gapSm,
          // Name and category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sibling.serviceProviderName ?? 'sp.other_sp_working'.tr(),
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sibling.categoryName != null)
                  Text(
                    sibling.categoryName!,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusBgColor(context, sibling.statusValue),
              borderRadius: AppRadius.badgeRadius,
            ),
            child: Text(
              sibling.statusLabel,
              style: context.textTheme.labelSmall?.copyWith(
                color: _getStatusColor(context, sibling.statusValue),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Work Type Card showing work type and allocated duration
class _WorkTypeCard extends StatelessWidget {
  final AssignmentModel assignment;

  const _WorkTypeCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'assignment.work_info'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (assignment.workType != null) ...[
            _InfoRow(
              label: 'work_type.name'.tr(),
              value: assignment.workType!.name,
            ),
            AppSpacing.vGapSm,
          ],
          if (assignment.allocatedDurationMinutes != null) ...[
            _InfoRow(
              label: 'assignment.allocated_duration'.tr(),
              value: 'common.minutes_count'.tr(namedArgs: {'count': '${assignment.allocatedDurationMinutes}'}),
            ),
            if (assignment.approvedExtensionMinutes > 0) ...[
              AppSpacing.vGapSm,
              _InfoRow(
                label: 'extensions.approved_extension'.tr(),
                value: '+${assignment.approvedExtensionMinutes} ${'common.min'.tr()}',
                valueColor: context.colors.success,
              ),
            ],
            AppSpacing.vGapSm,
            _InfoRow(
              label: 'assignment.total_allowed'.tr(),
              value: 'common.minutes_count'.tr(namedArgs: {'count': '${assignment.totalAllowedMinutes}'}),
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Info row for work type card
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.textTheme.bodyMedium),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}

/// Extension Requests Card showing request history
class _ExtensionRequestsCard extends StatelessWidget {
  final List<dynamic> requests;

  const _ExtensionRequestsCard({required this.requests});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'extensions.request_history'.tr(),
      child: Column(
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) AppSpacing.vGapMd,
            _ExtensionRequestRow(request: requests[i]),
          ],
        ],
      ),
    );
  }
}

/// Extension request row
class _ExtensionRequestRow extends StatelessWidget {
  final dynamic request;

  const _ExtensionRequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          request.status.icon,
          color: request.status.color,
          size: 20,
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '+${request.requestedMinutes} ${'common.min'.tr()} - ${request.status.label}',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (request.adminNotes != null &&
                  request.adminNotes.isNotEmpty) ...[
                AppSpacing.vGapXs,
                Text(
                  request.adminNotes,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          DateFormat('MMM d, y', context.locale.languageCode).format(request.requestedAt),
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }
}
