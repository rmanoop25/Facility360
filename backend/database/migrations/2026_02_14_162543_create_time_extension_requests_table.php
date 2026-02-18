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
        Schema::create('time_extension_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('assignment_id')->constrained('issue_assignments')->cascadeOnDelete();
            $table->foreignId('requested_by')->constrained('users');
            $table->unsignedInteger('requested_minutes');
            $table->text('reason');
            $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->foreignId('responded_by')->nullable()->constrained('users');
            $table->text('admin_notes')->nullable();
            $table->timestamp('requested_at');
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();

            $table->index('assignment_id');
            $table->index('status');
            $table->index('requested_by');
            $table->index('responded_by');
            $table->index(['assignment_id', 'status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('time_extension_requests');
    }
};
