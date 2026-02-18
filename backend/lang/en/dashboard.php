<?php

return [
    'title' => 'Dashboard',

    'stats' => [
        'pending_issues' => 'Pending Issues',
        'pending_description' => 'Awaiting assignment',
        'in_progress' => 'In Progress',
        'in_progress_description' => 'Currently being worked on',
        'awaiting_approval' => 'Awaiting Approval',
        'awaiting_approval_description' => 'Work finished, pending approval',
        'completed_today' => 'Completed Today',
        'completed_today_description' => 'Issues resolved today',
    ],

    'widgets' => [
        'pending_issues' => 'Pending Issues',
        'no_pending_issues' => 'No Pending Issues',
        'no_pending_issues_description' => 'All issues have been assigned. Great job!',

        'recent_activity' => 'Recent Activity',
        'no_recent_activity' => 'No Recent Activity',
        'no_recent_activity_description' => 'Activity will appear here when issues are created or updated.',
    ],
];
