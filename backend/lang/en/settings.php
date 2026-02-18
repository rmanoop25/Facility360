<?php

return [
    'issue' => [
        'navigation_label' => 'Issue Settings',
        'title' => 'Issue Settings',
        'subheading' => 'Configure how issues are processed and approved',

        'sections' => [
            'approval' => 'Approval Settings',
            'approval_description' => 'Control whether finished work requires manual admin approval or is automatically approved',
        ],

        'fields' => [
            'auto_approve_finished_issues' => 'Auto-approve finished issues',
            'auto_approve_finished_issues_helper' => 'When enabled, issues will be automatically marked as completed when service providers finish their work, skipping the manual approval step. When disabled, admins must manually approve completed work.',
        ],

        'messages' => [
            'saved' => 'Settings saved successfully',
        ],
    ],
];
