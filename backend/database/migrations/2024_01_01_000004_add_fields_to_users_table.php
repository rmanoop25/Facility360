<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('phone', 20)->nullable()->after('email');
            $table->string('fcm_token')->nullable()->after('password');
            $table->enum('locale', ['en', 'ar'])->default('en')->after('fcm_token');
            $table->boolean('is_active')->default(true)->after('locale');

            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['is_active']);
            $table->dropColumn(['phone', 'fcm_token', 'locale', 'is_active']);
        });
    }
};
