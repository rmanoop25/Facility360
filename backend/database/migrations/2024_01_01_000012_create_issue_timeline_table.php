<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('issue_timeline', function (Blueprint $table) {
            $table->id();
            $table->foreignId('issue_id')->constrained()->cascadeOnDelete();
            $table->foreignId('issue_assignment_id')->nullable()->constrained()->cascadeOnDelete();
            $table->enum('action', [
                'created',
                'assigned',
                'started',
                'held',
                'resumed',
                'finished',
                'approved',
                'cancelled'
            ]);
            $table->foreignId('performed_by')->constrained('users');
            $table->text('notes')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index('issue_id');
            $table->index('issue_assignment_id');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('issue_timeline');
    }
};
