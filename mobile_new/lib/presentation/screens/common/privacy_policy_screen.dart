import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/extensions/context_extensions.dart';

/// Privacy Policy Screen
/// Displays the privacy policy for the Facility360 app
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('legal.privacy.title'.tr()),
        backgroundColor: context.colors.background,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'legal.privacy.title'.tr(),
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              'legal.privacy.last_updated'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            AppSpacing.vGapXl,
            _buildSection(
              context,
              'legal.privacy.intro_title'.tr(),
              'legal.privacy.intro_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.collect_title'.tr(),
              'legal.privacy.collect_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.use_title'.tr(),
              'legal.privacy.use_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.sharing_title'.tr(),
              'legal.privacy.sharing_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.security_title'.tr(),
              'legal.privacy.security_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.rights_title'.tr(),
              'legal.privacy.rights_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.location_title'.tr(),
              'legal.privacy.location_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.retention_title'.tr(),
              'legal.privacy.retention_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.children_title'.tr(),
              'legal.privacy.children_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.changes_title'.tr(),
              'legal.privacy.changes_content'.tr(),
            ),
            AppSpacing.vGapLg,
            _buildSection(
              context,
              'legal.privacy.contact_title'.tr(),
              'legal.privacy.contact_content'.tr(),
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
