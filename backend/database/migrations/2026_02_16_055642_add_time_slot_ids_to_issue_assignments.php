<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            // Add JSON column to store multiple time slot IDs
            $table->json('time_slot_ids')->nullable()->after('time_slot_id');
        });

        // Migrate existing data: wrap single time_slot_id in JSON array
        DB::table('issue_assignments')
            ->whereNotNull('time_slot_id')
            ->update([
                'time_slot_ids' => DB::raw('JSON_ARRAY(time_slot_id)'),
            ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            $table->dropColumn('time_slot_ids');
        });
    }
};
