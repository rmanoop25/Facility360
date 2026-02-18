<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('issue_assignment_consumables', function (Blueprint $table) {
            $table->id();
            $table->foreignId('issue_assignment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('consumable_id')->nullable()->constrained()->nullOnDelete();
            $table->string('custom_name')->nullable(); // For "others" option
            $table->unsignedInteger('quantity')->default(1);
            $table->timestamp('created_at')->useCurrent();

            $table->index('issue_assignment_id');
            $table->index('consumable_id');
            $table->index('custom_name'); // Index for frequent custom consumables widget
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('issue_assignment_consumables');
    }
};
