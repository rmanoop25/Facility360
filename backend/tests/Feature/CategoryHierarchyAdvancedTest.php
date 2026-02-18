<?php

declare(strict_types=1);

use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Support\Facades\Hash;

/*
|--------------------------------------------------------------------------
| Advanced Category Hierarchy Tests
|--------------------------------------------------------------------------
|
| Extends the base hierarchy tests with deeper hierarchies (4+ levels),
| category deactivation cascading, materialized path recalculation on
| parent changes, tree utility methods, and hierarchy-aware navigation.
|
*/

beforeEach(function () {
    $this->seed(RolesAndPermissionsSeeder::class);
});

/*
|--------------------------------------------------------------------------
| Deep hierarchies (4+ levels)
|--------------------------------------------------------------------------
*/

describe('Deep hierarchies (4+ levels)', function () {

    it('handles 4-level deep hierarchy with correct ancestor chain', function () {
        $level0 = Category::create(['name_en' => 'L0', 'name_ar' => 'مستوى0', 'is_active' => true]);
        $level1 = Category::create(['parent_id' => $level0->id, 'name_en' => 'L1', 'name_ar' => 'مستوى1', 'is_active' => true]);
        $level2 = Category::create(['parent_id' => $level1->id, 'name_en' => 'L2', 'name_ar' => 'مستوى2', 'is_active' => true]);
        $level3 = Category::create(['parent_id' => $level2->id, 'name_en' => 'L3', 'name_ar' => 'مستوى3', 'is_active' => true]);

        $ancestors = $level3->fresh()->getAncestorIds();

        expect($ancestors)->toHaveCount(3)
            ->and($ancestors)->toBe([$level0->id, $level1->id, $level2->id]);
    });

    it('5-level hierarchy returns full ancestor chain', function () {
        $l0 = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $l1 = Category::create(['parent_id' => $l0->id, 'name_en' => 'L1', 'name_ar' => 'م1', 'is_active' => true]);
        $l2 = Category::create(['parent_id' => $l1->id, 'name_en' => 'L2', 'name_ar' => 'م2', 'is_active' => true]);
        $l3 = Category::create(['parent_id' => $l2->id, 'name_en' => 'L3', 'name_ar' => 'م3', 'is_active' => true]);
        $l4 = Category::create(['parent_id' => $l3->id, 'name_en' => 'L4', 'name_ar' => 'م4', 'is_active' => true]);

        $ancestors = $l4->fresh()->getAncestorIds();

        expect($ancestors)->toHaveCount(4)
            ->and($ancestors)->toBe([$l0->id, $l1->id, $l2->id, $l3->id]);
    });

    it('deep leaf returns SPs from all ancestor levels', function () {
        $l0 = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $l1 = Category::create(['parent_id' => $l0->id, 'name_en' => 'L1', 'name_ar' => 'م1', 'is_active' => true]);
        $l2 = Category::create(['parent_id' => $l1->id, 'name_en' => 'L2', 'name_ar' => 'م2', 'is_active' => true]);
        $l3 = Category::create(['parent_id' => $l2->id, 'name_en' => 'L3', 'name_ar' => 'م3', 'is_active' => true]);

        $spRoot = createTestSp([$l0->id]);
        $spMid = createTestSp([$l1->id]);
        $spLeaf = createTestSp([$l3->id]);

        $results = ServiceProvider::available()
            ->forCategoryWithAncestors($l3->id)
            ->pluck('id')
            ->toArray();

        expect($results)->toContain($spRoot->id)
            ->and($results)->toContain($spMid->id)
            ->and($results)->toContain($spLeaf->id);
    });

    it('depth is calculated correctly at each level', function () {
        $l0 = Category::create(['name_en' => 'D0', 'name_ar' => 'ع0', 'is_active' => true]);
        $l1 = Category::create(['parent_id' => $l0->id, 'name_en' => 'D1', 'name_ar' => 'ع1', 'is_active' => true]);
        $l2 = Category::create(['parent_id' => $l1->id, 'name_en' => 'D2', 'name_ar' => 'ع2', 'is_active' => true]);
        $l3 = Category::create(['parent_id' => $l2->id, 'name_en' => 'D3', 'name_ar' => 'ع3', 'is_active' => true]);

        expect($l0->fresh()->depth)->toBe(0)
            ->and($l1->fresh()->depth)->toBe(1)
            ->and($l2->fresh()->depth)->toBe(2)
            ->and($l3->fresh()->depth)->toBe(3);
    });
});

/*
|--------------------------------------------------------------------------
| Materialized path correctness
|--------------------------------------------------------------------------
*/

describe('Materialized path updates', function () {

    it('path is set correctly on creation', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        expect($root->fresh()->path)->toBe((string) $root->id)
            ->and($child->fresh()->path)->toBe("{$root->id}/{$child->id}")
            ->and($grandchild->fresh()->path)->toBe("{$root->id}/{$child->id}/{$grandchild->id}");
    });

    it('descendant paths update when parent is moved', function () {
        $root1 = Category::create(['name_en' => 'Root1', 'name_ar' => 'جذر1', 'is_active' => true]);
        $root2 = Category::create(['name_en' => 'Root2', 'name_ar' => 'جذر2', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root1->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        // Original path
        expect($grandchild->fresh()->path)->toBe("{$root1->id}/{$child->id}/{$grandchild->id}");

        // Move child to root2
        $child->moveTo($root2);

        // Paths should be recalculated
        expect($child->fresh()->path)->toBe("{$root2->id}/{$child->id}")
            ->and($grandchild->fresh()->path)->toBe("{$root2->id}/{$child->id}/{$grandchild->id}");
    });

    it('moving to root updates path to just the ID', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        expect($child->fresh()->path)->toBe("{$root->id}/{$child->id}");

        // Move to root (no parent)
        $child->moveTo(null);

        expect($child->fresh()->path)->toBe((string) $child->id)
            ->and($child->fresh()->parent_id)->toBeNull()
            ->and($child->fresh()->depth)->toBe(0);
    });

    it('prevents circular reference when moving to own descendant', function () {
        $parent = Category::create(['name_en' => 'Parent', 'name_ar' => 'أب', 'is_active' => true]);
        $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        expect(fn () => $parent->moveTo($child))->toThrow(
            InvalidArgumentException::class,
            'Cannot move category to itself or its descendant.'
        );
    });

    it('prevents moving category to itself', function () {
        $cat = Category::create(['name_en' => 'Self', 'name_ar' => 'نفس', 'is_active' => true]);

        expect(fn () => $cat->moveTo($cat))->toThrow(
            InvalidArgumentException::class,
            'Cannot move category to itself or its descendant.'
        );
    });
});

/*
|--------------------------------------------------------------------------
| Category deactivation cascading
|--------------------------------------------------------------------------
*/

describe('Category deactivation cascading', function () {

    it('deactivating parent cascades to all descendants', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        // Deactivate root
        $root->update(['is_active' => false]);

        expect($root->fresh()->is_active)->toBeFalse()
            ->and($child->fresh()->is_active)->toBeFalse()
            ->and($grandchild->fresh()->is_active)->toBeFalse();
    });

    it('deactivating mid-level cascades only to its descendants', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);
        $sibling = Category::create(['parent_id' => $root->id, 'name_en' => 'Sibling', 'name_ar' => 'شقيق', 'is_active' => true]);

        // Deactivate child (not root)
        $child->update(['is_active' => false]);

        expect($root->fresh()->is_active)->toBeTrue()
            ->and($child->fresh()->is_active)->toBeFalse()
            ->and($grandchild->fresh()->is_active)->toBeFalse()
            ->and($sibling->fresh()->is_active)->toBeTrue(); // Sibling unaffected
    });

    it('reactivating parent does NOT cascade to descendants', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        // Deactivate cascade
        $root->update(['is_active' => false]);
        expect($child->fresh()->is_active)->toBeFalse();

        // Reactivate parent - child should stay inactive (manual reactivation needed)
        $root->update(['is_active' => true]);
        expect($root->fresh()->is_active)->toBeTrue()
            ->and($child->fresh()->is_active)->toBeFalse();
    });

    it('deactivated categories are excluded by active() scope', function () {
        $active = Category::create(['name_en' => 'Active', 'name_ar' => 'نشط', 'is_active' => true]);
        $inactive = Category::create(['name_en' => 'Inactive', 'name_ar' => 'غير نشط', 'is_active' => false]);

        $results = Category::active()->pluck('id')->toArray();

        expect($results)->toContain($active->id)
            ->and($results)->not->toContain($inactive->id);
    });
});

/*
|--------------------------------------------------------------------------
| Category tree utilities
|--------------------------------------------------------------------------
*/

describe('Category tree utilities', function () {

    it('isRoot is true for root categories', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        expect($root->is_root)->toBeTrue()
            ->and($child->is_root)->toBeFalse();
    });

    it('isLeaf is true for categories with no children', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        expect($root->is_leaf)->toBeFalse() // has child
            ->and($child->is_leaf)->toBeTrue(); // no children
    });

    it('isAncestorOf returns true for direct and indirect ancestors', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        expect($root->isAncestorOf($child))->toBeTrue()
            ->and($root->isAncestorOf($grandchild))->toBeTrue()
            ->and($child->isAncestorOf($grandchild))->toBeTrue()
            ->and($grandchild->isAncestorOf($root))->toBeFalse();
    });

    it('isDescendantOf returns true for direct and indirect descendants', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        expect($grandchild->isDescendantOf($root))->toBeTrue()
            ->and($grandchild->isDescendantOf($child))->toBeTrue()
            ->and($child->isDescendantOf($root))->toBeTrue()
            ->and($root->isDescendantOf($grandchild))->toBeFalse();
    });

    it('getDescendantIds returns all descendant IDs', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child1 = Category::create(['parent_id' => $root->id, 'name_en' => 'C1', 'name_ar' => 'ط1', 'is_active' => true]);
        $child2 = Category::create(['parent_id' => $root->id, 'name_en' => 'C2', 'name_ar' => 'ط2', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child1->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        $descendantIds = $root->getDescendantIds();

        expect($descendantIds)->toContain($child1->id)
            ->and($descendantIds)->toContain($child2->id)
            ->and($descendantIds)->toContain($grandchild->id)
            ->and($descendantIds)->not->toContain($root->id); // Self is not a descendant
    });

    it('getTree returns correct tree structure', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        $tree = $root->fresh()->load('children')->getTree();

        expect($tree)->toHaveKey('id', $root->id)
            ->and($tree)->toHaveKey('name_en', 'Root')
            ->and($tree)->toHaveKey('children')
            ->and($tree['children'])->toHaveCount(1)
            ->and($tree['children'][0]['id'])->toBe($child->id);
    });

    it('fullPathName returns breadcrumb path', function () {
        $root = Category::create(['name_en' => 'HVAC', 'name_ar' => 'تكييف', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Cooling', 'name_ar' => 'تبريد', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'AC Units', 'name_ar' => 'مكيفات', 'is_active' => true]);

        expect($grandchild->fresh()->full_path_name_en)->toBe('HVAC > Cooling > AC Units');
    });
});

/*
|--------------------------------------------------------------------------
| Category scopes
|--------------------------------------------------------------------------
*/

describe('Category scopes', function () {

    it('roots() returns only categories without parents', function () {
        $root1 = Category::create(['name_en' => 'R1', 'name_ar' => 'ج1', 'is_active' => true]);
        $root2 = Category::create(['name_en' => 'R2', 'name_ar' => 'ج2', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root1->id, 'name_en' => 'C1', 'name_ar' => 'ط1', 'is_active' => true]);

        $rootIds = Category::roots()->pluck('id')->toArray();

        expect($rootIds)->toContain($root1->id)
            ->and($rootIds)->toContain($root2->id)
            ->and($rootIds)->not->toContain($child->id);
    });

    it('atDepth() filters by depth level', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        expect(Category::atDepth(0)->pluck('id')->toArray())->toContain($root->id)
            ->and(Category::atDepth(1)->pluck('id')->toArray())->toContain($child->id)
            ->and(Category::atDepth(2)->pluck('id')->toArray())->toContain($grandchild->id);
    });

    it('leaves() returns only categories with no children', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        $leafIds = Category::leaves()->pluck('id')->toArray();

        expect($leafIds)->toContain($child->id)
            ->and($leafIds)->not->toContain($root->id);
    });

    it('orderByHierarchy() sorts by path for proper tree display', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child2 = Category::create(['parent_id' => $root->id, 'name_en' => 'B', 'name_ar' => 'ب', 'is_active' => true]);
        $child1 = Category::create(['parent_id' => $root->id, 'name_en' => 'A', 'name_ar' => 'أ', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child1->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);

        $ordered = Category::orderByHierarchy()->pluck('id')->toArray();

        // Root should come first, then its children by path, then grandchildren
        $rootIndex = array_search($root->id, $ordered);
        $grandchildIndex = array_search($grandchild->id, $ordered);

        expect($rootIndex)->toBeLessThan($grandchildIndex);
    });
});

/*
|--------------------------------------------------------------------------
| Category archive and restore
|--------------------------------------------------------------------------
*/

describe('Archive and restore', function () {

    it('archive soft-deletes category and all descendants', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);
        $grandchild = Category::create(['parent_id' => $child->id, 'name_en' => 'GC', 'name_ar' => 'حفيد', 'is_active' => true]);
        $unrelated = Category::create(['name_en' => 'Unrelated', 'name_ar' => 'غير مرتبط', 'is_active' => true]);

        $root->archive();

        // Root and descendants should be soft deleted
        expect(Category::find($root->id))->toBeNull()
            ->and(Category::find($child->id))->toBeNull()
            ->and(Category::find($grandchild->id))->toBeNull()
            // But still exist in trashed
            ->and(Category::withTrashed()->find($root->id))->not->toBeNull()
            ->and(Category::withTrashed()->find($child->id))->not->toBeNull()
            // Unrelated should not be affected
            ->and(Category::find($unrelated->id))->not->toBeNull();
    });

    it('restoreWithDescendants restores category and all descendants', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $child = Category::create(['parent_id' => $root->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

        $root->archive();

        expect(Category::find($root->id))->toBeNull()
            ->and(Category::find($child->id))->toBeNull();

        // Restore with descendants
        Category::withTrashed()->find($root->id)->restoreWithDescendants();

        expect(Category::find($root->id))->not->toBeNull()
            ->and(Category::find($child->id))->not->toBeNull();
    });
});

/*
|--------------------------------------------------------------------------
| Wide trees (multiple siblings)
|--------------------------------------------------------------------------
*/

describe('Wide trees with multiple siblings', function () {

    it('sibling categories maintain independent paths', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $sibling1 = Category::create(['parent_id' => $root->id, 'name_en' => 'S1', 'name_ar' => 'ش1', 'is_active' => true]);
        $sibling2 = Category::create(['parent_id' => $root->id, 'name_en' => 'S2', 'name_ar' => 'ش2', 'is_active' => true]);
        $sibling3 = Category::create(['parent_id' => $root->id, 'name_en' => 'S3', 'name_ar' => 'ش3', 'is_active' => true]);

        expect($sibling1->fresh()->path)->toBe("{$root->id}/{$sibling1->id}")
            ->and($sibling2->fresh()->path)->toBe("{$root->id}/{$sibling2->id}")
            ->and($sibling3->fresh()->path)->toBe("{$root->id}/{$sibling3->id}");
    });

    it('SP attached to one sibling does not appear when querying another sibling', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $sibling1 = Category::create(['parent_id' => $root->id, 'name_en' => 'S1', 'name_ar' => 'ش1', 'is_active' => true]);
        $sibling2 = Category::create(['parent_id' => $root->id, 'name_en' => 'S2', 'name_ar' => 'ش2', 'is_active' => true]);

        $sp1 = createTestSp([$sibling1->id]);

        $results = ServiceProvider::available()
            ->forCategoryWithAncestors($sibling2->id)
            ->pluck('id')
            ->toArray();

        // SP1 is attached to sibling1, not sibling2 or their parent
        expect($results)->not->toContain($sp1->id);
    });

    it('SP attached to parent appears for all sibling children', function () {
        $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);
        $sibling1 = Category::create(['parent_id' => $root->id, 'name_en' => 'S1', 'name_ar' => 'ش1', 'is_active' => true]);
        $sibling2 = Category::create(['parent_id' => $root->id, 'name_en' => 'S2', 'name_ar' => 'ش2', 'is_active' => true]);

        $rootSp = createTestSp([$root->id]);

        $results1 = ServiceProvider::available()
            ->forCategoryWithAncestors($sibling1->id)
            ->pluck('id')
            ->toArray();

        $results2 = ServiceProvider::available()
            ->forCategoryWithAncestors($sibling2->id)
            ->pluck('id')
            ->toArray();

        expect($results1)->toContain($rootSp->id)
            ->and($results2)->toContain($rootSp->id);
    });
});

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function createTestSp(array $categoryIds, bool $isAvailable = true): ServiceProvider
{
    $user = User::factory()->create([
        'password' => Hash::make('password'),
        'is_active' => true,
    ]);
    $user->assignRole('service_provider');

    $sp = ServiceProvider::create([
        'user_id' => $user->id,
        'is_available' => $isAvailable,
    ]);
    $sp->categories()->attach($categoryIds);

    return $sp;
}
