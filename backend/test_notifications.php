<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== Notification System Test ===" . PHP_EOL . PHP_EOL;

// Find Khalid and an issue to test with
$khalid = \App\Models\User::where('email', 'plumber@maintenance.local')->first();
$issue = \App\Models\Issue::where('status', \App\Enums\IssueStatus::PENDING)->first();

if (!$khalid) {
    echo "ERROR: Khalid user not found" . PHP_EOL;
    exit(1);
}

if (!$issue) {
    echo "ERROR: No pending issue found" . PHP_EOL;
    exit(1);
}

echo "Test Setup:" . PHP_EOL;
echo "  - Khalid: {$khalid->name} (ID: {$khalid->id})" . PHP_EOL;
echo "  - Service Provider ID: {$khalid->serviceProvider->id}" . PHP_EOL;
echo "  - Issue: #{$issue->id} - {$issue->title}" . PHP_EOL;
echo "  - Khalid has FCM token: " . ($khalid->fcm_token ? 'YES' : 'NO') . PHP_EOL;
echo PHP_EOL;

// Test 1: Check if notification class works
echo "Test 1: Creating test notification..." . PHP_EOL;
try {
    $notification = new \App\Notifications\IssueNotification(
        $issue,
        \App\Enums\NotificationType::ISSUE_ASSIGNED
    );

    echo "  ✓ IssueNotification created successfully" . PHP_EOL;

    // Get notification data
    $data = $notification->toDatabase($khalid);
    echo "  ✓ Notification data generated:" . PHP_EOL;
    echo "    - Has 'format' key: " . (isset($data['format']) ? 'YES' : 'NO') . PHP_EOL;
    echo "    - Format value: " . ($data['format'] ?? 'N/A') . PHP_EOL;
    echo "    - Has 'title': " . (isset($data['title']) ? 'YES' : 'NO') . PHP_EOL;
    echo "    - Has 'body': " . (isset($data['body']) ? 'YES' : 'NO') . PHP_EOL;
    echo "    - Issue ID: " . ($data['issue_id'] ?? 'N/A') . PHP_EOL;
    echo "    - Type: " . ($data['type'] ?? 'N/A') . PHP_EOL;
} catch (\Exception $e) {
    echo "  ✗ Failed to create notification: " . $e->getMessage() . PHP_EOL;
    echo "    Stack trace:" . PHP_EOL;
    echo $e->getTraceAsString() . PHP_EOL;
}
echo PHP_EOL;

// Test 2: Send notification to Khalid
echo "Test 2: Sending notification to Khalid..." . PHP_EOL;
try {
    $khalid->notify(new \App\Notifications\IssueNotification(
        $issue,
        \App\Enums\NotificationType::ISSUE_ASSIGNED
    ));

    echo "  ✓ Notification sent successfully" . PHP_EOL;

    // Check if it was created
    $notificationCount = DB::table('notifications')
        ->where('notifiable_id', $khalid->id)
        ->where('notifiable_type', 'App\Models\User')
        ->count();

    echo "  ✓ Total notifications for Khalid: {$notificationCount}" . PHP_EOL;

    // Get the latest notification
    $latest = DB::table('notifications')
        ->where('notifiable_id', $khalid->id)
        ->orderBy('created_at', 'desc')
        ->first();

    if ($latest) {
        echo "  ✓ Latest notification:" . PHP_EOL;
        echo "    - ID: {$latest->id}" . PHP_EOL;
        echo "    - Created: {$latest->created_at}" . PHP_EOL;
        echo "    - Read: " . ($latest->read_at ? 'YES' : 'NO') . PHP_EOL;

        $data = json_decode($latest->data, true);
        echo "    - Title: " . ($data['title'] ?? 'N/A') . PHP_EOL;
        echo "    - Format: " . ($data['format'] ?? 'N/A') . PHP_EOL;
    }
} catch (\Exception $e) {
    echo "  ✗ Failed to send notification: " . $e->getMessage() . PHP_EOL;
    echo "    Stack trace:" . PHP_EOL;
    echo $e->getTraceAsString() . PHP_EOL;
}
echo PHP_EOL;

// Test 3: Check admin users
echo "Test 3: Checking admin users..." . PHP_EOL;
$adminUsers = \App\Models\User::role(['super_admin', 'manager'])->get();
echo "  - Found {$adminUsers->count()} admin users" . PHP_EOL;
foreach ($adminUsers as $admin) {
    echo "    - {$admin->name} (ID: {$admin->id}, Role: " . $admin->roles->first()->name . ")" . PHP_EOL;
}
echo PHP_EOL;

// Test 4: Send notifications to all admins
echo "Test 4: Sending notifications to all admins..." . PHP_EOL;
$successCount = 0;
$failCount = 0;
foreach ($adminUsers as $admin) {
    try {
        $admin->notify(new \App\Notifications\IssueNotification(
            $issue,
            \App\Enums\NotificationType::ISSUE_ASSIGNED
        ));
        $successCount++;
        echo "  ✓ Sent to {$admin->name}" . PHP_EOL;
    } catch (\Exception $e) {
        $failCount++;
        echo "  ✗ Failed to send to {$admin->name}: " . $e->getMessage() . PHP_EOL;
    }
}
echo "  Summary: {$successCount} success, {$failCount} failed" . PHP_EOL;
echo PHP_EOL;

// Test 5: Check total notifications
echo "Test 5: Total notifications in database..." . PHP_EOL;
$totalNotifications = DB::table('notifications')->count();
echo "  - Total: {$totalNotifications}" . PHP_EOL;

$recentNotifications = DB::table('notifications')
    ->orderBy('created_at', 'desc')
    ->limit(5)
    ->get();

echo "  - Recent notifications:" . PHP_EOL;
foreach ($recentNotifications as $n) {
    $user = \App\Models\User::find($n->notifiable_id);
    $data = json_decode($n->data, true);
    $status = $n->read_at ? 'read' : 'unread';
    echo "    - To: {$user->name} | Title: " . ($data['title'] ?? 'N/A') . " | Status: {$status}" . PHP_EOL;
}
echo PHP_EOL;

echo "=== Test Complete ===" . PHP_EOL;
