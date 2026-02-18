<?php

declare(strict_types=1);

use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

// =========================================================================
// Helper to create an SP linked to given categories
// =========================================================================
function createSp(array $categoryIds, bool $isAvailable = true): ServiceProvider
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

beforeEach(function () {
    ensureRolesExist();
});

// =========================================================================
// 1. getAncestorIds() on Category model
// =========================================================================

test('getAncestorIds returns empty array for root category', function () {
    $root = Category::create(['name_en' => 'Root', 'name_ar' => 'جذر', 'is_active' => true]);

    expect($root->fresh()->getAncestorIds())->toBe([]);
});

test('getAncestorIds returns parent ID for 1-level deep child', function () {
    $parent = Category::create(['name_en' => 'Parent', 'name_ar' => 'أب', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Child', 'name_ar' => 'طفل', 'is_active' => true]);

    expect($child->fresh()->getAncestorIds())->toBe([$parent->id]);
});

test('getAncestorIds returns full ancestor chain for 3-level hierarchy', function () {
    $grandparent = Category::create(['name_en' => 'GP', 'name_ar' => 'جد', 'is_active' => true]);
    $parent = Category::create(['parent_id' => $grandparent->id, 'name_en' => 'P', 'name_ar' => 'أب', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'C', 'name_ar' => 'طفل', 'is_active' => true]);

    $ancestorIds = $child->fresh()->getAncestorIds();

    expect($ancestorIds)->toBe([$grandparent->id, $parent->id]);
});

test('getAncestorIds returns empty for category with null path', function () {
    $cat = Category::create(['name_en' => 'Test', 'name_ar' => 'اختبار', 'is_active' => true]);
    // Force null path for edge case
    Category::withoutEvents(fn () => $cat->update(['path' => null]));

    expect($cat->fresh()->getAncestorIds())->toBe([]);
});

// =========================================================================
// 2. scopeForCategoryWithAncestors - basic 2-level hierarchy
// =========================================================================

test('child category query returns SPs from parent category', function () {
    $parent = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);

    $parentSp = createSp([$parent->id]);
    $childSp = createSp([$child->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($child->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($parentSp->id)
        ->and($results)->toContain($childSp->id);
});

test('parent category query does NOT return child-only SPs', function () {
    $parent = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);

    $parentSp = createSp([$parent->id]);
    $childSp = createSp([$child->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($parent->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($parentSp->id)
        ->and($results)->not->toContain($childSp->id);
});

// =========================================================================
// 3. scopeForCategoryWithAncestors - deep 3-level hierarchy
// =========================================================================

test('grandchild category returns SPs from all ancestors', function () {
    $gp = Category::create(['name_en' => 'HVAC', 'name_ar' => 'تكييف', 'is_active' => true]);
    $parent = Category::create(['parent_id' => $gp->id, 'name_en' => 'Cooling', 'name_ar' => 'تبريد', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'AC Units', 'name_ar' => 'مكيفات', 'is_active' => true]);

    $gpSp = createSp([$gp->id]);
    $parentSp = createSp([$parent->id]);
    $childSp = createSp([$child->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($child->id)
        ->pluck('id')
        ->toArray();

    expect($results)
        ->toContain($gpSp->id)
        ->toContain($parentSp->id)
        ->toContain($childSp->id);
});

test('middle-level category returns grandparent SP but not grandchild SP', function () {
    $gp = Category::create(['name_en' => 'HVAC', 'name_ar' => 'تكييف', 'is_active' => true]);
    $parent = Category::create(['parent_id' => $gp->id, 'name_en' => 'Cooling', 'name_ar' => 'تبريد', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'AC Units', 'name_ar' => 'مكيفات', 'is_active' => true]);

    $gpSp = createSp([$gp->id]);
    $childSp = createSp([$child->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($parent->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($gpSp->id)
        ->and($results)->not->toContain($childSp->id);
});

// =========================================================================
// 4. Unrelated categories should not leak into results
// =========================================================================

test('SPs from unrelated categories are NOT included', function () {
    $electrical = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $wiring = Category::create(['parent_id' => $electrical->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);
    $plumbing = Category::create(['name_en' => 'Plumbing', 'name_ar' => 'سباكة', 'is_active' => true]);

    $electricalSp = createSp([$electrical->id]);
    $plumbingSp = createSp([$plumbing->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($wiring->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($electricalSp->id)
        ->and($results)->not->toContain($plumbingSp->id);
});

// =========================================================================
// 5. SP assigned to multiple categories
// =========================================================================

test('SP assigned to both parent and child appears only once', function () {
    $parent = Category::create(['name_en' => 'General', 'name_ar' => 'عام', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Specific', 'name_ar' => 'محدد', 'is_active' => true]);

    $sp = createSp([$parent->id, $child->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($child->id)
        ->pluck('id')
        ->toArray();

    // Should appear once, not duplicated
    expect($results)->toContain($sp->id)
        ->and(array_count_values($results)[$sp->id])->toBe(1);
});

test('SP assigned to unrelated + parent category appears when filtering by child', function () {
    $parent = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);
    $plumbing = Category::create(['name_en' => 'Plumbing', 'name_ar' => 'سباكة', 'is_active' => true]);

    $multiSp = createSp([$parent->id, $plumbing->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($child->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($multiSp->id);
});

// =========================================================================
// 6. Unavailable SPs are excluded
// =========================================================================

test('unavailable SPs are excluded even if category matches', function () {
    $parent = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);

    $unavailableSp = createSp([$parent->id], isAvailable: false);
    $availableSp = createSp([$parent->id], isAvailable: true);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($child->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($availableSp->id)
        ->and($results)->not->toContain($unavailableSp->id);
});

// =========================================================================
// 7. Non-existent category ID
// =========================================================================

test('non-existent category ID returns no results', function () {
    $results = ServiceProvider::available()
        ->forCategoryWithAncestors(99999)
        ->pluck('id')
        ->toArray();

    expect($results)->toBe([]);
});

// =========================================================================
// 8. Root category with no parent
// =========================================================================

test('root category with no ancestors returns only its own SPs', function () {
    $root = Category::create(['name_en' => 'Maintenance', 'name_ar' => 'صيانة', 'is_active' => true]);
    $other = Category::create(['name_en' => 'Cleaning', 'name_ar' => 'تنظيف', 'is_active' => true]);

    $rootSp = createSp([$root->id]);
    $otherSp = createSp([$other->id]);

    $results = ServiceProvider::available()
        ->forCategoryWithAncestors($root->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($rootSp->id)
        ->and($results)->not->toContain($otherSp->id);
});

// =========================================================================
// 9. Original forCategory scope unchanged (regression)
// =========================================================================

test('original forCategory scope returns only exact match', function () {
    $parent = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);

    $parentSp = createSp([$parent->id]);
    $childSp = createSp([$child->id]);

    $results = ServiceProvider::available()
        ->forCategory($child->id)
        ->pluck('id')
        ->toArray();

    expect($results)->toContain($childSp->id)
        ->and($results)->not->toContain($parentSp->id);
});

// =========================================================================
// 10. API endpoint - category_id filter with ancestors
// =========================================================================

test('API service providers endpoint includes ancestor category SPs', function () {
    ensurePermissionsExist();

    $parent = Category::create(['name_en' => 'Electrical', 'name_ar' => 'كهربائي', 'is_active' => true]);
    $child = Category::create(['parent_id' => $parent->id, 'name_en' => 'Wiring', 'name_ar' => 'أسلاك', 'is_active' => true]);

    $parentSp = createSp([$parent->id]);
    $childSp = createSp([$child->id]);

    $admin = createAdminUser('super_admin');

    $response = $this->withHeaders(authHeaders($admin))
        ->getJson("/api/v1/admin/service-providers?category_id={$child->id}");

    $response->assertStatus(200);

    $spIds = collect($response->json('data'))->pluck('id')->toArray();

    expect($spIds)->toContain($parentSp->id)
        ->and($spIds)->toContain($childSp->id);
});

test('API service providers endpoint without category_id returns all', function () {
    ensurePermissionsExist();

    $cat1 = Category::create(['name_en' => 'Cat1', 'name_ar' => 'فئة1', 'is_active' => true]);
    $cat2 = Category::create(['name_en' => 'Cat2', 'name_ar' => 'فئة2', 'is_active' => true]);

    $sp1 = createSp([$cat1->id]);
    $sp2 = createSp([$cat2->id]);

    $admin = createAdminUser('super_admin');

    $response = $this->withHeaders(authHeaders($admin))
        ->getJson('/api/v1/admin/service-providers');

    $response->assertStatus(200);

    $spIds = collect($response->json('data'))->pluck('id')->toArray();

    expect($spIds)->toContain($sp1->id)
        ->and($spIds)->toContain($sp2->id);
});
