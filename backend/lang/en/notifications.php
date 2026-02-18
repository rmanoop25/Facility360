<?php

return [
    'title' => 'Notifications',
    'singular' => 'Notification',
    'plural' => 'Notifications',
    'unread' => 'unread',
    'mark_all_read' => 'Mark All as Read',
    'mark_read' => 'Mark as Read',
    'delete' => 'Delete',
    'delete_all' => 'Delete All',
    'confirm_delete' => 'Are you sure you want to delete this notification?',
    'confirm_delete_all' => 'Are you sure you want to delete all notifications?',
    'all_marked_read' => 'All notifications marked as read',
    'all_deleted' => 'All notifications deleted',
    'deleted' => 'Notification deleted',
    'no_notifications' => 'No notifications yet',
    'view_issue' => 'View Issue',
    'unread_description' => 'Notifications awaiting your attention',
    'today_description' => 'Received today',

    'channels' => [
        'fcm' => 'Firebase Cloud Messaging',
        'database' => 'Database',
    ],

    'types' => [
        'issue_created' => 'New Issue Created',
        'issue_assigned' => 'Issue Assigned',
        'work_started' => 'Work Started',
        'work_finished' => 'Work Finished',
        'assignment_approved' => 'Assignment Approved',
        'partial_progress' => 'Progress Update',
        'issue_completed' => 'Issue Completed',
        'issue_cancelled' => 'Issue Cancelled',
    ],

    'messages' => [
        'issue_created' => [
            'title' => 'New Issue',
            'body' => 'A new issue has been reported: :title',
        ],
        'issue_assigned' => [
            'title' => 'Issue Assigned',
            'body' => 'You have been assigned to: :title',
        ],
        'work_started' => [
            'title' => 'Work Started',
            'body' => 'Work has started on: :title',
        ],
        'work_on_hold' => [
            'title' => 'Work On Hold',
            'body' => 'Work has been put on hold for: :title',
        ],
        'work_resumed' => [
            'title' => 'Work Resumed',
            'body' => 'Work has resumed on: :title',
        ],
        'work_finished' => [
            'title' => 'Work Finished',
            'body' => 'Work has been completed on: :title. Please review and approve.',
        ],
        'assignment_approved' => [
            'title' => 'Assignment Approved',
            'body' => 'Your work on :title has been approved.',
        ],
        'partial_progress' => [
            'title' => 'Progress Update',
            'body' => ':completed of :total tasks completed for: :title',
        ],
        'issue_completed' => [
            'title' => 'Issue Completed',
            'body' => 'Your issue has been resolved: :title',
        ],
        'issue_cancelled' => [
            'title' => 'Issue Cancelled',
            'body' => 'Issue has been cancelled: :title',
        ],
        'general' => [
            'title' => 'Notification',
            'body' => ':message',
        ],
    ],
];
