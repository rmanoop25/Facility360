<?php

declare(strict_types=1);

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
            $table->date('scheduled_end_date')->nullable()->after('scheduled_date');
        });

        // Update existing records - set end date same as start date
        DB::table('issue_assignments')->update([
            'scheduled_end_date' => DB::raw('scheduled_date'),
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            $table->dropColumn('scheduled_end_date');
        });
    }
};
