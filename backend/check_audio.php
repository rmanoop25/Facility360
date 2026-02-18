<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "=== Issues with Audio Media ===\n";
$audioMedia = DB::table('issue_media')
    ->where('type', 'audio')
    ->get(['issue_id', 'type', 'file_path']);

if ($audioMedia->isEmpty()) {
    echo "No audio media found in issues.\n";
} else {
    foreach ($audioMedia as $media) {
        echo sprintf("Issue ID: %d | Type: %s | File: %s\n",
            $media->issue_id,
            $media->type,
            $media->file_path
        );
    }
}

echo "\n=== Proofs with Audio ===\n";
$audioProofs = DB::table('proofs')
    ->where('type', 'audio')
    ->get(['issue_assignment_id', 'type', 'file_path']);

if ($audioProofs->isEmpty()) {
    echo "No audio proofs found.\n";
} else {
    foreach ($audioProofs as $proof) {
        echo sprintf("Assignment ID: %d | Type: %s | File: %s\n",
            $proof->issue_assignment_id,
            $proof->type,
            $proof->file_path
        );
    }
}

echo "\n=== Issues with PDF Media ===\n";
$pdfMedia = DB::table('issue_media')
    ->where('type', 'pdf')
    ->get(['issue_id', 'type', 'file_path']);

if ($pdfMedia->isEmpty()) {
    echo "No PDF media found in issues.\n";
} else {
    foreach ($pdfMedia as $media) {
        echo sprintf("Issue ID: %d | Type: %s | File: %s\n",
            $media->issue_id,
            $media->type,
            $media->file_path
        );
    }
}

echo "\n=== Completed Issues ===\n";
$completed = DB::table('issues')
    ->where('status', 'completed')
    ->get(['id', 'title', 'status']);

echo sprintf("Total completed issues: %d\n", $completed->count());
if ($completed->isNotEmpty()) {
    foreach ($completed as $issue) {
        echo sprintf("  - Issue #%d: %s\n", $issue->id, $issue->title);
    }
}

echo "\n=== Finished Issues ===\n";
$finished = DB::table('issues')
    ->where('status', 'finished')
    ->get(['id', 'title', 'status']);

echo sprintf("Total finished issues: %d\n", $finished->count());
if ($finished->isNotEmpty()) {
    foreach ($finished as $issue) {
        echo sprintf("  - Issue #%d: %s\n", $issue->id, $issue->title);
    }
}
