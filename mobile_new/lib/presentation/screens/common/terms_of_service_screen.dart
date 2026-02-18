import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';

/// Terms of Service Screen
/// Displays the terms of service for the Facility360 app
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('legal.terms.title'.tr()),
        backgroundColor: context.colors.background,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'legal.terms.title'.tr(),
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              'legal.terms.last_updated'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            AppSpacing.vGapXl,
            _buildSection(
              context,
              'legal.terms.agreement_title'.tr(),
              'legal.terms.agreement_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.description_title'.tr(),
              'legal.terms.description_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.accounts_title'.tr(),
              'legal.terms.accounts_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.use_title'.tr(),
              'legal.terms.use_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.reporting_title'.tr(),
              'legal.terms.reporting_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.sp_title'.tr(),
              'legal.terms.sp_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.ownership_title'.tr(),
              'legal.terms.ownership_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.ip_title'.tr(),
              'legal.terms.ip_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.liability_title'.tr(),
              'legal.terms.liability_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.availability_title'.tr(),
              'legal.terms.availability_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.emergency_title'.tr(),
              'legal.terms.emergency_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.termination_title'.tr(),
              'legal.terms.termination_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.dispute_title'.tr(),
              'legal.terms.dispute_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.changes_title'.tr(),
              'legal.terms.changes_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.indemnification_title'.tr(),
              'legal.terms.indemnification_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.severability_title'.tr(),
              'legal.terms.severability_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.terms.contact_title'.tr(),
              'legal.terms.contact_content'.tr(),
            ),
            AppSpacing.vGapXxl,
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.vGapSm,
        Text(
          content,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
