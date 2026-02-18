<?php

ini_set('memory_limit', '1G');
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$user = App\Models\User::find(2);
auth()->login($user);

echo 'User: '.$user->email.PHP_EOL;
echo 'Memory before permissions: '.(memory_get_usage(true) / 1024 / 1024).' MB'.PHP_EOL;

// Check permissions
$permissions = $user->getAllPermissions();
echo 'Permissions count: '.$permissions->count().PHP_EOL;
echo 'Memory after permissions: '.(memory_get_usage(true) / 1024 / 1024).' MB'.PHP_EOL;

// Check if user can access panel
$panel = filament()->getPanel('admin');
echo 'Can access panel: '.($user->canAccessPanel($panel) ? 'Yes' : 'No').PHP_EOL;
echo 'Memory after panel check: '.(memory_get_usage(true) / 1024 / 1024).' MB'.PHP_EOL;

// Try to get navigation items
try {
    $items = filament()->getNavigation();
    echo 'Navigation items: '.count($items).PHP_EOL;
} catch (Exception $e) {
    echo 'Error getting navigation: '.$e->getMessage().PHP_EOL;
}
echo 'Memory after navigation: '.(memory_get_usage(true) / 1024 / 1024).' MB'.PHP_EOL;
