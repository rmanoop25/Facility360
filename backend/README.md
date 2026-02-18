# Facility360 — Backend

Laravel 12 + Filament v5 admin panel for managing facility maintenance issues with role-based access control and an offline-first mobile API.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Database Setup](#database-setup)
- [Running the Application](#running-the-application)
- [Default Credentials](#default-credentials)
- [Available Commands](#available-commands)
- [Testing](#testing)
- [Roles & Permissions](#roles--permissions)
- [API Documentation](#api-documentation)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

---

## Features

- **Multi-language Support**: English and Arabic with RTL layout
- **Role-Based Access Control**: Super Admin, Manager, Viewer, Tenant, Service Provider
- **Issue Lifecycle Management**: Create, assign, track, and complete maintenance issues with a full timeline history
- **Service Provider Scheduling**: Time slot management with availability checking
- **Time Extension Workflow**: Service providers can request deadline extensions; admins approve or reject
- **Offline-First Sync API**: Batch sync and master data endpoints for reliable mobile operation on unreliable networks
- **File Uploads**: Image and document attachments stored via Laravel's file storage
- **Real-Time Push Notifications**: Firebase Cloud Messaging (FCM) via `kreait/laravel-firebase`
- **Dashboard & Reporting**: Stats widgets, calendar view, and analytics
- **JWT Authentication**: Secure token-based API authentication for the mobile app
- **Filament v5 Admin Panel**: Modern, responsive admin interface with FilamentShield permissions

---

## Tech Stack

| Layer | Package / Version |
|---|---|
| **Framework** | Laravel 12 |
| **Admin Panel** | Filament v5 |
| **Database** | MySQL 8.0+ |
| **Authentication** | `php-open-source-saver/jwt-auth` v2.8 |
| **Permissions** | Spatie Laravel-Permission v6.24 + FilamentShield v4 |
| **Data / DTOs** | Spatie Laravel-Data v4.18 |
| **Settings** | Spatie Laravel-Settings v3.6 |
| **Translatable** | Spatie Laravel-Translatable v6.12 |
| **Push Notifications** | kreait/laravel-firebase v6.2 (FCM) |
| **Maps** | cheesegrits/filament-google-maps v5 |
| **Calendar** | filament-fullcalendar (local package) |
| **Frontend** | Vite + Tailwind CSS v4 |
| **Queue** | Laravel Queue (database driver) |
| **Testing** | Pest v3 + PHPUnit v11 |
| **Code Style** | Laravel Pint v1 |

---

## Prerequisites

- **PHP**: 8.2 or higher
- **Composer**: 2.x
- **Node.js**: 18.x or higher
- **npm**: 9.x or higher
- **MySQL**: 8.0 or higher

**Required PHP Extensions:** BCMath, Ctype, cURL, DOM, Fileinfo, JSON, Mbstring, OpenSSL, PDO, PDO_MySQL, Tokenizer, XML, GD or Imagick

---

## Installation

### Quick Setup (one command)

```bash
composer setup
```

This runs `composer install`, copies `.env.example`, generates the app key, runs migrations, installs npm packages, and builds frontend assets.

### Manual Setup

#### 1. Clone the repository

```bash
git clone <repository-url>
cd AppartmentManagement/backend
```

#### 2. Install PHP dependencies

```bash
composer install
```

#### 3. Install Node dependencies

```bash
npm install
```

#### 4. Copy environment file

```bash
# Linux/macOS
cp .env.example .env

# Windows
copy .env.example .env
```

---

## Configuration

### 1. Generate application key

```bash
php artisan key:generate
```

### 2. Configure database

Edit `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=facility360
DB_USERNAME=your_username
DB_PASSWORD=your_password
```

### 3. Generate JWT secret

```bash
php artisan jwt:secret
```

### 4. Create storage symlink

```bash
php artisan storage:link
```

### 5. Configure Firebase (FCM push notifications)

Add your Firebase service account credentials to `.env`:

```env
FIREBASE_CREDENTIALS=/absolute/path/to/firebase-credentials.json
```

Or set the path in `config/firebase.php`. See the [kreait/laravel-firebase docs](https://github.com/kreait/laravel-firebase) for full setup.

### 6. Configure mail (optional)

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_username
MAIL_PASSWORD=your_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@facility360.local"
MAIL_FROM_NAME="${APP_NAME}"
```

---

## Database Setup

### 1. Create the database

```sql
CREATE DATABASE facility360 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. Run migrations

```bash
php artisan migrate
```

### 3. Seed default data

```bash
php artisan db:seed
```

Seeds: roles & permissions, admin users, sample categories, tenants, service providers, and sample issues.

### 4. Regenerate FilamentShield permissions (after adding new resources)

```bash
php artisan shield:generate --all
php artisan db:seed --class=RolesAndPermissionsSeeder
```

---

## Running the Application

### Development (recommended)

```bash
composer dev
```

Concurrently starts:
- Laravel dev server — `http://localhost:8000`
- Queue worker
- Log viewer (Pail)
- Vite dev server with HMR

### Individual services

```bash
# Terminal 1
php artisan serve

# Terminal 2
php artisan queue:work

# Terminal 3
npm run dev
```

### Production

```bash
npm run build
php artisan optimize
php artisan filament:optimize
```

---

## Default Credentials

### Admin panel (`/admin`)

| Role | Email | Password |
|------|-------|----------|
| **Super Admin** | admin@maintenance.local | password |
| **Manager** | manager@maintenance.local | password |
| **Viewer** | viewer@maintenance.local | password |

### Mobile app (API)

| Role | Email | Password |
|------|-------|----------|
| **Tenant** | tenant1@maintenance.local | password |
| **Service Provider** | sp1@maintenance.local | password |

---

## Available Commands

### Development

```bash
composer dev               # Start all services
php artisan serve          # Laravel server only
npm run dev                # Vite dev server
npm run build              # Build for production
```

### Database

```bash
php artisan migrate                                        # Run migrations
php artisan migrate --seed                                 # Migrate and seed
php artisan migrate:fresh --seed                          # Drop all and re-run
php artisan db:seed --class=RolesAndPermissionsSeeder     # Re-seed permissions
```

### Code Quality

```bash
vendor/bin/pint --dirty    # Fix code style (changed files only)
vendor/bin/pint            # Fix all files
vendor/bin/pint --check    # Check without fixing
```

### Testing

```bash
composer test                                     # Run all tests
php artisan test --compact                        # Compact output
php artisan test --compact --filter=testName      # Filter by name
php artisan test --testsuite=Feature              # Feature tests only
```

### Cache

```bash
php artisan optimize:clear    # Clear all caches
php artisan config:cache      # Cache config (production)
php artisan route:cache       # Cache routes (production)
php artisan filament:optimize # Optimize Filament
```

### Permissions

```bash
php artisan shield:generate --all        # Generate permissions for all resources
php artisan shield:super-admin           # Promote a user to super admin
```

### Utilities

```bash
php artisan route:list          # List all routes
php artisan jwt:secret --force  # Regenerate JWT secret
php artisan storage:link        # Recreate storage symlink
php artisan queue:failed        # List failed jobs
php artisan queue:retry all     # Retry all failed jobs
```

---

## Testing

Tests live in `tests/Feature/` and `tests/Unit/`, using **Pest v3**.

### Test helpers (`tests/Pest.php`)

```php
createUser()                      // Basic authenticated user
createAdminUser('manager')        // Admin with specific role
createTenantUser()                // Tenant mobile user
createServiceProviderUser()       // Service provider mobile user
getAuthToken($user)               // Get JWT token
authHeaders($user)                // Get Authorization headers array
```

### Example

```php
test('manager can assign issues', function () {
    $manager = createAdminUser('manager');
    $issue = Issue::factory()->create(['status' => IssueStatus::PENDING]);

    actingAs($manager)
        ->postJson("/api/v1/admin/issues/{$issue->id}/assign", [
            'service_provider_id' => ServiceProvider::factory()->create()->id,
        ])
        ->assertSuccessful();
});
```

Tests run against an in-memory SQLite database (configured in `phpunit.xml`).

---

## Roles & Permissions

| Role | Platform | Description |
|------|----------|-------------|
| **Super Admin** | Web | Full access — all CRUD, all permissions |
| **Manager** | Web | Manage issues, assign work, approve completions |
| **Viewer** | Web | Read-only access to issues and reports |
| **Tenant** | Mobile | Report issues, track their own issues |
| **Service Provider** | Mobile | View assignments, execute and complete work |

### Custom permissions (managed via FilamentShield)

- `assign_issues` — Assign issues to service providers
- `approve_issues` — Approve completed work
- `cancel_issues` — Cancel issues
- `view_reports` — Access reporting/statistics

### Permission management

Admin panel: `/admin/shield/roles`

```php
$user->assignRole('manager');
$user->can('assign_issues');
$user->hasRole('super_admin');
```

---

## API Documentation

### Base URL

```
/api/v1
```

### Authentication

```http
POST /api/v1/auth/login
Content-Type: application/json

{ "email": "admin@maintenance.local", "password": "password" }
```

Response:
```json
{
  "success": true,
  "access_token": "eyJ0eXAiOiJKV1Qi...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

All protected routes require:
```http
Authorization: Bearer {access_token}
```

### Response envelope

```json
{ "success": true, "data": { ... }, "message": "..." }
{ "success": true, "data": [ ... ], "meta": { ... }, "links": { ... } }
{ "success": false, "message": "...", "errors": { ... } }
```

### Auth routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/auth/login` | Login, returns JWT |
| `POST` | `/auth/logout` | Invalidate token |
| `POST` | `/auth/refresh` | Refresh token |
| `GET` | `/auth/me` | Current user info |

### Tenant routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/issues` | List own issues |
| `POST` | `/issues` | Create new issue |
| `GET` | `/issues/{id}` | Issue details |
| `POST` | `/issues/{id}/cancel` | Cancel issue |

### Service Provider routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/assignments` | List assigned work |
| `POST` | `/assignments/{id}/start` | Start work |
| `POST` | `/assignments/{id}/hold` | Pause work |
| `POST` | `/assignments/{id}/resume` | Resume work |
| `POST` | `/assignments/{id}/finish` | Complete work |
| `POST` | `/time-extensions/request` | Request deadline extension |

### Shared routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/categories` | Master categories list |
| `GET` | `/consumables` | Consumables list |
| `GET` | `/profile` | User profile |
| `PUT` | `/profile` | Update profile |
| `POST` | `/devices` | Register FCM device token |
| `GET` | `/sync/master-data` | Full master data for offline sync |
| `POST` | `/sync/batch` | Batch sync operations |

### Admin routes (require admin role)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET/POST` | `/admin/issues` | List / create issues |
| `PUT` | `/admin/issues/{id}` | Update issue |
| `POST` | `/admin/issues/{id}/assign` | Assign to service provider |
| `POST` | `/admin/issues/{id}/approve` | Approve completed work |
| `POST` | `/admin/issues/{id}/cancel` | Cancel issue |
| `GET/POST` | `/admin/tenants` | Tenant management |
| `GET/POST` | `/admin/service-providers` | Service provider management |
| `GET` | `/admin/service-providers/{id}/availability` | Availability check |
| `GET/POST` | `/admin/categories` | Category tree management |
| `GET/POST` | `/admin/consumables` | Consumable management |
| `GET/POST` | `/admin/work-types` | Work type management |
| `GET` | `/admin/time-extensions` | List extension requests |
| `POST` | `/admin/time-extensions/{id}/approve` | Approve extension |
| `POST` | `/admin/time-extensions/{id}/reject` | Reject extension |
| `GET/POST` | `/admin/users` | Admin user management |
| `GET` | `/admin/dashboard/stats` | Dashboard statistics |
| `GET` | `/admin/calendar/events` | Calendar events |

---

## Project Structure

```
backend/
├── app/
│   ├── Actions/                    # Single-purpose business logic
│   │   ├── Issue/
│   │   ├── Notification/
│   │   └── User/
│   ├── DTOs/                       # Data Transfer Objects (Spatie Laravel-Data)
│   ├── Enums/                      # Typed enums (IssueStatus, IssuePriority, UserRole…)
│   ├── Filament/
│   │   ├── Resources/              # Admin panel CRUD resources
│   │   ├── Pages/                  # Custom Filament pages
│   │   └── Widgets/                # Dashboard widgets
│   ├── Http/
│   │   ├── Controllers/Api/V1/     # REST API controllers
│   │   │   └── Admin/              # Admin-only controllers
│   │   ├── Middleware/
│   │   ├── Requests/               # Form Request validation classes
│   │   └── Resources/              # API response transformers
│   ├── Models/                     # Eloquent models (14 models)
│   ├── Policies/                   # Authorization policies (Shield)
│   ├── Services/                   # Complex business logic services
│   ├── Settings/                   # Spatie Settings models
│   └── Providers/
│       └── Filament/               # Filament panel providers
├── database/
│   ├── migrations/
│   ├── seeders/
│   └── factories/
├── packages/
│   └── filament-fullcalendar/      # Local calendar package
├── routes/
│   ├── api.php                     # All API routes (/api/v1/*)
│   └── web.php                     # Web routes (redirects to /admin)
├── resources/
│   ├── css/                        # Tailwind CSS v4
│   ├── js/
│   └── views/                      # Blade templates
├── tests/
│   ├── Feature/
│   └── Unit/
├── lang/
│   ├── en/                         # English translations
│   └── ar/                         # Arabic translations (RTL)
└── bootstrap/app.php               # Laravel 12 middleware/routing config
```

---

## Troubleshooting

**Permission denied on storage/cache**
```bash
chmod -R 775 storage bootstrap/cache
```

**Migrations fail**
```bash
php artisan migrate:fresh --seed
```

**Vite assets not loading**
```bash
npm run build && php artisan optimize:clear
```

**JWT token invalid**
```bash
php artisan jwt:secret --force && php artisan config:clear
```

**FilamentShield permissions missing**
```bash
php artisan shield:generate --all
php artisan db:seed --class=RolesAndPermissionsSeeder
php artisan cache:clear
```

**Queue jobs not processing**
```bash
# Verify QUEUE_CONNECTION=database in .env
php artisan queue:work
php artisan queue:failed
```

**Storage link broken**
```bash
rm public/storage && php artisan storage:link
```

### Debug mode

```env
APP_DEBUG=true
APP_ENV=local
```

> Never enable `APP_DEBUG=true` in production.

### Logs

```bash
# Linux/macOS
tail -f storage/logs/laravel.log

# Windows PowerShell
Get-Content storage\logs\laravel.log -Wait -Tail 50
```

---

## Additional Resources

- [Laravel Documentation](https://laravel.com/docs)
- [Filament v5 Documentation](https://filamentphp.com/docs)
- [FilamentShield Documentation](https://filamentphp.com/plugins/bezhansalleh-shield)
- [Spatie Laravel-Permission](https://spatie.be/docs/laravel-permission)
- [jwt-auth Documentation](https://github.com/PHP-Open-Source-Saver/jwt-auth)
- [kreait/laravel-firebase](https://github.com/kreait/laravel-firebase)

---

## License

Proprietary software. All rights reserved.
