<?php

return [
    'singular' => 'Assignment',
    'plural' => 'Assignments',

    'sections' => [
        'details' => 'Assignment Details',
        'timestamps' => 'Timestamps',
        'proofs' => 'Proofs',
        'consumables' => 'Consumables Used',
    ],

    'fields' => [
        'service_provider' => 'Service Provider',
        'category' => 'Category',
        'time_slot' => 'Time Slot',
        'time_slots' => 'Time Slots',
        'scheduled_date' => 'Scheduled Date',
        'assigned_start_time' => 'Start Time',
        'assigned_end_time' => 'End Time',
        'assigned_time' => 'Assigned Time',
        'total_duration' => 'Total Duration',
        'status' => 'Status',
        'notes' => 'Notes',
        'started_at' => 'Started At',
        'held_at' => 'Held At',
        'resumed_at' => 'Resumed At',
        'finished_at' => 'Finished At',
        'completed_at' => 'Completed At',
        'quantity' => 'Quantity',
    ],

    'status' => [
        'assigned' => 'Assigned',
        'in_progress' => 'In Progress',
        'on_hold' => 'On Hold',
        'finished' => 'Finished',
        'completed' => 'Completed',
    ],

    'filters' => [
        'status' => 'Status',
    ],

    'not_found' => 'Assignment not found.',
    'cannot_edit_started' => 'Cannot edit assignment after work has started.',
    'updated' => 'Assignment updated successfully.',
    'auto_calculated' => 'Auto-calculated',
];
