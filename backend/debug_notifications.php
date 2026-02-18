<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\User;

echo "\n";
echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║         DEBUG: NOTIFICATIONS NOT SHOWING                   ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n\n";

// Find the super admin
$admin = User::where('email', 'admin@maintenance.local')->first();

if (!$admin) {
    echo "❌ Super Admin not found!\n";
    exit(1);
}

echo "Super Admin Found:\n";
echo "  ID: {$admin->id}\n";
echo "  Name: {$admin->name}\n";
echo "  Email: {$admin->email}\n\n";

// Check notifications directly from database
echo "Checking notifications table:\n";
$dbNotifications = DB::table('notifications')
    ->where('notifiable_type', 'App\\Models\\User')
    ->where('notifiable_id', $admin->id)
    ->get();

echo "  Total in DB: {$dbNotifications->count()}\n";
echo "  Unread in DB: " . $dbNotifications->where('read_at', null)->count() . "\n\n";

// Check via Eloquent
echo "Checking via Eloquent:\n";
$eloquentNotifications = $admin->notifications()->get();
echo "  Total via Eloquent: {$eloquentNotifications->count()}\n";
echo "  Unread via Eloquent: {$admin->unreadNotifications()->count()}\n\n";

// Show notification details
if ($dbNotifications->count() > 0) {
    echo "Notification Details:\n";
    echo "════════════════════════════════════════════════════════════\n";
    foreach ($dbNotifications as $notif) {
        echo "\nNotification ID: {$notif->id}\n";
        echo "  Type: {$notif->type}\n";
        echo "  Notifiable Type: {$notif->notifiable_type}\n";
        echo "  Notifiable ID: {$notif->notifiable_id}\n";
        echo "  Created: {$notif->created_at}\n";
        echo "  Read At: " . ($notif->read_at ?? 'NULL (Unread)') . "\n";

        $data = json_decode($notif->data, true);
        echo "  Data:\n";
        echo "    - Title: " . ($data['title'] ?? 'N/A') . "\n";
        echo "    - Body: " . ($data['body'] ?? 'N/A') . "\n";
        echo "    - Issue ID: " . ($data['issue_id'] ?? 'N/A') . "\n";
        echo "    - Type: " . ($data['type'] ?? 'N/A') . "\n";
        echo "    - Icon: " . ($data['icon'] ?? 'N/A') . "\n";
        echo "    - Color: " . ($data['color'] ?? 'N/A') . "\n";
    }
    echo "\n════════════════════════════════════════════════════════════\n\n";
}

// Check if User model uses Notifiable trait
echo "Checking User model:\n";
$reflection = new ReflectionClass($admin);
$traits = $reflection->getTraitNames();
echo "  Traits: " . implode(', ', $traits) . "\n";
echo "  Has Notifiable: " . (in_array('Illuminate\\Notifications\\Notifiable', $traits) ? 'YES' : 'NO') . "\n\n";

// Check database notifications table structure
echo "Checking notifications table structure:\n";
$columns = DB::select("DESCRIBE notifications");
foreach ($columns as $column) {
    echo "  - {$column->Field} ({$column->Type})\n";
}
echo "\n";

// Test if Filament can access them
echo "Testing Filament database notifications config:\n";
$config = config('filament.notifications');
echo "  Config exists: " . ($config ? 'YES' : 'NO') . "\n\n";

echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║         POSSIBLE ISSUES                                    ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n\n";

if ($dbNotifications->count() === 0) {
    echo "❌ ISSUE: No notifications in database\n";
    echo "   Solution: Run queue worker to process queued notifications\n";
    echo "   Command: php artisan queue:work --queue=notifications\n\n";
} elseif ($admin->unreadNotifications()->count() === 0) {
    echo "❌ ISSUE: All notifications marked as read\n";
    echo "   Solution: Create new test notification\n\n";
} else {
    echo "✅ Notifications exist in database and are unread\n\n";
    echo "Possible reasons Filament isn't showing them:\n";
    echo "1. Cache issue - Clear browser cache and Filament cache\n";
    echo "2. Session issue - Logout and login again\n";
    echo "3. Notification type mismatch\n";
    echo "4. Filament polling not working\n\n";

    echo "Try these solutions:\n";
    echo "1. Clear Filament cache:\n";
    echo "   php artisan filament:optimize\n\n";
    echo "2. Clear application cache:\n";
    echo "   php artisan cache:clear\n";
    echo "   php artisan config:clear\n\n";
    echo "3. Hard refresh browser (Ctrl+Shift+R)\n\n";
    echo "4. Check browser console for JavaScript errors\n\n";
}
