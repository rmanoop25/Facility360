<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('issue_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('issue_id')->constrained()->cascadeOnDelete();
            $table->foreignId('service_provider_id')->constrained();
            $table->foreignId('category_id')->constrained();
            $table->foreignId('time_slot_id')->nullable()->constrained()->nullOnDelete();
            $table->date('scheduled_date')->nullable();
            $table->enum('status', [
                'assigned',
                'in_progress',
                'on_hold',
                'finished',
                'completed'
            ])->default('assigned');
            $table->boolean('proof_required')->default(false);
            $table->timestamp('started_at')->nullable();
            $table->timestamp('held_at')->nullable();
            $table->timestamp('resumed_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('service_provider_id');
            $table->index('issue_id');
            $table->index('status');
            $table->index('scheduled_date');
            // Composite index for concurrency control (double booking prevention)
            $table->index(['service_provider_id', 'scheduled_date', 'time_slot_id'], 'idx_sp_schedule');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('issue_assignments');
    }
};
