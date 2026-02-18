<?php

return [
    // General
    'tenant_only' => 'This action is only available for tenants.',
    'service_provider_only' => 'This action is only available for service providers.',

    // Issues
    'issues' => [
        'list_success' => 'Issues retrieved successfully.',
        'show_success' => 'Issue details retrieved successfully.',
        'created_success' => 'Issue created successfully.',
        'admin_created_success' => 'Issue created successfully on behalf of tenant.',
        'created_by_admin' => 'Created by :admin on behalf of tenant.',
        'create_failed' => 'Failed to create issue.',
        'cancelled_success' => 'Issue cancelled successfully.',
        'cancel_failed' => 'Failed to cancel issue.',
        'cannot_cancel' => 'This issue cannot be cancelled.',
        'not_found' => 'Issue not found.',
    ],

    // Assignments
    'assignments' => [
        'list_success' => 'Assignments retrieved successfully.',
        'show_success' => 'Assignment details retrieved successfully.',
        'not_found' => 'Assignment not found.',
        'cannot_start' => 'This assignment cannot be started.',
        'started_success' => 'Work started successfully.',
        'start_failed' => 'Failed to start work.',
        'cannot_hold' => 'This assignment cannot be put on hold.',
        'held_success' => 'Assignment put on hold successfully.',
        'hold_failed' => 'Failed to put assignment on hold.',
        'cannot_resume' => 'This assignment cannot be resumed.',
        'resumed_success' => 'Work resumed successfully.',
        'resume_failed' => 'Failed to resume work.',
        'cannot_finish' => 'This assignment cannot be finished.',
        'finished_success' => 'Work completed successfully.',
        'finish_failed' => 'Failed to complete work.',
        'proof_required' => 'Proof of completion is required.',
    ],

    // Categories
    'categories' => [
        'list_success' => 'Categories retrieved successfully.',
        'show_success' => 'Category details retrieved successfully.',
        'created_success' => 'Category created successfully.',
        'create_failed' => 'Failed to create category.',
        'updated_success' => 'Category updated successfully.',
        'update_failed' => 'Failed to update category.',
        'deleted_success' => 'Category deleted successfully.',
        'delete_failed' => 'Failed to delete category.',
        'not_found' => 'Category not found.',
        'in_use' => 'Cannot delete category that is in use.',
    ],

    // Consumables
    'consumables' => [
        'list_success' => 'Consumables retrieved successfully.',
        'show_success' => 'Consumable details retrieved successfully.',
        'created_success' => 'Consumable created successfully.',
        'create_failed' => 'Failed to create consumable.',
        'updated_success' => 'Consumable updated successfully.',
        'update_failed' => 'Failed to update consumable.',
        'deleted_success' => 'Consumable deleted successfully.',
        'delete_failed' => 'Failed to delete consumable.',
        'not_found' => 'Consumable not found.',
    ],

    // Tenants
    'tenants' => [
        'list_success' => 'Tenants retrieved successfully.',
        'show_success' => 'Tenant details retrieved successfully.',
        'created_success' => 'Tenant created successfully.',
        'create_failed' => 'Failed to create tenant.',
        'updated_success' => 'Tenant updated successfully.',
        'update_failed' => 'Failed to update tenant.',
        'deleted_success' => 'Tenant deleted successfully.',
        'delete_failed' => 'Failed to delete tenant.',
        'not_found' => 'Tenant not found.',
    ],

    // Service Providers
    'service_providers' => [
        'list_success' => 'Service providers retrieved successfully.',
        'show_success' => 'Service provider details retrieved successfully.',
        'created_success' => 'Service provider created successfully.',
        'create_failed' => 'Failed to create service provider.',
        'updated_success' => 'Service provider updated successfully.',
        'update_failed' => 'Failed to update service provider.',
        'deleted_success' => 'Service provider deleted successfully.',
        'delete_failed' => 'Failed to delete service provider.',
        'not_found' => 'Service provider not found.',
        'availability_success' => 'Availability retrieved successfully.',
    ],

    // Devices (FCM)
    'devices' => [
        'registered' => 'Device registered successfully.',
        'removed' => 'Device unregistered successfully.',
        'token_not_found' => 'Device token not found.',
    ],

    // Sync
    'sync' => [
        'master_data_success' => 'Master data retrieved successfully.',
        'batch_success' => 'Batch sync completed successfully.',
    ],

    // Dashboard
    'dashboard' => [
        'stats_success' => 'Dashboard statistics retrieved successfully.',
    ],

    // Profile
    'profile' => [
        'show_success' => 'Profile retrieved successfully.',
        'updated' => 'Profile updated successfully.',
        'locale_updated' => 'Language preference updated successfully.',
        'photo_uploaded' => 'Profile photo uploaded successfully.',
        'photo_deleted' => 'Profile photo deleted successfully.',
        'no_photo' => 'No profile photo to delete.',
    ],
];
