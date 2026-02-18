<?php

return [
    'singular' => 'Time Slot',
    'plural' => 'Time Slots',

    'sections' => [
        'quick_setup' => 'Quick Setup',
        'quick_setup_description' => 'Select days and apply the same working hours to all of them at once.',
        'weekly_schedule' => 'Weekly Schedule',
        'weekly_schedule_description' => 'View and edit individual day schedules below.',
    ],

    'fields' => [
        'day_of_week' => 'Day',
        'start_time' => 'Start Time',
        'end_time' => 'End Time',
        'time_range' => 'Time Range',
        'is_active' => 'Active',
        'is_full_day' => 'Full Day',
        'select_days' => 'Select Days',
    ],

    'filters' => [
        'day' => 'Day',
        'active' => 'Active Status',
    ],

    'presets' => [
        'weekdays' => 'Weekdays',
        'weekend' => 'Weekend',
        'all_week' => 'All Week',
    ],

    'actions' => [
        'activate' => 'Activate',
        'deactivate' => 'Deactivate',
        'add_slot' => 'Add Time Slot',
        'new_slot' => 'New Time Slot',
        'apply_to_selected' => 'Apply to Selected Days',
        'clear_all' => 'Clear All',
    ],

    'messages' => [
        'no_days_selected' => 'Please select at least one day.',
        'applied_successfully' => 'Time slots applied successfully.',
        'select_time_first' => 'Please set start and end times first.',
        'cleared_successfully' => 'All time slots cleared.',
    ],

    'status' => [
        'configured' => 'Configured',
        'not_configured' => 'Not configured',
    ],
];
