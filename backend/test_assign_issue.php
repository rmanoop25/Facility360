<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== Testing Issue Assignment with Notifications ===" . PHP_EOL . PHP_EOL;

// Get test data
$issue = \App\Models\Issue::where('status', \App\Enums\IssueStatus::PENDING)->first();
if (!$issue) {
    $issue = \App\Models\Issue::where('status', \App\Enums\IssueStatus::ASSIGNED)->first();
}

$sp = \App\Models\ServiceProvider::first();
$timeSlot = \App\Models\TimeSlot::where('service_provider_id', $sp->id)->first();

if (!$issue || !$sp || !$timeSlot) {
    echo "ERROR: Missing test data (issue, SP, or time slot)" . PHP_EOL;
    exit(1);
}

echo "Test Data:" . PHP_EOL;
echo "  - Issue: #{$issue->id} - {$issue->title}" . PHP_EOL;
echo "  - Service Provider: {$sp->name} (ID: {$sp->id})" . PHP_EOL;
echo "  - Time Slot: {$timeSlot->formatted_time_range}" . PHP_EOL;
echo PHP_EOL;

// Count current notifications
$notifCountBefore = DB::table('notifications')->count();
echo "Notifications before: {$notifCountBefore}" . PHP_EOL;

// Simulate the assignment process (from AdminIssueController)
try {
    DB::beginTransaction();

    // Create assignment
    $assignment = \App\Models\IssueAssignment::create([
        'issue_id' => $issue->id,
        'service_provider_id' => $sp->id,
        'category_id' => $sp->category_id,
        'time_slot_id' => $timeSlot->id,
        'scheduled_date' => now()->addDays(1)->toDateString(),
        'status' => \App\Enums\AssignmentStatus::ASSIGNED,
        'proof_required' => false,
        'notes' => 'Test assignment with notifications',
    ]);

    // Update issue status
    $issue->update(['status' => \App\Enums\IssueStatus::ASSIGNED]);

    DB::commit();

    echo "✓ Assignment created successfully" . PHP_EOL . PHP_EOL;

    // Now send notifications (like in the controller)
    echo "Sending notifications..." . PHP_EOL;

    // 1. Notify Service Provider
    if ($sp->user) {
        echo "  - Notifying SP: {$sp->user->name}..." . PHP_EOL;
        // This would normally send FCM, but we'll just log
        echo "    (FCM notification would be sent here)" . PHP_EOL;
    }

    // 2. Notify Tenant
    $issue->load('tenant.user');
    if ($issue->tenant?->user) {
        echo "  - Notifying Tenant: {$issue->tenant->user->name}..." . PHP_EOL;
        // This would normally send FCM
        echo "    (FCM notification would be sent here)" . PHP_EOL;
    }

    // 3. Notify Admins (database notifications)
    echo "  - Notifying Admins..." . PHP_EOL;
    $adminUsers = \App\Models\User::role(['super_admin', 'manager'])->get();
    foreach ($adminUsers as $admin) {
        $admin->notify(new \App\Notifications\IssueNotification(
            $issue,
            \App\Enums\NotificationType::ISSUE_ASSIGNED
        ));
        echo "    ✓ {$admin->name}" . PHP_EOL;
    }

    echo PHP_EOL;

    // Count notifications after
    $notifCountAfter = DB::table('notifications')->count();
    echo "Notifications after: {$notifCountAfter}" . PHP_EOL;
    echo "New notifications created: " . ($notifCountAfter - $notifCountBefore) . PHP_EOL;
    echo PHP_EOL;

    // Show recent notifications
    echo "Recent notifications:" . PHP_EOL;
    $recent = DB::table('notifications')
        ->orderBy('created_at', 'desc')
        ->limit(5)
        ->get();

    foreach ($recent as $n) {
        $user = \App\Models\User::find($n->notifiable_id);
        $data = json_decode($n->data, true);
        $status = $n->read_at ? 'read' : 'unread';
        echo "  - {$user->name}: " . ($data['title'] ?? 'N/A') . " ({$status})" . PHP_EOL;
    }

} catch (\Exception $e) {
    DB::rollBack();
    echo "ERROR: " . $e->getMessage() . PHP_EOL;
    echo $e->getTraceAsString() . PHP_EOL;
}
