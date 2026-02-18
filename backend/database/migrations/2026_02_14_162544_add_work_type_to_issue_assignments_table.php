<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            $table->foreignId('work_type_id')->nullable()->after('time_slot_id')->constrained()->nullOnDelete();
            $table->unsignedInteger('allocated_duration_minutes')->nullable()->after('work_type_id');
            $table->boolean('is_custom_duration')->default(false)->after('allocated_duration_minutes');

            $table->index('work_type_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            $table->dropForeign(['work_type_id']);
            $table->dropIndex(['work_type_id']);
            $table->dropColumn(['work_type_id', 'allocated_duration_minutes', 'is_custom_duration']);
        });
    }
};
