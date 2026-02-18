<?php

return [
    'title' => 'Admin Users',
    'singular' => 'Admin User',
    'plural' => 'Admin Users',

    'sections' => [
        'user_info' => 'User Information',
        'role_status' => 'Role & Status',
    ],

    'fields' => [
        'name' => 'Name',
        'email' => 'Email',
        'password' => 'Password',
        'phone' => 'Phone',
        'role' => 'Role',
        'is_active' => 'Active',
        'created_at' => 'Created At',
        'updated_at' => 'Updated At',
        'new_password' => 'New Password',
        'confirm_password' => 'Confirm Password',
    ],

    'roles' => [
        'super_admin' => 'Super Admin',
        'manager' => 'Manager',
        'viewer' => 'Viewer',
    ],

    'filters' => [
        'role' => 'Role',
        'active' => 'Active Status',
    ],

    'actions' => [
        'reset_password' => 'Reset Password',
        'reset_password_confirmation' => 'Are you sure you want to reset this user\'s password?',
        'toggle_active' => 'Toggle Active',
        'activate' => 'Activate',
        'deactivate' => 'Deactivate',
    ],

    'messages' => [
        'created' => 'Admin user created successfully',
        'updated' => 'Admin user updated successfully',
        'deleted' => 'Admin user deleted successfully',
        'password_reset' => 'Password reset successfully',
        'activated' => 'User activated successfully',
        'deactivated' => 'User deactivated successfully',
        'cannot_delete_self' => 'You cannot delete your own account',
        'cannot_deactivate_self' => 'You cannot deactivate your own account',
    ],
];
