<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== Watching for FCM Token Registration ===" . PHP_EOL;
echo "Enable notifications in Android settings, then logout/login in the app..." . PHP_EOL;
echo "Press Ctrl+C to stop watching" . PHP_EOL . PHP_EOL;

$lastCount = 0;
$lastCheck = null;

while (true) {
    // Check for users with tokens
    $usersWithTokens = \App\Models\User::whereNotNull('fcm_token')->get(['id', 'name', 'email', 'fcm_token', 'updated_at']);
    $currentCount = $usersWithTokens->count();

    if ($currentCount !== $lastCount) {
        echo "[" . date('H:i:s') . "] ✓ CHANGE DETECTED!" . PHP_EOL;
        echo "Users with FCM tokens: {$currentCount}" . PHP_EOL;

        foreach ($usersWithTokens as $user) {
            $tokenPreview = substr($user->fcm_token, 0, 40) . '...';
            echo "  - {$user->name} ({$user->email})" . PHP_EOL;
            echo "    Token: {$tokenPreview}" . PHP_EOL;
            echo "    Updated: {$user->updated_at}" . PHP_EOL;
        }
        echo PHP_EOL;

        $lastCount = $currentCount;
    } else {
        // Show waiting indicator every 5 seconds
        if ($lastCheck === null || time() - $lastCheck >= 5) {
            echo "[" . date('H:i:s') . "] Waiting for token registration... (Users with tokens: {$currentCount})" . PHP_EOL;
            $lastCheck = time();
        }
    }

    sleep(2);
}
