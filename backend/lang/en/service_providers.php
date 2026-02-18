<?php

return [
    'singular' => 'Service Provider',
    'plural' => 'Service Providers',

    'sections' => [
        'personal_info' => 'Personal Information',
        'work_info' => 'Work Information',
        'time_slots' => 'Working Hours',
        'time_slots_description' => 'Define when this service provider is available for work assignments.',
        'location' => 'Location',
        'status' => 'Status',
    ],

    'fields' => [
        'name' => 'Name',
        'email' => 'Email',
        'password' => 'Password',
        'phone' => 'Phone',
        'profile_photo' => 'Profile Photo',
        'categories' => 'Categories',
        'is_available' => 'Available',
        'is_active' => 'Active',
        'latitude' => 'Latitude',
        'longitude' => 'Longitude',
        'assignments_count' => 'Assignments',
        'new_password' => 'New Password',
        'confirm_password' => 'Confirm Password',
    ],

    'filters' => [
        'category' => 'Category',
        'available' => 'Availability',
        'active' => 'Active Status',
    ],

    'actions' => [
        'reset_password' => 'Reset Password',
        'reset_password_confirmation' => 'Enter the new password for this service provider.',
        'mark_available' => 'Mark as Available',
        'mark_unavailable' => 'Mark as Unavailable',
        'delete_with_assignments' => 'This service provider has :count assignment(s). Deleting will remove the service provider link from these assignments. Are you sure you want to proceed?',
        'bulk_delete_warning' => 'This will delete the selected service providers. Any assignments linked to them will have their service provider reference removed.',
    ],
];
