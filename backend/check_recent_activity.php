<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== Recent Activity Check ===" . PHP_EOL . PHP_EOL;

// Check recent issues
$recentIssues = \App\Models\Issue::with('tenant.user', 'assignments.serviceProvider.user')
    ->orderBy('updated_at', 'desc')
    ->limit(3)
    ->get();

echo "Recent issues:" . PHP_EOL;
foreach ($recentIssues as $issue) {
    echo "  Issue #{$issue->id}: {$issue->title}" . PHP_EOL;
    echo "    Status: {$issue->status->label()}" . PHP_EOL;
    echo "    Tenant: {$issue->tenant->user->name}" . PHP_EOL;
    echo "    Updated: {$issue->updated_at}" . PHP_EOL;

    if ($issue->assignments->isNotEmpty()) {
        foreach ($issue->assignments as $assignment) {
            echo "    Assignment to: {$assignment->serviceProvider->user->name}" . PHP_EOL;
            echo "      Status: {$assignment->status->label()}" . PHP_EOL;
            echo "      Updated: {$assignment->updated_at}" . PHP_EOL;
        }
    }
    echo PHP_EOL;
}

// Check notifications created in the last hour
$recentNotifications = DB::table('notifications')
    ->where('created_at', '>=', now()->subHour())
    ->orderBy('created_at', 'desc')
    ->get();

echo "Notifications created in last hour: " . $recentNotifications->count() . PHP_EOL;
foreach ($recentNotifications as $notification) {
    $data = json_decode($notification->data, true);
    $type = class_basename($notification->type);
    $user = \App\Models\User::find($notification->notifiable_id);
    echo "  - {$type} to {$user->name} at {$notification->created_at}" . PHP_EOL;
    echo "    Title: " . ($data['title'] ?? 'N/A') . PHP_EOL;
    echo "    Read: " . ($notification->read_at ? 'Yes' : 'No') . PHP_EOL;
}
