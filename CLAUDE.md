# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Facility maintenance management system for a single community with:
- **Backend**: Laravel 12 + Filament v5 admin panel (`backend/`)
- **Mobile App**: Flutter with offline-first architecture (`mobile_new/`)
- **Languages**: Arabic + English with RTL support
- **Theme**: Dark/Light mode compatible
- **Access**: Dynamic, permission-based UI

## Commands

### Backend (run from `backend/` directory)
```bash
composer dev                   # Development (server, queue, logs, Vite)
php artisan serve              # Laravel dev server
npm run dev                    # Vite dev server with HMR
php artisan migrate            # Run migrations
php artisan db:seed            # Seed database
composer test                  # Run Pest tests
php artisan pint               # Fix code style
```

### Mobile (run from `mobile_new/` directory)
```bash
flutter pub get                # Install packages
flutter run                    # Run on device/emulator
flutter build apk              # Build Android APK
flutter analyze                # Lint and analyze code
dart format lib/               # Format code
flutter test                   # Run all tests
dart run build_runner build --delete-conflicting-outputs  # Code generation
```

---

## Architecture

### Backend Structure
- **Filament v5**: Admin panel at `/admin` with Shield for role-based permissions
- **API**: JWT-authenticated REST API at `/api/v1`
- **Patterns**: Actions (`app/Actions/`), DTOs (`app/DTOs/`), Services (`app/Services/`), Form Requests, API Resources

### Mobile Structure (Clean Architecture)
```
lib/
├── core/          # api/, network/, services/, storage/, sync/, router/, theme/, extensions/
├── domain/        # entities/, enums/
├── data/          # datasources/, local/, models/, repositories/
├── presentation/  # screens/{admin,tenant,service_provider}/, widgets/, providers/
└── l10n/          # Localization
```

---

## Roles and Permissions

| Role | Platform | Capabilities |
|------|----------|--------------|
| **Super Admin** | Web | Full access to all features |
| **Manager** | Web | Manage issues, users, settings (no Shield config) |
| **Viewer** | Web | Read-only access to admin panel |
| **Tenant** | Mobile | Create issues, track progress |
| **Service Provider** | Mobile | Receive assignments, execute work |

---

## Backend Standards

### Filament v5 Namespaces (CRITICAL)
```php
// Resource Forms - Import Forms facade and use Forms\Components\*
use Filament\Forms;                                 // Import Forms facade
use Filament\Schemas\Components\Section;           // For sections
use Filament\Schemas\Components\Utilities\Get;     // For reactive forms
use Filament\Schemas\Components\Utilities\Set;     // For reactive forms
use Filament\Schemas\Components\Tabs\Tab;          // For tabs

// In resource form() method - use Forms\Components\*
Forms\Components\TextInput::make('name')            // NOT Filament\Schemas\Components\TextInput
Forms\Components\Textarea::make('description')
Forms\Components\Select::make('category')
Forms\Components\Toggle::make('is_active')

// Table Actions - Import from Filament\Actions (NOT Tables\Actions)
use Filament\Actions\ViewAction;                   // NOT Tables\Actions\ViewAction
use Filament\Actions\EditAction;                   // NOT Tables\Actions\EditAction
use Filament\Actions\DeleteAction;                 // NOT Tables\Actions\DeleteAction
use Filament\Actions\DeleteBulkAction;             // NOT Tables\Actions\DeleteBulkAction
use Filament\Actions\BulkActionGroup;              // NOT Tables\Actions\BulkActionGroup
use Filament\Actions\Action;                       // For custom actions

// Action Forms - Use Forms\Components (NOT Schemas\Components)
use Filament\Forms\Components\Textarea;            // NOT Schemas\Components\Textarea
use Filament\Forms\Components\TextInput;           // NOT Schemas\Components\TextInput
use Filament\Forms\Components\Select;              // NOT Schemas\Components\Select (for action forms)

// Resource Property Types
protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-icon';
protected static string|Htmlable|null $navigationBadgeTooltip = 'Tooltip';

// Usage in table - NO Tables\Actions prefix needed
->actions([
    ViewAction::make(),                             // NOT Tables\Actions\ViewAction::make()
    Action::make('custom')                          // NOT Tables\Actions\Action::make()
        ->form([
            Textarea::make('notes'),                // Filament\Forms\Components\Textarea
        ]),
])
```

### Common Filament v5 Errors & Fixes

| Error | Wrong Code | Fix |
|-------|-----------|-----|
| `Class "Filament\Tables\Actions\ViewAction" not found` | `Tables\Actions\ViewAction::make()` | Import `use Filament\Actions\ViewAction;` and use `ViewAction::make()` |
| `Class "Filament\Schemas\Components\TextInput" not found` | Using Schemas\Components in resource forms | Import `use Filament\Forms;` and use `Forms\Components\TextInput` |
| `Class "Filament\Schemas\Components\Textarea" not found` | Using Schemas for action forms | Import `use Filament\Forms\Components\Textarea;` for action forms |
| `Type of $navigationIcon must be BackedEnum\|string\|null` | `protected static ?string $navigationIcon` | Use `protected static string\|BackedEnum\|null $navigationIcon` |
| `Type of $navigationBadgeTooltip must be Htmlable\|string\|null` | `protected static ?string $navigationBadgeTooltip` | Import `Illuminate\Contracts\Support\Htmlable` and use `string\|Htmlable\|null` |
| Translation keys showing in nav (e.g., `work_types.plural`) | Missing translation file | Create `lang/en/work_types.php` and `lang/ar/work_types.php` with proper keys |

### Resource Pattern
```php
class ModelResource extends Resource
{
    // ALWAYS use translation helpers
    public static function getNavigationGroup(): ?string { return __('navigation.*'); }
    public static function getModelLabel(): string { return __('model.singular'); }
    public static function getPluralModelLabel(): string { return __('model.plural'); }
}
```

### Enum Standards
```php
enum Status: string {
    case PENDING = 'pending';

    // REQUIRED methods
    public function label(): string { return match($this) { self::PENDING => __('status.pending') }; }
    public function color(): string { return match($this) { self::PENDING => 'warning' }; }
    public function icon(): string { return match($this) { self::PENDING => 'heroicon-o-clock' }; }
    public static function options(): array { return collect(self::cases())->mapWithKeys(fn($s) => [$s->value => $s->label()])->toArray(); }
}
```

### Permission-Based Access (Shield)
```php
// Policy: return $authUser->can('ViewAny:Issue');
// Action: ->visible(fn() => auth()->user()->can('approve_issues'))
// Page: public static function canAccess(): bool { return auth()->user()?->can('permission') ?? false; }
```

### API Response Standards
```php
// Success: { "success": true, "data": {...}, "message": "..." }
// Paginated: { "success": true, "data": [...], "meta": {...}, "links": {...} }
// Error: { "success": false, "message": "...", "errors": {...} }
```

### File Header Convention
```php
<?php
declare(strict_types=1);
namespace App\Namespace;
```

---

## Mobile Standards

### ZERO TOLERANCE POLICIES (MANDATORY)

| Rule | Wrong | Correct |
|------|-------|---------|
| Colors | `Colors.blue` | `AppColors.primary` or `context.colors.primary` |
| Spacing | `SizedBox(height: 16)` | `AppSpacing.vGapLg` |
| Padding | `EdgeInsets.all(16)` | `AppSpacing.allLg` |
| Radius | `BorderRadius.circular(8)` | `AppRadius.cardAll` |
| Shadows | `BoxShadow(...)` | `AppShadows.card` |
| Text | `'Submit'` | `'common.submit'.tr()` |
| State | `setState()` in ConsumerWidget | Use Riverpod providers |
| Icons | `Icons.home_outlined` | `Icons.home_rounded` (always use `_rounded` variants) |
| Loading | `CircularProgressIndicator()` | Use shimmer/skeleton placeholders |

### Theme System Locations
- Colors: `lib/core/theme/app_colors.dart` (status, priority, sync colors with bg variants)
- Typography: `lib/core/theme/app_typography.dart` (Inter/Cairo fonts)
- Spacing: `lib/core/theme/app_spacing.dart` (xs=4, sm=8, md=12, lg=16, xl=24, xxl=32)
- Radius: `lib/core/theme/app_radius.dart`
- Shadows: `lib/core/theme/app_shadows.dart`
- Extensions: `lib/core/extensions/context_extensions.dart`

### Permission Widgets
```dart
PermissionGate(allowedRoles: [UserRole.superAdmin], child: ...)
CanManageGate(child: ...)    // superAdmin + manager
SuperAdminGate(child: ...)   // superAdmin only
PermissionBasedGate(permission: 'approve_issues', child: ...)
```

### Permission Providers
```dart
ref.watch(hasPermissionProvider('create_issues'))
ref.watch(canViewIssuesProvider)
ref.watch(isTenantProvider)
```

### State Management (Riverpod)
- Always use `ConsumerWidget` or `ConsumerStatefulWidget`
- State: `ref.watch()` for reactive UI
- Actions: `ref.read()` for one-time reads
- Auth: `authStateProvider`, `currentUserProvider`, `userRoleProvider`

### Localization
```dart
'nav.home'.tr()
'tenant.hello'.tr(namedArgs: {'name': userName})
// Use EdgeInsetsDirectional and BorderRadiusDirectional for RTL
```

### Offline-First Architecture (CRITICAL)

This app is designed for Saudi users with limited/unreliable internet. **ALL features must work offline first.**

#### Core Principle
```
User Action → Save to Hive → Update UI immediately → Queue for sync → Sync when online
```

#### Key Components
| Component | Location | Purpose |
|-----------|----------|---------|
| Hive Models | `lib/data/local/adapters/` | Local storage with sync metadata |
| Sync Queue | `lib/core/sync/sync_queue_service.dart` | Queue operations for later sync |
| Local Datasources | `lib/data/datasources/*_local_datasource.dart` | CRUD on Hive |
| Repositories | `lib/data/repositories/` | Coordinate local + remote |

#### Connectivity Providers
```dart
ref.watch(isOnlineProvider)           // Current status
ref.watch(connectivityStreamProvider) // Stream of changes
OfflineBanner()                       // Show when offline
SyncStatusIndicator(status: syncStatus) // Show sync state on items
```

---

## Offline-First Patterns (MUST FOLLOW)

### 1. Hive Model `toModel()` Pattern (CRITICAL BUG PREVENTION)

When Hive models have `fullDataJson` (cached server response), the `toModel()` method MUST overlay local fields:

```dart
// ❌ WRONG - loses offline changes
IssueModel toModel() {
  if (fullDataJson != null) {
    return IssueModel.fromJson(jsonDecode(fullDataJson!));
  }
}

// ✅ CORRECT - preserves offline changes
IssueModel toModel() {
  if (fullDataJson != null) {
    return IssueModel.fromJson(jsonDecode(fullDataJson!)).copyWith(
      syncStatus: syncStatusEnum,
      localId: localId,
      // CRITICAL: Copy ALL locally-modifiable fields
      status: statusEnum,
      priority: priorityEnum,
      // ... other fields that can change offline
    );
  }
}
```

**Affected models:** `issue_hive_model.dart`, `assignment_hive_model.dart`, `tenant_hive_model.dart`, `service_provider_hive_model.dart`

### 2. Merge Pattern - Preserve Pending Sync

When refreshing data from server, NEVER overwrite local items with pending sync:

```dart
// ❌ WRONG - loses pending changes
void _mergeData(List<Model> serverData) {
  state = state.copyWith(items: serverData);
}

// ✅ CORRECT - preserve pending sync items
void _mergeData(List<Model> serverData) {
  final pendingItems = <int, Model>{};
  for (final item in state.items) {
    if (item.syncStatus != SyncStatus.synced) {
      pendingItems[item.id] = item;
    }
  }

  final merged = serverData.map((server) {
    final pending = pendingItems[server.id];
    return pending ?? server; // Prefer local if pending
  }).toList();

  state = state.copyWith(items: merged);
}
```

### 3. Repository `getById` Pattern

When fetching single item, check for pending sync before updating from server:

```dart
Future<Model?> getItem(int id) async {
  final cached = await _localDs.getItem(id);

  // DON'T overwrite if local has pending changes
  if (cached != null && cached.needsSync) {
    return cached.toModel();
  }

  // Safe to fetch from server
  if (isOnline) {
    final remote = await _remoteDs.getItem(id);
    await _localDs.saveItem(remote);
    return remote;
  }

  return cached?.toModel();
}
```

### 4. Local Issue Navigation

Offline-created issues have negative IDs. Handle navigation:

```dart
// In lists
onTap: () {
  if (issue.id > 0) {
    context.push('/tenant/issues/${issue.id}');
  } else if (issue.localId != null) {
    context.push('/tenant/issues/local/${issue.localId}');
  }
}

// Router has both routes:
// /tenant/issues/:id         - Server issues
// /tenant/issues/local/:localId - Local issues
```

### 5. Sync Queue User Context

Sync operations are tied to the user who created them:

```dart
// Operations store userId
final operation = SyncOperation.create(
  // ...
  userId: currentUserId, // Tracked automatically
);

// Queue skips operations from other users
if (operation.userId != null && operation.userId != currentUserId) {
  continue; // Skip - different user
}
```

### 6. Sync Retry Reset on Connectivity

When coming back online, reset retry counts to avoid backoff delays:

```dart
// In connectivity listener
if (isOnline) {
  await service.resetRetryCountsForOnlineRecovery();
  service.processQueue();
}
```

---

## Sync Status Enum

```dart
enum SyncStatus {
  synced,   // Data matches server
  pending,  // Local changes waiting to sync
  syncing,  // Currently syncing
  failed,   // Sync failed (will retry)
}

// Check if needs sync
bool get needsSync => syncStatus != SyncStatus.synced;
```

---

## Common Offline Bugs & Fixes

| Bug | Cause | Fix |
|-----|-------|-----|
| Offline changes not showing | `toModel()` reads from `fullDataJson` | Copy local fields in `copyWith()` |
| Changes lost on refresh | `_merge` overwrites pending sync | Check `needsSync` before replacing |
| "Invalid Issue ID" for local issues | Negative ID rejected | Use `/local/:localId` route |
| Sync waits 16s when online | Exponential backoff from offline | Reset retry counts on connectivity |
| 403 on sync after user switch | Wrong user's token | Store/check `userId` on operations |
| Duplicate issues after sync | Old localId key + new server_* key | Call `migrateToServerKey()` after sync, dedupe by serverId |

---

## API Integration & Type Safety (CRITICAL)

### Backend: Always provide defaults
```php
'description' => $this->description ?? '',
'images' => $this->images?->toArray() ?? [],
'count' => $this->count ?? 0,
```

### Flutter: Defensive parsing
```dart
id: _parseInt(json['id']) ?? 0,
title: json['title']?.toString() ?? '',
images: (json['images'] as List?)?.whereType<Map<String, dynamic>>().map((e) => ImageModel.fromJson(e)).toList() ?? [],
tenant: json['tenant'] != null ? TenantModel.fromJson(json['tenant']) : null,

static int? _parseInt(dynamic v) => v is int ? v : v is String ? int.tryParse(v) : null;
```

### Common Errors
| Error | Fix |
|-------|-----|
| `Null is not subtype of int` | Use `?? 0` default |
| `String is not subtype of int` | Use `_parseInt()` helper |
| `List<dynamic>` cast error | Use `.whereType<Map<String, dynamic>>()` |

---

## Testing & Credentials

### Backend Test Helpers (`tests/Pest.php`)
- `createUser()`, `createTenantUser()`, `createServiceProviderUser()`
- `createAdminUser($role)` - super_admin, manager, viewer
- `getAuthToken($user)`, `authHeaders($user)`

### Demo Credentials
| Role | Email | Password |
|------|-------|----------|
| Tenant | tenant1@maintenance.local | password |
| Service Provider | plumber@maintenance.local | password |
| Super Admin | admin@maintenance.local | password |

---

## Naming Conventions

### Backend
Models: `Issue`, Actions: `ApproveIssueAction`, Enums: `IssueStatus`, Controllers: `AdminIssueController`

### Mobile
Files: `snake_case.dart`, Classes: `PascalCase`, Providers: `camelCaseProvider`

---

## Quick Reference

### New Filament Resource
1. `php artisan make:filament-resource Model`
2. Add translations to `lang/{en,ar}/model.php`
3. Create policy with Shield permissions
4. Use Section grouping, searchable/sortable columns

### New Mobile Screen
1. Create in `lib/presentation/screens/{role}/`
2. Use `ConsumerWidget`, `AppColors`, `AppSpacing` - NO hardcoded values
3. Wrap with `PermissionGate` if needed
4. All text via `.tr()` localization


---

## Critical Notes

1. **Image Compression**: Mobile compresses before upload (70% quality, max 1920x1080)
2. **Code Generation**: Run `dart run build_runner build --delete-conflicting-outputs` after modifying providers/Freezed models
3. **Hive Adapters**: Manual adapters (hive_generator conflicts with riverpod_generator)
4. **Connectivity**: Use `ConnectivityService.isOnline` with `.any()` pattern
5. **Offline-First**: ALWAYS save to Hive first, then queue for sync. UI must reflect local state immediately.
6. **Hive toModel()**: When editing Hive models with `fullDataJson`, ALWAYS copy local fields in `toModel().copyWith()`
7. **Sync Queue**: Operations are user-specific. Never clear queue on logout - operations wait for correct user.
8. **Local IDs**: Offline-created items use negative IDs (`-localId.hashCode.abs()`). Handle in navigation and display.
9. **Pending Sync**: Never overwrite items where `syncStatus != synced` with server data during refresh/merge operations.
