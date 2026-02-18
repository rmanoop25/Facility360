<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Media attached by tenant when creating issue (photos/videos of the problem)
        Schema::create('issue_media', function (Blueprint $table) {
            $table->id();
            $table->foreignId('issue_id')->constrained()->cascadeOnDelete();
            $table->enum('type', ['photo', 'video']);
            $table->string('file_path', 500);
            $table->timestamp('uploaded_at')->useCurrent();

            $table->index('issue_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('issue_media');
    }
};
