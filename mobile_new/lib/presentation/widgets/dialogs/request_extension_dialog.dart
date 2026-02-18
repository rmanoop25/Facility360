import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/assignment_model.dart';
import '../../providers/time_extension_provider.dart';

/// Dialog for service providers to request time extension
class RequestExtensionDialog extends ConsumerStatefulWidget {
  final AssignmentModel assignment;

  const RequestExtensionDialog({
    super.key,
    required this.assignment,
  });

  @override
  ConsumerState<RequestExtensionDialog> createState() =>
      _RequestExtensionDialogState();
}

class _RequestExtensionDialogState
    extends ConsumerState<RequestExtensionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  int _selectedMinutes = 30;
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result =
        await ref.read(timeExtensionActionsProvider.notifier).requestExtension(
              assignmentId: widget.assignment.id,
              requestedMinutes: _selectedMinutes,
              reason: _reasonController.text.trim(),
            );

    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('extensions.success.requested'.tr()),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        final error = ref.read(timeExtensionActionsProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'extensions.errors.request_failed'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(timeExtensionActionsProvider).isLoading;

    return AlertDialog(
      title: Text('extensions.request_extension'.tr()),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration selection chips
              Text(
                'extensions.select_duration'.tr(),
                style: context.textTheme.labelLarge,
              ),
              AppSpacing.vGapSm,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions.map((minutes) {
                  return ChoiceChip(
                    label: Text('$minutes ${'common.min'.tr()}'),
                    selected: _selectedMinutes == minutes,
                    onSelected: (selected) {
                      setState(() => _selectedMinutes = minutes);
                    },
                  );
                }).toList(),
              ),

              AppSpacing.vGapMd,

              // Reason text field
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'extensions.reason'.tr(),
                  hintText: 'extensions.reason_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'extensions.errors.reason_required'.tr();
                  }
                  if (value.trim().length < 20) {
                    return 'extensions.errors.reason_too_short'.tr();
                  }
                  return null;
                },
              ),

              AppSpacing.vGapSm,

              // Current overtime info
              if ((widget.assignment.overtimeMinutes ?? 0) > 0) ...[
                Container(
                  padding: AppSpacing.allMd,
                  decoration: BoxDecoration(
                    color: context.colors.error.withAlpha(26),
                    borderRadius: AppRadius.inputRadius,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 20, color: context.colors.error),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Text(
                          'extensions.current_overtime'.tr(
                            namedArgs: {
                              'minutes':
                                  widget.assignment.overtimeMinutes.toString(),
                            },
                          ),
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.submit'.tr()),
        ),
      ],
    );
  }
}
