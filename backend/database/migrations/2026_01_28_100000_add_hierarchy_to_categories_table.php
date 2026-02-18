<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            // Hierarchy columns
            $table->foreignId('parent_id')
                ->nullable()
                ->after('id')
                ->constrained('categories')
                ->nullOnDelete();

            $table->unsignedSmallInteger('depth')
                ->default(0)
                ->after('parent_id');

            $table->string('path', 500)
                ->nullable()
                ->after('depth');

            // Soft deletes for archiving
            $table->softDeletes();

            // Indexes for hierarchy queries
            $table->index(['parent_id', 'is_active'], 'categories_parent_active_index');
            $table->index('depth', 'categories_depth_index');
            $table->index('path', 'categories_path_index');
        });

        // Initialize path for existing categories (all become roots)
        \App\Models\Category::query()->update([
            'depth' => 0,
        ]);

        // Set path after we have the structure
        \App\Models\Category::all()->each(function ($category) {
            $category->path = (string) $category->id;
            $category->saveQuietly();
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropForeign(['parent_id']);
            $table->dropIndex('categories_parent_active_index');
            $table->dropIndex('categories_depth_index');
            $table->dropIndex('categories_path_index');
            $table->dropColumn(['parent_id', 'depth', 'path', 'deleted_at']);
        });
    }
};
