<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::statement("ALTER TABLE issue_timeline MODIFY COLUMN action ENUM('created', 'assigned', 'assignment_updated', 'started', 'held', 'resumed', 'finished', 'approved', 'cancelled', 'updated') NOT NULL");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement("ALTER TABLE issue_timeline MODIFY COLUMN action ENUM('created', 'assigned', 'assignment_updated', 'started', 'held', 'resumed', 'finished', 'approved', 'cancelled') NOT NULL");
    }
};
