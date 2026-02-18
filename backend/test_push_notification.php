<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== Testing Push Notification to Khalid ===" . PHP_EOL . PHP_EOL;

// Get Khalid
$khalid = \App\Models\User::where('email', 'plumber@maintenance.local')->first();

if (!$khalid) {
    echo "ERROR: Khalid not found" . PHP_EOL;
    exit(1);
}

echo "Target User:" . PHP_EOL;
echo "  - Name: {$khalid->name}" . PHP_EOL;
echo "  - Email: {$khalid->email}" . PHP_EOL;
echo "  - Has FCM Token: " . ($khalid->fcm_token ? 'YES' : 'NO') . PHP_EOL;

if (!$khalid->fcm_token) {
    echo "  ERROR: No FCM token registered" . PHP_EOL;
    exit(1);
}

$tokenPreview = substr($khalid->fcm_token, 0, 40) . '...';
echo "  - Token: {$tokenPreview}" . PHP_EOL;
echo PHP_EOL;

// Get a test issue
$issue = \App\Models\Issue::first();
if (!$issue) {
    echo "ERROR: No issues found" . PHP_EOL;
    exit(1);
}

echo "Test Issue:" . PHP_EOL;
echo "  - ID: {$issue->id}" . PHP_EOL;
echo "  - Title: {$issue->title}" . PHP_EOL;
echo PHP_EOL;

// Send FCM notification using the action
echo "Sending push notification..." . PHP_EOL;

try {
    $fcmAction = app(\App\Actions\Notification\SendFcmNotificationAction::class);

    $result = $fcmAction->toUser(
        $khalid,
        \App\Enums\NotificationType::ISSUE_ASSIGNED,
        [
            'title' => $issue->title,
            'issue_id' => (string) $issue->id,
        ]
    );

    echo "✓ Notification sent successfully!" . PHP_EOL;
    echo PHP_EOL;
    echo "CHECK YOUR PHONE NOW! 📱" . PHP_EOL;
    echo "You should see a push notification on Khalid's device." . PHP_EOL;

} catch (\Exception $e) {
    echo "✗ Failed to send notification" . PHP_EOL;
    echo "Error: " . $e->getMessage() . PHP_EOL;
    echo PHP_EOL;
    echo "Stack trace:" . PHP_EOL;
    echo $e->getTraceAsString() . PHP_EOL;
}
