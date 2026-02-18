<?php

return [
    'title' => 'Categories',
    'singular' => 'Category',
    'plural' => 'Categories',

    'sections' => [
        'basic_info' => 'Basic Information',
    ],

    'fields' => [
        'name' => 'Name',
        'name_en' => 'Name (English)',
        'name_ar' => 'Name (Arabic)',
        'icon' => 'Icon',
        'icon_help' => 'Enter a Heroicon name (e.g., heroicon-o-wrench)',
        'is_active' => 'Active',
        'is_active_help' => 'Deactivating will also deactivate all child categories',
        'sort_order' => 'Sort Order',
        'consumables_count' => 'Consumables',
        'service_providers_count' => 'Service Providers',
        'created_at' => 'Created At',
        'updated_at' => 'Updated At',
        // Hierarchy fields
        'parent' => 'Parent Category',
        'no_parent' => 'None (Root Category)',
        'parent_help' => 'Select a parent to create a subcategory',
        'depth' => 'Level',
        'full_path' => 'Full Path',
        'children_count' => 'Children',
    ],

    'filters' => [
        'active' => 'Active Status',
        'has_consumables' => 'Has Consumables',
        'has_service_providers' => 'Has Service Providers',
        'has_children' => 'Has Children',
        'roots_only' => 'Root Categories Only',
        'depth' => 'Depth Level',
        'parent' => 'Parent Category',
    ],

    'depth_options' => [
        'root' => 'Root (Level 0)',
        'level_1' => 'Level 1',
        'level_2' => 'Level 2',
        'level_3_plus' => 'Level 3+',
    ],

    'depth_level' => 'Level :level',
    'level' => 'L:level',

    'actions' => [
        'activate' => 'Activate',
        'deactivate' => 'Deactivate',
        'archive' => 'Archive',
        'restore' => 'Restore',
        'view_children' => 'View Children',
    ],

    'messages' => [
        'created' => 'Category created successfully',
        'updated' => 'Category updated successfully',
        'deleted' => 'Category deleted successfully',
    ],

    // Archive/Restore messages
    'archive_heading' => 'Archive Category',
    'archive_warning' => 'This category will be archived and hidden from users.',
    'archive_warning_with_children' => 'This will archive this category and :count child categories.',
    'archived_successfully' => 'Category archived successfully',
    'restored_successfully' => 'Category restored successfully',
    'not_archived' => 'This category is not archived',
    'bulk_archive_warning' => 'Selected categories and their children will be archived.',
    'bulk_deactivate_warning' => 'Selected categories and their children will be deactivated.',

    // Deactivation messages
    'deactivate_warning_with_children' => 'This will also deactivate :count child categories.',

    // Validation messages
    'cannot_be_own_parent' => 'A category cannot be its own parent.',
    'cannot_move_to_descendant' => 'Cannot move a category to one of its descendants.',

    // API messages
    'created_successfully' => 'Category created successfully',
    'updated_successfully' => 'Category updated successfully',
    'archived_successfully' => 'Category archived successfully',
    'restored_successfully' => 'Category restored successfully',
    'moved_successfully' => 'Category moved successfully',
    'not_found' => 'Category not found',
    'has_consumables' => 'Cannot archive category with :count consumables',
    'has_service_providers' => 'Cannot archive category with :count service providers',
    'has_issues' => 'Cannot archive category with :count issues',
];
