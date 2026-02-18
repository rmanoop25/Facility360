import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/proof_model.dart';
import '../../../domain/enums/proof_type.dart';
import '../../providers/admin_issue_provider.dart';
import '../../widgets/common/media_gallery_viewer.dart';
import '../../widgets/common/offline_banner.dart';

/// Approve Work Screen
/// Displays work summary, before/after photos, consumables, and approval actions
class ApproveWorkScreen extends ConsumerStatefulWidget {
  final String issueId;

  const ApproveWorkScreen({super.key, required this.issueId});

  @override
  ConsumerState<ApproveWorkScreen> createState() => _ApproveWorkScreenState();
}

class _ApproveWorkScreenState extends ConsumerState<ApproveWorkScreen> {
  Future<void> _approveWork() async {
    final success = await ref.read(adminIssueActionProvider.notifier).approveIssue(
      int.parse(widget.issueId),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('approve.work_approved'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        // Go back to issues list
        context.pop();
        context.pop(); // Pop detail screen too
      } else {
        final error = ref.read(adminIssueActionProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'approve.approve_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('approve.reject_work'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('approve.rejection_reason_prompt'.tr()),
            AppSpacing.vGapMd,
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'approve.rejection_hint'.tr(),
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
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('approve.reason_min_length'.tr()),
                    backgroundColor: context.colors.error,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);

              try {
                await ref.read(adminIssueActionProvider.notifier).cancelIssue(
                  int.parse(widget.issueId),
                  reason: reasonController.text.trim(),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('approve.work_rejected'.tr()),
                      backgroundColor: context.colors.success,
                    ),
                  );
                  context.pop();
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('approve.reject_failed'.tr(namedArgs: {'error': e.toString()})),
                      backgroundColor: context.colors.error,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            child: Text('approve.reject'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issueAsync = ref.watch(adminIssueDetailProvider(int.parse(widget.issueId)));
    final actionState = ref.watch(adminIssueActionProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('approve.title'.tr()),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: issueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: context.colors.error),
                    AppSpacing.vGapLg,
                    Text('errors.load_failed'.tr(), style: context.textTheme.titleMedium),
                    AppSpacing.vGapSm,
                    Text(
                      error.toString(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vGapLg,
                    FilledButton(
                      onPressed: () => ref.invalidate(adminIssueDetailProvider(int.parse(widget.issueId))),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
              data: (issue) => _buildContent(issue, actionState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(IssueModel issue, AdminIssueActionState actionState) {
    // Get the latest assignment (finished work)
    final assignment = issue.currentAssignment;

    if (assignment == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 64, color: context.colors.textTertiary),
            AppSpacing.vGapLg,
            Text(
              'approve.no_assignment'.tr(),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              'approve.no_assignment_desc'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Separate proofs by stage: duringWork = before/during photos, completion = after photos
    final beforeProofs = assignment.proofs.where((p) => p.stage == ProofStage.duringWork).toList();
    final afterProofs = assignment.proofs.where((p) => p.stage == ProofStage.completion).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Issue Summary Card
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 48,
                            decoration: BoxDecoration(
                              color: context.priorityColor(issue.priority),
                              borderRadius: AppRadius.allSm,
                            ),
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue.title,
                                  style: context.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AppSpacing.vGapXs,
                                Text(
                                  issue.tenantAddress,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vGapMd,
                      const Divider(),
                      AppSpacing.vGapMd,
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                            child: Text(
                              (assignment.serviceProvider?.displayName ?? 'S')[0].toUpperCase(),
                              style: TextStyle(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'approve.completed_by'.tr(),
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: context.colors.textTertiary,
                                  ),
                                ),
                                Text(
                                  assignment.serviceProvider?.displayName ?? 'sp.service_provider'.tr(),
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.assignmentStatusBgColor(assignment.status),
                              borderRadius: AppRadius.badgeRadius,
                            ),
                            child: Text(
                              assignment.status.label,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: context.assignmentStatusColor(assignment.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                AppSpacing.vGapLg,

                // Work Summary Card
                _InfoCard(
                  title: 'approve.work_summary'.tr(),
                  child: Column(
                    children: [
                      _SummaryRow(
                        icon: Icons.timer_outlined,
                        label: 'assignment.duration'.tr(),
                        value: assignment.workDurationFormatted,
                      ),
                      AppSpacing.vGapMd,
                      _SummaryRow(
                        icon: Icons.play_circle_outline,
                        label: 'assignment.started'.tr(),
                        value: assignment.startedAt != null
                            ? DateFormat('h:mm a', context.locale.languageCode).format(assignment.startedAt!)
                            : '-',
                      ),
                      AppSpacing.vGapMd,
                      _SummaryRow(
                        icon: Icons.check_circle_outline,
                        label: 'admin.finished'.tr(),
                        value: assignment.finishedAt != null
                            ? DateFormat('h:mm a', context.locale.languageCode).format(assignment.finishedAt!)
                            : '-',
                      ),
                      if (assignment.scheduledDate != null) ...[
                        AppSpacing.vGapMd,
                        _SummaryRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'approve.scheduled'.tr(),
                          value: assignment.isMultiDay && assignment.scheduledDateRange != null
                              ? assignment.scheduledDateRange!
                              : DateFormat('MMM d, y', context.locale.languageCode).format(assignment.scheduledDate!),
                          badge: assignment.isMultiDay
                              ? 'common.days_count'.tr(namedArgs: {'count': '${assignment.spanDays}'})
                              : null,
                        ),
                      ],
                      // Time slot information (multi-slot aware)
                      if (assignment.timeSlotId != null || assignment.hasMultipleSlots) ...[
                        AppSpacing.vGapMd,
                        _SummaryRow(
                          icon: Icons.schedule_rounded,
                          label: 'admin.assign.time_slots_label'.tr(),
                          value: assignment.hasMultipleSlots
                              ? 'admin.assign.slots_selected'.tr(namedArgs: {
                                  'count': assignment.timeSlotCount.toString(),
                                })
                              : assignment.timeSlotDisplay ?? 'N/A',
                          badge: assignment.hasMultipleSlots ? 'admin.assign.multi_slot'.tr() : null,
                        ),
                      ],
                      // Time range override display
                      if (assignment.assignedTimeRange != null) ...[
                        AppSpacing.vGapMd,
                        _SummaryRow(
                          icon: Icons.access_time_rounded,
                          label: 'admin.assign.work_time_range'.tr(),
                          value: assignment.assignedTimeRange!,
                        ),
                      ],
                    ],
                  ),
                ),

                AppSpacing.vGapLg,

                // Before Photos (completion proofs)
                if (beforeProofs.isNotEmpty)
                  _InfoCard(
                    title: 'approve.before_photos'.tr(),
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: beforeProofs.length,
                        separatorBuilder: (_, __) => AppSpacing.gapMd,
                        itemBuilder: (context, index) => _buildProofThumbnail(
                          beforeProofs[index],
                          context,
                          isBefore: true,
                          allProofs: beforeProofs,
                          index: index,
                        ),
                      ),
                    ),
                  )
                else
                  _InfoCard(
                    title: 'approve.before_photos'.tr(),
                    child: Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: Text(
                        'approve.no_before_photos'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),

                AppSpacing.vGapLg,

                // After Photos (inspection proofs)
                if (afterProofs.isNotEmpty)
                  _InfoCard(
                    title: 'approve.after_photos'.tr(),
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: afterProofs.length,
                        separatorBuilder: (_, __) => AppSpacing.gapMd,
                        itemBuilder: (context, index) => _buildProofThumbnail(
                          afterProofs[index],
                          context,
                          isBefore: false,
                          allProofs: afterProofs,
                          index: index,
                        ),
                      ),
                    ),
                  )
                else
                  _InfoCard(
                    title: 'approve.after_photos'.tr(),
                    child: Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: Text(
                        'approve.no_after_photos'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),

                AppSpacing.vGapLg,

                // Consumables Used
                if (assignment.consumables.isNotEmpty)
                  _InfoCard(
                    title: 'assignment.consumables_used'.tr(),
                    child: Column(
                      children: [
                        ...assignment.consumables.map((consumable) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: context.colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                AppSpacing.gapMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        consumable.getName(context.locale.languageCode),
                                        style: context.textTheme.bodyMedium,
                                      ),
                                      if (consumable.quantity > 1)
                                        Text(
                                          'common.qty'.tr(namedArgs: {'count': '${consumable.quantity}'}),
                                          style: context.textTheme.labelSmall?.copyWith(
                                            color: context.colors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(),
                        AppSpacing.vGapSm,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'approve.total_items'.tr(),
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${assignment.totalConsumablesCount}',
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  _InfoCard(
                    title: 'assignment.consumables_used'.tr(),
                    child: Container(
                      padding: AppSpacing.allMd,
                      alignment: Alignment.center,
                      child: Text(
                        'approve.no_consumables'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),

                AppSpacing.vGapLg,

                // SP Notes
                _InfoCard(
                  title: 'approve.sp_notes'.tr(),
                  child: Text(
                    assignment.notes?.isNotEmpty == true
                        ? assignment.notes!
                        : 'approve.no_notes'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: assignment.notes?.isNotEmpty == true
                          ? context.colors.textPrimary
                          : context.colors.textTertiary,
                    ),
                  ),
                ),

                // Bottom spacing for buttons
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // Bottom Action Buttons
        Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            color: context.colors.card,
            boxShadow: context.bottomNavShadow,
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionState.isLoading ? null : _showRejectDialog,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('approve.reject_work'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error,
                      side: BorderSide(color: context.colors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: actionState.isLoading ? null : _approveWork,
                    icon: actionState.isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_outline),
                    label: actionState.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(context.colors.onPrimary),
                            ),
                          )
                        : Text('approve.approve_complete'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofThumbnail(
    ProofModel proof,
    BuildContext context, {
    required bool isBefore,
    required List<ProofModel> allProofs,
    required int index,
  }) {
    final isNetworkUrl = proof.displayUrl.startsWith('http');
    final accentColor = isBefore ? context.colors.textTertiary : context.colors.success;

    return GestureDetector(
      onTap: () {
        if (!isNetworkUrl && !proof.isLocal) return;
        final mediaItems = allProofs.map((p) => p.toMediaModel()).toList();
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
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: isBefore
              ? context.colors.surfaceVariant
              : context.colors.success.withValues(alpha: 0.05),
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isBefore
                ? context.colors.border
                : context.colors.success.withValues(alpha: 0.3),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: isNetworkUrl && proof.isPhoto
              ? Image.network(
                  proof.displayUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildProofTypePlaceholder(context, proof, accentColor),
                )
              : _buildProofTypePlaceholder(context, proof, accentColor),
        ),
      ),
    );
  }

  Widget _buildProofTypePlaceholder(BuildContext context, ProofModel proof, Color color) {
    final IconData icon;
    final String label;
    if (proof.isVideo) {
      icon = Icons.videocam_rounded;
      label = 'common.media_video'.tr();
    } else if (proof.isAudio) {
      icon = Icons.audio_file_rounded;
      label = 'common.media_audio'.tr();
    } else if (proof.type.name == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      label = 'common.media_pdf'.tr();
    } else {
      icon = Icons.photo_rounded;
      label = 'common.media_photo'.tr();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32, color: color),
        AppSpacing.vGapSm,
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Info card wrapper
class _InfoCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _InfoCard({this.title, required this.child});

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
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            AppSpacing.vGapMd,
          ],
          child,
        ],
      ),
    );
  }
}

/// Summary row widget
class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.textTertiary),
        AppSpacing.gapMd,
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (badge != null) ...[
          AppSpacing.gapSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.primary.withAlpha(26),
              borderRadius: AppRadius.badgeRadius,
            ),
            child: Text(
              badge!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
