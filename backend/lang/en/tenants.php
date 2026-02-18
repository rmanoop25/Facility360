<?php

return [
    'singular' => 'Tenant',
    'plural' => 'Tenants',

    'sections' => [
        'profile_photo' => 'Profile Photo',
        'personal_info' => 'Personal Information',
        'address' => 'Address Information',
        'status' => 'Status',
    ],

    'fields' => [
        'profile_photo' => 'Profile Photo',
        'name' => 'Name',
        'email' => 'Email',
        'password' => 'Password',
        'phone' => 'Phone',
        'unit_number' => 'Unit Number',
        'building_name' => 'Building Name',
        'is_active' => 'Active',
        'issues_count' => 'Issues',
        'new_password' => 'New Password',
        'confirm_password' => 'Confirm Password',
    ],

    'filters' => [
        'active' => 'Active Status',
        'has_issues' => 'Has Issues',
    ],

    'actions' => [
        'reset_password' => 'Reset Password',
        'reset_password_confirmation' => 'Enter the new password for this tenant.',
        'activate' => 'Activate',
        'deactivate' => 'Deactivate',
    ],
];
