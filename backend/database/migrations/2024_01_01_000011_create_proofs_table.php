<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('proofs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('issue_assignment_id')->constrained()->cascadeOnDelete();
            $table->enum('type', ['photo', 'video', 'audio']);
            $table->string('file_path', 500);
            $table->enum('stage', ['during_work', 'completion']);
            $table->timestamp('uploaded_at')->useCurrent();

            $table->index('issue_assignment_id');
            $table->index('stage');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('proofs');
    }
};
