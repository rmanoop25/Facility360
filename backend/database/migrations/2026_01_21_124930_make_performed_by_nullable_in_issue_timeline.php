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
        Schema::table('issue_timeline', function (Blueprint $table) {
            $table->dropForeign(['performed_by']);
        });

        Schema::table('issue_timeline', function (Blueprint $table) {
            $table->unsignedBigInteger('performed_by')->nullable()->change();

            $table->foreign('performed_by')
                ->references('id')
                ->on('users')
                ->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('issue_timeline', function (Blueprint $table) {
            $table->dropForeign(['performed_by']);
        });

        Schema::table('issue_timeline', function (Blueprint $table) {
            $table->unsignedBigInteger('performed_by')->nullable(false)->change();

            $table->foreign('performed_by')
                ->references('id')
                ->on('users');
        });
    }
};
