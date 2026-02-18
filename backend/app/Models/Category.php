<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Collection;

class Category extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'parent_id',
        'name_en',
        'name_ar',
        'icon',
        'is_active',
        'depth',
        'path',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'depth' => 'integer',
            'parent_id' => 'integer',
        ];
    }

    protected static function boot(): void
    {
        parent::boot();

        static::creating(function (Category $category): void {
            $category->validateIcon();
            $category->calculateHierarchy();
        });

        static::updating(function (Category $category): void {
            if ($category->isDirty('icon')) {
                $category->validateIcon();
            }

            if ($category->isDirty('parent_id')) {
                $category->calculateHierarchy();
            }

            // Auto-deactivate descendants when parent is deactivated
            if ($category->isDirty('is_active') && ! $category->is_active) {
                static::where('path', 'like', $category->path.'/%')
                    ->update(['is_active' => false]);
            }
        });

        static::saved(function (Category $category): void {
            // Update path after save (now we have ID for new records)
            if ($category->wasRecentlyCreated) {
                $category->updatePathAfterCreate();
            }

            // If parent changed, update all descendants' paths
            if ($category->wasChanged('parent_id')) {
                $category->updateDescendantsPaths();
            }
        });
    }

    // =========================================================================
    // Hierarchy Relationships
    // =========================================================================

    /**
     * Parent category relationship.
     */
    public function parent(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'parent_id');
    }

    /**
     * Direct children relationship.
     */
    public function children(): HasMany
    {
        return $this->hasMany(Category::class, 'parent_id');
    }

    /**
     * Recursive children (all descendants) with eager loading.
     */
    public function allChildren(): HasMany
    {
        return $this->children()->with('allChildren');
    }

    /**
     * Active children only.
     */
    public function activeChildren(): HasMany
    {
        return $this->children()->active();
    }

    /**
     * Recursive active children.
     */
    public function allActiveChildren(): HasMany
    {
        return $this->activeChildren()->with('allActiveChildren');
    }

    // =========================================================================
    // Existing Relationships
    // =========================================================================

    public function consumables(): HasMany
    {
        return $this->hasMany(Consumable::class);
    }

    public function serviceProviders(): BelongsToMany
    {
        return $this->belongsToMany(ServiceProvider::class, 'category_service_provider')
            ->withTimestamps();
    }

    public function issues(): BelongsToMany
    {
        return $this->belongsToMany(Issue::class, 'issue_categories');
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(IssueAssignment::class);
    }

    public function workTypes(): BelongsToMany
    {
        return $this->belongsToMany(WorkType::class, 'category_work_type')
            ->withTimestamps()
            ->orderBy('name_en');
    }

    public function activeWorkTypes(): BelongsToMany
    {
        return $this->workTypes()->where('is_active', true);
    }

    // =========================================================================
    // Scopes
    // =========================================================================

    /**
     * Filter active categories.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Filter root categories (no parent).
     */
    public function scopeRoots($query)
    {
        return $query->whereNull('parent_id');
    }

    /**
     * Filter categories at a specific depth level.
     */
    public function scopeAtDepth($query, int $depth)
    {
        return $query->where('depth', $depth);
    }

    /**
     * Filter leaf categories (no children).
     */
    public function scopeLeaves($query)
    {
        return $query->whereDoesntHave('children');
    }

    /**
     * Filter non-leaf categories (has children).
     */
    public function scopeWithChildren($query)
    {
        return $query->whereHas('children');
    }

    /**
     * Order by hierarchy (path) for proper tree display.
     */
    public function scopeOrderByHierarchy($query)
    {
        return $query->orderBy('path');
    }

    // =========================================================================
    // Accessors
    // =========================================================================

    /**
     * Get localized name based on current locale.
     */
    public function getNameAttribute(): string
    {
        $locale = app()->getLocale();

        return $locale === 'ar' ? $this->name_ar : $this->name_en;
    }

    /**
     * Alias for name accessor.
     */
    public function getLocalizedNameAttribute(): string
    {
        return $this->name;
    }

    /**
     * Check if category is a root (no parent).
     */
    public function getIsRootAttribute(): bool
    {
        return $this->parent_id === null;
    }

    /**
     * Check if category is a leaf (no children).
     */
    public function getIsLeafAttribute(): bool
    {
        return ! $this->children()->exists();
    }

    /**
     * Check if category has children.
     */
    public function getHasChildrenAttribute(): bool
    {
        return $this->children()->exists();
    }

    /**
     * Get count of direct children.
     */
    public function getChildrenCountAttribute(): int
    {
        return $this->children()->count();
    }

    /**
     * Get ancestor IDs efficiently from materialized path (no extra queries).
     */
    public function getAncestorIds(): array
    {
        if (! $this->path) {
            return [];
        }

        $ids = array_map('intval', explode('/', $this->path));
        array_pop($ids); // Remove self

        return $ids;
    }

    /**
     * Get all ancestors ordered from root to immediate parent.
     */
    public function getAncestorsAttribute(): Collection
    {
        $ancestors = collect();
        $category = $this;

        while ($category->parent_id !== null) {
            $category = $category->parent;
            if ($category) {
                $ancestors->prepend($category);
            } else {
                break;
            }
        }

        return $ancestors;
    }

    /**
     * Get full path name (e.g., "HVAC > Cooling > AC Units").
     */
    public function getFullPathNameAttribute(): string
    {
        $locale = app()->getLocale();
        $path = $this->ancestors->pluck($locale === 'ar' ? 'name_ar' : 'name_en')->toArray();
        $path[] = $locale === 'ar' ? $this->name_ar : $this->name_en;

        return implode(' > ', $path);
    }

    /**
     * Get full path name in English.
     */
    public function getFullPathNameEnAttribute(): string
    {
        $path = $this->ancestors->pluck('name_en')->toArray();
        $path[] = $this->name_en;

        return implode(' > ', $path);
    }

    /**
     * Get full path name in Arabic.
     */
    public function getFullPathNameArAttribute(): string
    {
        $path = $this->ancestors->pluck('name_ar')->toArray();
        $path[] = $this->name_ar;

        return implode(' < ', $path); // RTL separator
    }

    // =========================================================================
    // Validation Methods
    // =========================================================================

    /**
     * List of valid Heroicon icon names.
     */
    protected static function validIcons(): array
    {
        return [
            'heroicon-o-wrench',
            'heroicon-o-wrench-screwdriver',
            'heroicon-o-cog-6-tooth',
            'heroicon-o-bolt',
            'heroicon-o-fire',
            'heroicon-o-beaker',
            'heroicon-o-home',
            'heroicon-o-building-office',
            'heroicon-o-paint-brush',
            'heroicon-o-key',
            'heroicon-o-shield-check',
            'heroicon-o-truck',
            'heroicon-o-cube',
            'heroicon-o-scissors',
            'heroicon-o-sparkles',
            'heroicon-o-sun',
            'heroicon-o-wifi',
            'heroicon-o-tv',
            'heroicon-o-phone',
            'heroicon-o-light-bulb',
            'heroicon-o-window',
            'heroicon-o-arrow-path',
            'heroicon-o-clipboard-document-list',
            'heroicon-o-calendar',
            'heroicon-o-clock',
            'heroicon-o-exclamation-triangle',
            'heroicon-o-check-circle',
            'heroicon-o-tag',
            'heroicon-o-bug-ant',
            'heroicon-o-cog',
            'heroicon-o-arrow-up',
        ];
    }

    /**
     * Validate that the icon is a valid Heroicon name.
     */
    protected function validateIcon(): void
    {
        if ($this->icon && ! in_array($this->icon, self::validIcons(), true)) {
            throw new \InvalidArgumentException(
                "Invalid icon '{$this->icon}'. Must be a valid Heroicon name. Valid icons: ".implode(', ', self::validIcons())
            );
        }
    }

    // =========================================================================
    // Hierarchy Methods
    // =========================================================================

    /**
     * Calculate and set depth and path based on parent.
     */
    protected function calculateHierarchy(): void
    {
        if ($this->parent_id) {
            $parent = Category::find($this->parent_id);
            if ($parent) {
                $this->depth = $parent->depth + 1;
                // Path will be set after save for new records
                if ($this->exists) {
                    $this->path = $parent->path.'/'.$this->id;
                }
            }
        } else {
            $this->depth = 0;
            if ($this->exists) {
                $this->path = (string) $this->id;
            }
        }
    }

    /**
     * Update path after creating (when we have an ID).
     */
    public function updatePathAfterCreate(): void
    {
        if ($this->parent_id) {
            $parent = $this->parent;
            $this->path = $parent ? $parent->path.'/'.$this->id : (string) $this->id;
        } else {
            $this->path = (string) $this->id;
        }
        $this->saveQuietly();
    }

    /**
     * Update paths of all descendants recursively.
     */
    public function updateDescendantsPaths(): void
    {
        foreach ($this->children as $child) {
            $child->depth = $this->depth + 1;
            $child->path = $this->path.'/'.$child->id;
            $child->saveQuietly();
            $child->updateDescendantsPaths();
        }
    }

    /**
     * Archive this category and all its descendants.
     */
    public function archive(): void
    {
        $now = now();

        // Archive self
        $this->deleted_at = $now;
        $this->saveQuietly();

        // Archive all descendants
        static::where('path', 'like', $this->path.'/%')
            ->update(['deleted_at' => $now]);
    }

    /**
     * Restore this category and optionally all its descendants.
     */
    public function restoreWithDescendants(bool $includeDescendants = true): void
    {
        $this->restore();

        if ($includeDescendants) {
            static::withTrashed()
                ->where('path', 'like', $this->path.'/%')
                ->restore();
        }
    }

    /**
     * Get all descendant IDs.
     */
    public function getDescendantIds(): array
    {
        return static::where('path', 'like', $this->path.'/%')
            ->pluck('id')
            ->toArray();
    }

    /**
     * Get all descendants.
     */
    public function getDescendants(): Collection
    {
        return static::where('path', 'like', $this->path.'/%')
            ->orderBy('path')
            ->get();
    }

    /**
     * Check if this category is an ancestor of another.
     */
    public function isAncestorOf(Category $category): bool
    {
        return str_starts_with($category->path ?? '', $this->path.'/');
    }

    /**
     * Check if this category is a descendant of another.
     */
    public function isDescendantOf(Category $category): bool
    {
        return str_starts_with($this->path ?? '', $category->path.'/');
    }

    /**
     * Move this category to a new parent.
     */
    public function moveTo(?Category $newParent): void
    {
        // Prevent circular reference
        if ($newParent && ($newParent->id === $this->id || $newParent->isDescendantOf($this))) {
            throw new \InvalidArgumentException('Cannot move category to itself or its descendant.');
        }

        $this->parent_id = $newParent?->id;
        $this->save();
    }

    /**
     * Get tree structure starting from this category.
     */
    public function getTree(): array
    {
        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'name_en' => $this->name_en,
            'name_ar' => $this->name_ar,
            'icon' => $this->icon,
            'is_active' => $this->is_active,
            'depth' => $this->depth,
            'children' => $this->children->map(fn ($child) => $child->getTree())->toArray(),
        ];
    }

    /**
     * Build a full tree from root categories.
     */
    public static function getFullTree(bool $activeOnly = true): Collection
    {
        $query = static::roots()->with('allChildren');

        if ($activeOnly) {
            $query->active();
        }

        return $query->orderBy('name_en')->get();
    }
}
