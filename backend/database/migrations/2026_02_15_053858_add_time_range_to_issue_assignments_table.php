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
            // Add time range columns for partial slot booking
            $table->time('assigned_start_time')->nullable()->after('scheduled_date');
            $table->time('assigned_end_time')->nullable()->after('assigned_start_time');

            // Add composite index for fast overlap detection queries
            $table->index([
                'service_provider_id',
                'scheduled_date',
                'assigned_start_time',
                'assigned_end_time',
            ], 'idx_sp_time_range');
        });

        // Migrate existing data: populate time range from associated time slot
        DB::table('issue_assignments')
            ->whereNotNull('time_slot_id')
            ->whereNotNull('scheduled_date')
            ->whereNull('assigned_start_time') // Only update records without time range
            ->chunkById(100, function ($assignments) {
                foreach ($assignments as $assignment) {
                    $timeSlot = DB::table('time_slots')
                        ->find($assignment->time_slot_id);

                    if ($timeSlot) {
                        // Use the full slot time range as the assigned time
                        DB::table('issue_assignments')
                            ->where('id', $assignment->id)
                            ->update([
                                'assigned_start_time' => $timeSlot->start_time,
                                'assigned_end_time' => $timeSlot->end_time,
                            ]);
                    }
                }
            });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            // Drop index first
            $table->dropIndex('idx_sp_time_range');

            // Drop columns
            $table->dropColumn(['assigned_start_time', 'assigned_end_time']);
        });
    }
};
