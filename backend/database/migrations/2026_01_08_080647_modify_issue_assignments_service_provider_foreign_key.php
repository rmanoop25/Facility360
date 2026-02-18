<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            // Drop the existing foreign key constraint
            $table->dropForeign(['service_provider_id']);

            // Make the column nullable
            $table->foreignId('service_provider_id')->nullable()->change();
        });

        Schema::table('issue_assignments', function (Blueprint $table) {
            // Re-add the foreign key with nullOnDelete
            $table->foreign('service_provider_id')
                ->references('id')
                ->on('service_providers')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('issue_assignments', function (Blueprint $table) {
            // Drop the modified foreign key
            $table->dropForeign(['service_provider_id']);
        });

        Schema::table('issue_assignments', function (Blueprint $table) {
            // Restore original foreign key (without nullOnDelete)
            $table->foreign('service_provider_id')
                ->references('id')
                ->on('service_providers');
        });
    }
};
