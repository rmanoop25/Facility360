<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Create pivot table
        Schema::create('category_service_provider', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->onDelete('cascade');
            $table->foreignId('service_provider_id')->constrained()->onDelete('cascade');
            $table->timestamps();

            $table->unique(['category_id', 'service_provider_id']);
            $table->index('category_id');
            $table->index('service_provider_id');
        });

        // Data migration: Copy existing category_id to pivot table
        DB::table('service_providers')
            ->whereNotNull('category_id')
            ->orderBy('id')
            ->chunk(100, function ($providers) {
                $pivotData = [];
                foreach ($providers as $provider) {
                    $pivotData[] = [
                        'category_id' => $provider->category_id,
                        'service_provider_id' => $provider->id,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                }
                DB::table('category_service_provider')->insert($pivotData);
            });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('category_service_provider');
    }
};
