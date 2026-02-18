<?php

return [
    'title' => 'Users',
    'singular' => 'User',
    'plural' => 'Users',

    'roles' => [
        'super_admin' => 'Super Admin',
        'manager' => 'Manager',
        'viewer' => 'Viewer',
        'tenant' => 'Tenant',
        'service_provider' => 'Service Provider',
    ],

    'fields' => [
        'name' => 'Name',
        'email' => 'Email',
        'phone' => 'Phone',
        'password' => 'Password',
        'password_confirmation' => 'Confirm Password',
        'role' => 'Role',
        'is_active' => 'Active',
        'locale' => 'Language',
        'fcm_token' => 'FCM Token',
        'created_at' => 'Created At',
    ],

    'messages' => [
        'created' => 'User created successfully',
        'updated' => 'User updated successfully',
        'deleted' => 'User deleted successfully',
        'password_reset' => 'Password reset successfully',
    ],
];
