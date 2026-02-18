<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Models\Category;
use App\Models\Consumable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends ApiController
{
    /**
     * Get all master data for offline sync.
     */
    public function masterData(): JsonResponse
    {
        $categories = Category::where('is_active', true)
            ->orderBy('name_en')
            ->get()
            ->map(fn ($cat) => [
                'id' => $cat->id,
                'name_en' => $cat->name_en,
                'name_ar' => $cat->name_ar,
                'icon' => $cat->icon,
                'updated_at' => $cat->updated_at->format('Y-m-d\TH:i:s\Z'),
            ]);

        $consumables = Consumable::where('is_active', true)
            ->orderBy('name_en')
            ->get()
            ->map(fn ($c) => [
                'id' => $c->id,
                'name_en' => $c->name_en,
                'name_ar' => $c->name_ar,
                'unit' => $c->unit,
                'updated_at' => $c->updated_at->format('Y-m-d\TH:i:s\Z'),
            ]);

        return $this->success([
            'categories' => $categories,
            'consumables' => $consumables,
            'settings' => [
                'default_locale' => config('app.locale', 'en'),
                'available_locales' => config('app.available_locales', ['en', 'ar']),
                'timezone' => config('app.timezone', 'UTC'),
            ],
            'synced_at' => now()->format('Y-m-d\TH:i:s\Z'),
        ], __('api.sync.master_data_success'));
    }

    /**
     * Process batch sync operations (for offline-first mobile apps).
     */
    public function batch(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'operations' => ['required', 'array'],
            'operations.*.type' => ['required', 'string', 'in:create_issue,update_issue,cancel_issue'],
            'operations.*.local_id' => ['required', 'string'],
            'operations.*.data' => ['required', 'array'],
            'operations.*.created_at' => ['required', 'date'],
        ]);

        $results = [];
        $processed = 0;
        $failed = 0;
        $errors = [];

        foreach ($validated['operations'] as $index => $operation) {
            try {
                $result = $this->processOperation($operation);
                $results[] = [
                    'local_id' => $operation['local_id'],
                    'success' => true,
                    'server_id' => $result['id'] ?? null,
                ];
                $processed++;
            } catch (\Exception $e) {
                $failed++;
                $errors[] = [
                    'local_id' => $operation['local_id'],
                    'error' => $e->getMessage(),
                ];
                $results[] = [
                    'local_id' => $operation['local_id'],
                    'success' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }

        return $this->success([
            'results' => $results,
            'summary' => [
                'processed' => $processed,
                'failed' => $failed,
                'total' => count($validated['operations']),
            ],
            'errors' => $errors,
        ], __('api.sync.batch_success'));
    }

    /**
     * Process a single sync operation.
     */
    private function processOperation(array $operation): array
    {
        // TODO: Implement actual sync operations based on type
        // This would handle offline-created issues, etc.

        return ['id' => null, 'status' => 'processed'];
    }
}
