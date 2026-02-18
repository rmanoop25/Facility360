<?php

return [
    'singular' => 'Timeline Entry',
    'plural' => 'Timeline',

    'fields' => [
        'action' => 'Action',
        'performed_by' => 'Performed By',
        'notes' => 'Notes',
        'assignment' => 'Assignment',
        'service_provider' => 'Service Provider',
    ],

    'actions' => [
        'created' => 'Created issue',
        'assigned' => 'Assigned to service provider',
        'assignment_updated' => 'Assignment updated',
        'started' => 'Started work',
        'held' => 'Put on hold',
        'resumed' => 'Resumed work',
        'finished' => 'Finished work',
        'approved' => 'Approved completion',
        'cancelled' => 'Cancelled issue',
        'updated' => 'Updated issue',
    ],

    'filters' => [
        'action' => 'Action',
    ],

    'system' => 'System',
];
