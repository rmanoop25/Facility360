<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Category
 */
class CategoryResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $locale = $request->header('Accept-Language', app()->getLocale());

        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'name_en' => $this->name_en,
            'name_ar' => $this->name_ar,
            'name' => $locale === 'ar' ? $this->name_ar : $this->name_en,
            'icon' => $this->icon,
            'is_active' => $this->is_active,
            'depth' => $this->depth ?? 0,
            'path' => $this->path,
            'is_root' => $this->is_root,

            // Optional fields based on request parameters
            'is_leaf' => $this->when(
                $request->boolean('include_leaf_info', false),
                fn () => $this->is_leaf
            ),
            'has_children' => $this->when(
                $request->boolean('include_children_info', false) || $request->boolean('nested', false),
                fn () => $this->has_children
            ),
            'children_count' => $this->when(
                $this->relationLoaded('children') || isset($this->children_count),
                fn () => $this->children_count ?? $this->children->count()
            ),
            'full_path_name' => $this->when(
                $request->boolean('include_path_name', false),
                fn () => $this->full_path_name
            ),
            'full_path_name_en' => $this->when(
                $request->boolean('include_path_name', false),
                fn () => $this->full_path_name_en
            ),
            'full_path_name_ar' => $this->when(
                $request->boolean('include_path_name', false),
                fn () => $this->full_path_name_ar
            ),

            // Nested children when requested (check both 'children' and 'allChildren' relations)
            'children' => $this->when(
                $request->boolean('nested', false) && ($this->relationLoaded('children') || $this->relationLoaded('allChildren')),
                fn () => CategoryResource::collection($this->relationLoaded('allChildren') ? $this->allChildren : $this->children)
            ),

            // Parent info when requested
            'parent' => $this->when(
                $request->boolean('include_parent', false) && $this->relationLoaded('parent') && $this->parent,
                fn () => [
                    'id' => $this->parent->id,
                    'name_en' => $this->parent->name_en,
                    'name_ar' => $this->parent->name_ar,
                    'name' => $locale === 'ar' ? $this->parent->name_ar : $this->parent->name_en,
                    'icon' => $this->parent->icon,
                ]
            ),

            // Statistics when loaded
            'consumables_count' => $this->when(
                isset($this->consumables_count),
                $this->consumables_count
            ),
            'service_providers_count' => $this->when(
                isset($this->service_providers_count),
                $this->service_providers_count
            ),
            'issues_count' => $this->when(
                isset($this->issues_count),
                $this->issues_count
            ),
        ];
    }
}
