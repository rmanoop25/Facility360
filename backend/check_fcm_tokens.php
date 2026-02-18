<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== FCM Token Check ===" . PHP_EOL . PHP_EOL;

// Check users with FCM tokens
$usersWithTokens = \App\Models\User::whereNotNull('fcm_token')->get(['id', 'name', 'email', 'fcm_token']);

echo "Users with FCM tokens: " . $usersWithTokens->count() . PHP_EOL;
foreach ($usersWithTokens as $user) {
    $tokenPreview = substr($user->fcm_token, 0, 30) . '...';
    echo "  - {$user->name} ({$user->email}): {$tokenPreview}" . PHP_EOL;
}

echo PHP_EOL;

// Check recent notifications
$recentNotifications = DB::table('notifications')
    ->orderBy('created_at', 'desc')
    ->limit(5)
    ->get(['id', 'type', 'notifiable_id', 'read_at', 'created_at']);

echo "Recent database notifications: " . $recentNotifications->count() . PHP_EOL;
foreach ($recentNotifications as $notification) {
    $type = class_basename($notification->type);
    $status = $notification->read_at ? 'read' : 'unread';
    echo "  - {$type} for user#{$notification->notifiable_id} ({$status}) at {$notification->created_at}" . PHP_EOL;
}

echo PHP_EOL;

// Check Khalid user
$khalid = \App\Models\User::where('name', 'LIKE', '%khalid%')->first();
if ($khalid) {
    echo "Khalid user found:" . PHP_EOL;
    echo "  - ID: {$khalid->id}" . PHP_EOL;
    echo "  - Email: {$khalid->email}" . PHP_EOL;
    echo "  - FCM Token: " . ($khalid->fcm_token ? 'YES' : 'NO') . PHP_EOL;

    $sp = $khalid->serviceProvider;
    if ($sp) {
        echo "  - Service Provider ID: {$sp->id}" . PHP_EOL;
        echo "  - Category: {$sp->category->name}" . PHP_EOL;
    }
} else {
    echo "Khalid user not found" . PHP_EOL;
}
