<?php

return [
    'singular' => 'Time Extension Request',
    'plural' => 'Time Extension Requests',
    'request_submitted' => 'Time extension request submitted successfully',
    'approved_successfully' => 'Time extension request approved successfully',
    'rejected_successfully' => 'Time extension request rejected successfully',
    'not_found' => 'Time extension request not found',
    'cannot_approve' => 'This extension request cannot be approved',
    'overlap_conflict' => 'Cannot approve: the :minutes-minute extension conflicts with another assignment in that time slot',
    'cannot_reject' => 'This extension request cannot be rejected',
    'not_authorized' => 'You are not authorized to request extension for this assignment',
    'work_not_started' => 'Work must be in progress to request time extension',
    'pending_request_exists' => 'A pending extension request already exists for this assignment',
    'request_failed' => 'Failed to submit extension request',

    'status' => [
        'pending' => 'Pending',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
    ],

    'fields' => [
        'id' => 'ID',
        'issue' => 'Issue',
        'service_provider' => 'Service Provider',
        'requested_time' => 'Requested Time',
        'status' => 'Status',
        'requested_at' => 'Requested At',
        'responded_by' => 'Responded By',
        'responded_at' => 'Responded At',
        'requested_by' => 'Requested By',
        'admin_notes' => 'Admin Notes',
        'rejection_reason' => 'Rejection Reason',
        'reason' => 'Reason',
        'start_time' => 'Start Time',
        'end_time' => 'End Time (after extension)',
        'allocated_duration' => 'Allocated Duration',
        'scheduled_date' => 'Scheduled Date',
    ],

    'filters' => [
        'status' => 'Filter by Status',
    ],

    'actions' => [
        'approve' => 'Approve',
        'reject' => 'Reject',
    ],

    'widget' => [
        'pending' => 'Pending Extensions',
        'pending_description' => 'Time extension requests awaiting approval',
    ],

    'request_info' => 'Request Information',
    'admin_response' => 'Admin Response',
    'slot_impact' => 'Time Slot Impact',
    'reason' => 'Reason',
    'no_requests' => 'No extension requests found',
    'detail_title' => 'Extension Request Details',
    'request_title' => 'Request Time Extension',
    'select_duration' => 'Select Duration',
    'reason_hint' => 'Explain why you need more time',
    'reason_min_length' => 'Reason must be at least 10 characters',
    'submit_request' => 'Submit Request',
    'rejection_reason_required' => 'Rejection reason is required (minimum 10 characters)',
];
