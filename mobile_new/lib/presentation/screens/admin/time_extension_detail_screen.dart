import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/time_extension_request_model.dart';
import '../../providers/time_extension_provider.dart';

/// Admin screen for viewing and managing a single extension request
class TimeExtensionDetailScreen extends ConsumerStatefulWidget {
  final int extensionId;

  const TimeExtensionDetailScreen({
    super.key,
    required this.extensionId,
  });

  @override
  ConsumerState<TimeExtensionDetailScreen> createState() =>
      _TimeExtensionDetailScreenState();
}

class _TimeExtensionDetailScreenState
    extends ConsumerState<TimeExtensionDetailScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _approve(TimeExtensionRequestModel extension) async {
    final success =
        await ref.read(timeExtensionActionsProvider.notifier).approveExtension(
              widget.extensionId,
              adminNotes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('extensions.success.approved'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(timeExtensionActionsProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'extensions.errors.approve_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _reject(TimeExtensionRequestModel extension) async {
    if (_notesController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('extensions.errors.rejection_reason_required'.tr()),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    final success =
        await ref.read(timeExtensionActionsProvider.notifier).rejectExtension(
              widget.extensionId,
              adminNotes: _notesController.text.trim(),
            );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('extensions.success.rejected'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      } else {
        final error = ref.read(timeExtensionActionsProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'extensions.errors.reject_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fetch extension from the list provider
    final extensionsAsync = ref.watch(adminExtensionRequestsProvider(null));

    return extensionsAsync.when(
      data: (extensions) {
        final extension = extensions.cast<TimeExtensionRequestModel?>().firstWhere(
          (e) => e?.id == widget.extensionId,
          orElse: () => null,
        );

        if (extension == null) {
          return Scaffold(
            appBar: AppBar(title: Text('extensions.request_detail'.tr())),
            body: Center(
              child: Text('extensions.not_found'.tr()),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('extensions.request_detail'.tr()),
          ),
          body: SingleChildScrollView(
            padding: AppSpacing.allLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: extension.status.color.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(extension.status.icon,
                            color: extension.status.color),
                        AppSpacing.gapSm,
                        Text(
                          extension.status.label,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: extension.status.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                AppSpacing.vGapXl,

                // Request details
                _DetailCard(
                  title: 'extensions.request_info'.tr(),
                  children: [
                    _DetailRow(
                      label: 'extensions.requested_minutes'.tr(),
                      value: '+${extension.requestedMinutes} min',
                    ),
                    _DetailRow(
                      label: 'extensions.requested_by'.tr(),
                      value: extension.requesterName ?? 'Unknown',
                    ),
                    _DetailRow(
                      label: 'extensions.requested_at'.tr(),
                      value: DateFormat('MMM d, yyyy h:mm a')
                          .format(extension.requestedAt),
                    ),
                  ],
                ),

                AppSpacing.vGapLg,

                // Reason
                _DetailCard(
                  title: 'extensions.reason'.tr(),
                  children: [
                    Text(
                      extension.reason,
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),

                // Response details (if approved/rejected)
                if (!extension.isPending) ...[
                  AppSpacing.vGapLg,
                  _DetailCard(
                    title: 'extensions.admin_response'.tr(),
                    children: [
                      if (extension.respondedBy != null)
                        _DetailRow(
                          label: 'extensions.responded_by'.tr(),
                          value: extension.responderName ?? 'Unknown',
                        ),
                      if (extension.respondedAt != null)
                        _DetailRow(
                          label: 'extensions.responded_at'.tr(),
                          value: DateFormat('MMM d, yyyy h:mm a')
                              .format(extension.respondedAt!),
                        ),
                      if (extension.adminNotes != null &&
                          extension.adminNotes!.isNotEmpty) ...[
                        AppSpacing.vGapSm,
                        Text(
                          extension.adminNotes!,
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ],

                // Admin notes input (if pending)
                if (extension.isPending) ...[
                  AppSpacing.vGapLg,
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'extensions.admin_notes'.tr(),
                      hintText: 'extensions.notes_optional'.tr(),
                      helperText: 'extensions.rejection_reason_required'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    maxLength: 500,
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: extension.isPending
              ? SafeArea(
                  child: Padding(
                    padding: AppSpacing.allLg,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reject(extension),
                            icon: const Icon(Icons.close_rounded),
                            label: Text('extensions.reject'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.error,
                              side: BorderSide(color: context.colors.error),
                            ),
                          ),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _approve(extension),
                            icon: const Icon(Icons.check_rounded),
                            label: Text('extensions.approve'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('common.error'.tr())),
        body: Center(child: Text(error.toString())),
      ),
    );
  }
}

/// Detail card widget
class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.vGapMd,
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
