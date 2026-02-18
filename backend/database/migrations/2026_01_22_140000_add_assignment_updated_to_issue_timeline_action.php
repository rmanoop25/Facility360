<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Add 'assignment_updated' to the action enum
        DB::statement("ALTER TABLE issue_timeline MODIFY COLUMN action ENUM(
            'created',
            'assigned',
            'assignment_updated',
            'started',
            'held',
            'resumed',
            'finished',
            'approved',
            'cancelled'
        ) NOT NULL");
    }

    public function down(): void
    {
        // Remove 'assignment_updated' from the action enum
        // Note: This will fail if there are records with 'assignment_updated'
        DB::statement("ALTER TABLE issue_timeline MODIFY COLUMN action ENUM(
            'created',
            'assigned',
            'started',
            'held',
            'resumed',
            'finished',
            'approved',
            'cancelled'
        ) NOT NULL");
    }
};
