import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/consumable_model.dart';
import '../../../domain/enums/enums.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/consumable_provider.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/common/media_picker_dialog.dart';
import '../../widgets/shimmer/shimmer.dart';
import '../../widgets/common/sync_status_indicator.dart';
import '../../../data/models/time_extension_request_model.dart';
import '../../../domain/enums/extension_status.dart';
import '../../widgets/dialogs/request_extension_dialog.dart';

/// Work execution screen where service providers do the actual work
class WorkExecutionScreen extends ConsumerStatefulWidget {
  final String assignmentId;

  const WorkExecutionScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<WorkExecutionScreen> createState() =>
      _WorkExecutionScreenState();
}

class _WorkExecutionScreenState extends ConsumerState<WorkExecutionScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  bool _isInitialized = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    final issueId = int.tryParse(widget.assignmentId);
    if (issueId == null) return;

    final assignmentAsync = await ref.read(assignmentDetailProvider(issueId).future);

    if (mounted) {
      ref.read(workExecutionProvider.notifier).initialize(assignmentAsync);

      // Calculate initial elapsed time from startedAt
      if (assignmentAsync.startedAt != null) {
        final now = DateTime.now();
        _elapsedSeconds = now.difference(assignmentAsync.startedAt!).inSeconds;
      }

      setState(() {
        _isInitialized = true;
      });

      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() => _elapsedSeconds++);
        ref
            .read(workExecutionProvider.notifier)
            .updateElapsedTime(Duration(seconds: _elapsedSeconds));
      }
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _addProof() async {
    try {
      final result = await MediaPickerDialog.show(
        context,
        allowVideo: true,
        allowAudio: true,
        allowPdf: true,
      );

      if (result != null && mounted) {
        ref.read(workExecutionProvider.notifier).addProofFile(result.file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('errors.media_picker_failed'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workState = ref.watch(workExecutionProvider);
    final assignment = workState.assignment;

    // Show loading if not initialized
    if (!_isInitialized || assignment == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Text('assignment.work_in_progress'.tr()),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: const AssignmentDetailShimmer(),
      );
    }

    // Get available consumables for this category
    final consumablesAsync =
        ref.watch(consumablesByCategoryProvider(assignment.categoryId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('assignment.work_in_progress'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(context),
        ),
        actions: [
          // Sync status indicator
          if (workState.syncStatus != SyncStatus.synced)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: SyncStatusIndicator(status: workState.syncStatus),
            ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          const OfflineBanner(),

          // Error message
          if (workState.error != null)
            Container(
              width: double.infinity,
              padding: AppSpacing.allMd,
              color: context.colors.error.withAlpha(25),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: context.colors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workState.error!,
                      style: TextStyle(color: context.colors.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        ref.read(workExecutionProvider.notifier).clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer Card
                  _TimerCard(
                    duration: _formatDuration(_elapsedSeconds),
                    isPaused: _isPaused,
                    onTogglePause: _togglePause,
                  ),

                  // Time Allocation / Extension section
                  // Always shown for in-progress assignments
                  AppSpacing.vGapMd,
                  _TimeAllocationCard(
                    elapsedMinutes: _elapsedSeconds ~/ 60,
                    allocatedMinutes: assignment.allocatedDurationMinutes,
                    totalAllowedMinutes: assignment.totalAllowedMinutes,
                    hasPendingExtension: assignment.hasPendingExtension,
                    canRequestExtension: assignment.canRequestExtension,
                    extensionRequests: assignment.extensionRequests,
                    onRequestExtension: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) =>
                            RequestExtensionDialog(assignment: assignment),
                      );
                      if (result == true && mounted) {
                        final issueId = int.tryParse(widget.assignmentId);
                        if (issueId != null) {
                          ref.invalidate(assignmentDetailProvider(issueId));
                          await _loadAssignment();
                        }
                      }
                    },
                  ),

                  AppSpacing.vGapLg,

                  // Job Info
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.issueTitle ?? 'sp.job_number'.tr(namedArgs: {'id': '${assignment.id}'}),
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppSpacing.vGapXs,
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 16, color: context.colors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              assignment.tenantAddress,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (assignment.issueDescription != null &&
                            assignment.issueDescription!.isNotEmpty) ...[
                          AppSpacing.vGapSm,
                          Text(
                            assignment.issueDescription!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  AppSpacing.vGapXl,

                  // Proof Photos Section
                  _SectionHeader(
                    title: 'assignment.completion_photos'.tr(),
                    subtitle: assignment.proofRequired
                        ? 'assignment.photo_required'.tr()
                        : 'assignment.photo_optional'.tr(),
                  ),
                  AppSpacing.vGapMd,
                  _ProofGrid(
                    photos: workState.proofFiles,
                    onAddPhoto: _addProof,
                    onRemovePhoto: (index) {
                      ref.read(workExecutionProvider.notifier).removeProofFile(index);
                    },
                  ),

                  AppSpacing.vGapXl,

                  // Consumables Section
                  _SectionHeader(
                    title: 'assignment.consumables_used'.tr(),
                    subtitle: 'assignment.select_materials'.tr(),
                  ),
                  AppSpacing.vGapMd,
                  consumablesAsync.when(
                    data: (consumables) => _ConsumablesSection(
                      availableConsumables: consumables,
                      selectedConsumables: workState.consumables,
                      onAddConsumable: (consumable) {
                        ref.read(workExecutionProvider.notifier).addConsumable(
                              ConsumableUsageEntry(
                                consumableId: consumable.id,
                                consumableName: consumable.localizedName(context.locale.languageCode),
                                quantity: 1,
                              ),
                            );
                      },
                      onAddCustomConsumable: (name, quantity) {
                        ref.read(workExecutionProvider.notifier).addConsumable(
                              ConsumableUsageEntry(
                                consumableId: null,
                                customName: name,
                                consumableName: name,
                                quantity: quantity,
                              ),
                            );
                      },
                      onUpdateQuantity: (index, quantity) {
                        if (quantity <= 0) {
                          ref
                              .read(workExecutionProvider.notifier)
                              .removeConsumable(index);
                        } else {
                          ref
                              .read(workExecutionProvider.notifier)
                              .updateConsumableQuantity(index, quantity);
                        }
                      },
                      onRemove: (index) {
                        ref
                            .read(workExecutionProvider.notifier)
                            .removeConsumable(index);
                      },
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: AppSpacing.allLg,
                        child: Text(
                          'errors.consumables_load_failed'.tr(),
                          style: TextStyle(color: context.colors.error),
                        ),
                      ),
                    ),
                  ),

                  AppSpacing.vGapXl,

                  // Notes Section
                  _SectionHeader(
                    title: 'assignment.notes'.tr(),
                    subtitle: 'assignment.notes_optional'.tr(),
                  ),
                  AppSpacing.vGapMd,
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'assignment.notes_hint'.tr(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      ref.read(workExecutionProvider.notifier).updateNotes(value);
                    },
                  ),

                  AppSpacing.vGapXxl,
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: context.colors.card,
          boxShadow: context.bottomNavShadow,
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Hold button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: workState.isLoading
                        ? null
                        : () => _showHoldDialog(context),
                    icon: const Icon(Icons.pause),
                    label: Text('common.put_on_hold'.tr()),
                  ),
                ),
              ),
              AppSpacing.gapMd,
              // Finish button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: workState.isLoading
                        ? null
                        : () => _showFinishDialog(context),
                    icon: workState.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(workState.isLoading ? 'common.processing'.tr() : 'assignment.finish_job'.tr()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('assignment.leave_work'.tr()),
        content: Text(
          'assignment.leave_work_desc'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.stay'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: Text('common.leave'.tr()),
          ),
        ],
      ),
    );
  }

  void _showHoldDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('assignment.put_job_on_hold'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('assignment.timer_paused_desc'.tr()),
            AppSpacing.vGapMd,
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'assignment.reason_optional'.tr(),
                hintText: 'assignment.hold_reason_hint'.tr(),
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

              final success = await ref
                  .read(workExecutionProvider.notifier)
                  .holdWork(reason: reasonController.text.isNotEmpty
                      ? reasonController.text
                      : null);

              if (success && mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('assignment.job_on_hold'.tr()),
                    backgroundColor: context.colors.warning,
                  ),
                );
              }
            },
            child: Text('common.hold'.tr()),
          ),
        ],
      ),
    );
  }

  void _showFinishDialog(BuildContext context) {
    final workState = ref.read(workExecutionProvider);

    // Validate required proofs
    if (workState.assignment?.proofRequired == true &&
        workState.proofFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('assignment.photo_required_error'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('assignment.finish_job_confirm'.tr()),
        content: Text(
          '${'assignment.total_time'.tr()}: ${_formatDuration(_elapsedSeconds)}\n'
          '${'assignment.photos'.tr()}: ${workState.proofFiles.length}\n'
          '${'assignment.consumables_count'.tr()}: ${workState.consumables.length} ${'common.items'.tr()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('assignment.continue_working'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final success =
                  await ref.read(workExecutionProvider.notifier).finishWork();

              if (success && mounted) {
                // Refresh assignment list to get latest status from server
                ref.read(assignmentListProvider.notifier).refresh();

                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: context.colors.onPrimary),
                        const SizedBox(width: 8),
                        Text('assignment.job_completed'.tr()),
                      ],
                    ),
                    backgroundColor: context.colors.success,
                  ),
                );
              }
            },
            child: Text('common.finish'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Timer card widget
class _TimerCard extends StatelessWidget {
  final String duration;
  final bool isPaused;
  final VoidCallback onTogglePause;

  const _TimerCard({
    required this.duration,
    required this.isPaused,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allXl,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.primary,
            context.colors.primaryDark,
          ],
        ),
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadowMd,
      ),
      child: Column(
        children: [
          Text(
            'assignment.time_elapsed'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.onPrimary.withAlpha(204),
                ),
          ),
          AppSpacing.vGapSm,
          Text(
            duration,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: context.colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
          ),
          AppSpacing.vGapLg,
          // Pause/Resume button
          SizedBox(
            width: 120,
            child: OutlinedButton.icon(
              onPressed: onTogglePause,
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'common.resume'.tr() : 'common.pause'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.onPrimary,
                side: BorderSide(color: context.colors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Info card widget
class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

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
      child: child,
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
        ),
      ],
    );
  }
}

/// Proof grid widget for displaying all proof media files
class _ProofGrid extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onAddPhoto;
  final Function(int) onRemovePhoto;

  const _ProofGrid({
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ...photos.asMap().entries.map((entry) {
          return _ProofThumbnail(
            file: entry.value,
            onRemove: () => onRemovePhoto(entry.key),
          );
        }),
        _AddProofButton(onTap: onAddPhoto),
      ],
    );
  }
}

/// Media thumbnail widget showing preview for all media types
class _ProofThumbnail extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ProofThumbnail({
    required this.file,
    required this.onRemove,
  });

  ProofType _detectMediaType() {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'pdf') return ProofType.pdf;
    if (extension == 'mp3') return ProofType.audio;
    if (extension == 'mp4') return ProofType.video;
    return ProofType.photo;
  }

  Widget _buildPreview(BuildContext context) {
    final type = _detectMediaType();
    switch (type) {
      case ProofType.photo:
        return Image.file(
          file,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.broken_image,
            color: context.colors.textTertiary,
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
    return Stack(
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
    );
  }
}

/// Add photo button widget
class _AddProofButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProofButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: context.colors.primary.withAlpha(13),
          borderRadius: AppRadius.allMd,
          border: Border.all(
            color: context.colors.primary.withAlpha(77),
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          color: context.colors.primary,
          size: 32,
        ),
      ),
    );
  }
}

/// Consumables section widget
class _ConsumablesSection extends StatelessWidget {
  final List<ConsumableModel> availableConsumables;
  final List<ConsumableUsageEntry> selectedConsumables;
  final Function(ConsumableModel) onAddConsumable;
  final Function(String name, int quantity) onAddCustomConsumable;
  final Function(int, int) onUpdateQuantity;
  final Function(int) onRemove;

  const _ConsumablesSection({
    required this.availableConsumables,
    required this.selectedConsumables,
    required this.onAddConsumable,
    required this.onAddCustomConsumable,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Get consumables not yet selected
    final availableToAdd = availableConsumables
        .where((c) =>
            !selectedConsumables.any((s) => s.consumableId == c.id) &&
            c.isActive)
        .toList();

    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          // Selected consumables
          if (selectedConsumables.isNotEmpty) ...[
            ...selectedConsumables.asMap().entries.map((entry) {
              final index = entry.key;
              final consumable = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ConsumableItem(
                  name: consumable.consumableName,
                  quantity: consumable.quantity,
                  onIncrement: () =>
                      onUpdateQuantity(index, consumable.quantity + 1),
                  onDecrement: () =>
                      onUpdateQuantity(index, consumable.quantity - 1),
                  onRemove: () => onRemove(index),
                ),
              );
            }),
            const Divider(),
            AppSpacing.vGapSm,
          ],

          // Add consumable dropdown
          if (availableToAdd.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showConsumablePicker(context, availableToAdd),
                icon: const Icon(Icons.add),
                label: Text('assignment.add_consumable'.tr()),
              ),
            ),

          // Add custom consumable button
          if (availableToAdd.isNotEmpty) AppSpacing.vGapSm,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCustomConsumableDialog(context),
              icon: const Icon(Icons.edit),
              label: Text('assignment.add_custom_consumable'.tr()),
            ),
          ),

          // Show message if no consumables available
          if (availableConsumables.isEmpty && selectedConsumables.isEmpty)
            Padding(
              padding: AppSpacing.allMd,
              child: Text(
                'assignment.no_consumables'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCustomConsumableDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('assignment.add_custom_consumable'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'assignment.consumable_name'.tr(),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            AppSpacing.vGapMd,
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'assignment.quantity'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text) ?? 1;
              if (name.isNotEmpty && quantity > 0) {
                Navigator.pop(dialogContext);
                onAddCustomConsumable(name, quantity);
              }
            },
            child: Text('common.add'.tr()),
          ),
        ],
      ),
    );
  }

  void _showConsumablePicker(
      BuildContext context, List<ConsumableModel> consumables) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.allLg,
              child: Text(
                'assignment.select_consumable'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: consumables.length,
                itemBuilder: (context, index) {
                  final consumable = consumables[index];
                  return ListTile(
                    title: Text(consumable.localizedName(context.locale.languageCode)),
                    subtitle: consumable.category != null
                        ? Text(consumable.category!.localizedName(context.locale.languageCode))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onAddConsumable(consumable);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consumable item widget with quantity controls
class _ConsumableItem extends StatelessWidget {
  final String name;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _ConsumableItem({
    required this.name,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Remove button
        IconButton(
          onPressed: onRemove,
          icon: Icon(Icons.remove_circle_outline, color: context.colors.error),
          iconSize: 20,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 8),
        // Name
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        // Quantity selector
        Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: AppRadius.allMd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: quantity > 1 ? onDecrement : null,
                icon: const Icon(Icons.remove),
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  quantity.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add),
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card showing time allocation progress and extension request button.
/// Shows progress bar when [allocatedMinutes] is set, otherwise shows
/// just the extension button for timed-out or untracked assignments.
class _TimeAllocationCard extends StatelessWidget {
  final int elapsedMinutes;
  final int? allocatedMinutes;   // null = no work type assigned
  final int? totalAllowedMinutes; // includes approved extensions
  final bool hasPendingExtension;
  final bool canRequestExtension;
  final List<TimeExtensionRequestModel> extensionRequests;
  final VoidCallback onRequestExtension;

  const _TimeAllocationCard({
    required this.elapsedMinutes,
    required this.allocatedMinutes,
    required this.totalAllowedMinutes,
    required this.hasPendingExtension,
    required this.canRequestExtension,
    required this.extensionRequests,
    required this.onRequestExtension,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = totalAllowedMinutes ?? allocatedMinutes;
    final hasAllocation = effectiveTotal != null;

    // Color coding
    Color progressColor = const Color(0xFF66BB6A); // green default
    double progress = 0.0;
    int overtime = 0;

    if (hasAllocation) {
      progress = (elapsedMinutes / effectiveTotal!).clamp(0.0, 1.0);
      overtime = elapsedMinutes - effectiveTotal;
      if (progress >= 1.0) {
        progressColor = const Color(0xFFEF5350); // red
      } else if (progress >= 0.75) {
        progressColor = const Color(0xFFFFA726); // orange
      }
    }

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: hasAllocation && overtime > 0
              ? const Color(0xFFEF5350).withAlpha(77)
              : context.colors.surfaceVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar row — only when allocation exists
          if (hasAllocation) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: progressColor),
                    AppSpacing.gapXs,
                    Text(
                      'assignment.allocated_duration'.tr(),
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  overtime > 0
                      ? '+${overtime} ${'common.min'.tr()} ${'assignment.overtime'.tr()}'
                      : '$elapsedMinutes / ${effectiveTotal} ${'common.min'.tr()}',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.vGapSm,
            ClipRRect(
              borderRadius: AppRadius.badgeRadius,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.colors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 6,
              ),
            ),
            AppSpacing.vGapMd,
          ],

          // Latest extension admin response (approved/rejected)
          ..._buildLatestResponse(context),

          // Extension button — visible when canRequestExtension
          if (canRequestExtension)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRequestExtension,
                icon: const Icon(Icons.more_time_rounded, size: 18),
                label: Text('extensions.request_extension'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: context.colors.primary),
                ),
              ),
            )
          else if (hasPendingExtension)
            Row(
              children: [
                const Icon(Icons.pending_outlined,
                    size: 16, color: Color(0xFFFFA726)),
                AppSpacing.gapXs,
                Text(
                  'extensions.pending_request'.tr(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFFFA726),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Returns banners for the most recent admin response (approved/rejected).
  List<Widget> _buildLatestResponse(BuildContext context) {
    final decided = extensionRequests
        .where((r) =>
            r.status == ExtensionStatus.approved ||
            r.status == ExtensionStatus.rejected)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    if (decided.isEmpty) return [];

    final latest = decided.first;
    final isApproved = latest.status == ExtensionStatus.approved;
    final bgColor =
        isApproved ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);
    final icon =
        isApproved ? Icons.check_circle_outline_rounded : Icons.cancel_outlined;
    final statusLabel = isApproved
        ? 'extensions.status.approved'.tr()
        : 'extensions.status.rejected'.tr();

    return [
      AppSpacing.vGapSm,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bgColor.withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: bgColor),
                AppSpacing.gapXs,
                Text(
                  '+${latest.requestedMinutes} ${'common.min'.tr()} — $statusLabel',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: bgColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (latest.adminNotes != null &&
                latest.adminNotes!.isNotEmpty) ...[
              AppSpacing.vGapXs,
              Text(
                latest.adminNotes!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      AppSpacing.vGapSm,
    ];
  }
}
