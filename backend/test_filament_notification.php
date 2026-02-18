<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\User;
use App\Models\Issue;
use App\Notifications\IssueNotification;
use App\Enums\NotificationType;

echo "\n";
echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║         TEST: FILAMENT NOTIFICATION FORMAT                ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n\n";

// Clear all existing notifications
DB::table('notifications')->truncate();
echo "✅ Old notifications cleared\n\n";

// Get super admin
$admin = User::where('email', 'admin@maintenance.local')->first();
echo "Super Admin: {$admin->email}\n";

// Get a test issue
$issue = Issue::latest()->first();
if (!$issue) {
    echo "No issues found. Creating test issue...\n";
    $tenant = User::role('tenant')->first();
    $issue = Issue::factory()->create([
        'tenant_id' => $tenant->tenant->id,
        'title' => 'Test Issue for Notification',
    ]);
}
echo "Using Issue: {$issue->title}\n\n";

// Send notification directly (no queue)
echo "Sending notification...\n";
try {
    $notification = new IssueNotification($issue, NotificationType::ISSUE_CREATED);
    $admin->notify($notification);
    echo "✅ Notification sent\n\n";
} catch (\Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}

// Process queue
echo "Processing queue...\n";
Artisan::call('queue:work', [
    '--queue' => 'notifications',
    '--stop-when-empty' => true,
    '--tries' => 1,
]);
echo Artisan::output();

// Check notifications
$notifications = $admin->fresh()->notifications;
echo "═══════════════════════════════════════════════════════════\n";
echo "Total notifications: {$notifications->count()}\n\n";

if ($notifications->count() > 0) {
    foreach ($notifications as $notif) {
        echo "Notification ID: {$notif->id}\n";
        echo "Type: {$notif->type}\n";
        echo "Created: {$notif->created_at}\n";
        echo "Read At: " . ($notif->read_at ?? 'NULL (Unread)') . "\n\n";

        echo "Data structure:\n";
        echo json_encode($notif->data, JSON_PRETTY_PRINT) . "\n\n";

        // Check if it has Filament's expected format
        echo "Has 'format' key (Filament format): " . (isset($notif->data['format']) ? 'YES ✅' : 'NO ❌') . "\n";
        echo "Has 'title' key: " . (isset($notif->data['title']) ? 'YES ✅' : 'NO ❌') . "\n";
        echo "Has 'body' key: " . (isset($notif->data['body']) ? 'YES ✅' : 'NO ❌') . "\n";
    }
} else {
    echo "❌ No notifications found after processing queue\n";
}

echo "\n═══════════════════════════════════════════════════════════\n";
echo "Next step: Login to admin panel and check topbar bell icon\n";
echo "URL: http://localhost:8000/admin\n";
echo "═══════════════════════════════════════════════════════════\n\n";
