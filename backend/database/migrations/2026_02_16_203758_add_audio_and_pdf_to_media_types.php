<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Update issue_media table to add audio and pdf types
        DB::statement("ALTER TABLE issue_media MODIFY COLUMN type ENUM('photo', 'video', 'audio', 'pdf') NOT NULL");

        // Update proofs table to add pdf type
        DB::statement("ALTER TABLE proofs MODIFY COLUMN type ENUM('photo', 'video', 'audio', 'pdf') NOT NULL");
    }

    public function down(): void
    {
        // Revert issue_media table
        DB::statement("ALTER TABLE issue_media MODIFY COLUMN type ENUM('photo', 'video') NOT NULL");

        // Revert proofs table
        DB::statement("ALTER TABLE proofs MODIFY COLUMN type ENUM('photo', 'video', 'audio') NOT NULL");
    }
};
