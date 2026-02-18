# Facility360

A full-stack facility maintenance management system for residential communities. Tenants report issues, administrators assign them to service providers, and everyone tracks progress — even without internet.

---

## Overview

Facility360 consists of two parts:

| Part | Stack | Path |
|------|-------|------|
| **Admin Panel & API** | Laravel 12 + Filament v5 | `backend/` |
| **Mobile App** | Flutter (Dart) | `mobile_new/` |

**Key characteristics:**
- Offline-first mobile app — all actions queue locally and sync when online
- Arabic + English with full RTL support
- Role-based access control with permission-gated UI
- Dark and light theme support

---

## Roles

| Role | Platform | Access |
|------|----------|--------|
| Super Admin | Web | Full system access |
| Manager | Web | Issues, assignments, users |
| Viewer | Web | Read-only |
| Tenant | Mobile | Create & track issues |
| Service Provider | Mobile | Receive assignments, complete work |

---

## Tech Stack

### Backend
- **PHP** 8.2+ / **Laravel** 12
- **Filament** v5 — admin panel
- **FilamentShield** v4 — role & permission management
- **Spatie Permission** v6 — granular access control
- **JWT Auth** (php-open-source-saver) — mobile API authentication
- **Spatie Laravel-Data** — typed DTOs
- **Firebase** (kreait) — push notifications
- **MySQL** 8.0+
- **Pest** v3 — testing

### Mobile
- **Flutter** / **Dart** 3.10+
- **Riverpod** v2 — state management
- **Hive** v2 — local offline storage
- **Dio** v5 — HTTP client
- **GoRouter** v14 — navigation
- **Freezed** v3 — immutable models
- **Firebase Messaging** — push notifications
- **Google Maps** — location services
- **Easy Localization** — AR/EN translations

---

## Features

### Issue Lifecycle
```
Tenant creates issue → Admin reviews → Admin assigns to SP → SP completes work → Admin approves
```
Full audit trail recorded at every step via `IssueTimeline`.

### Admin Panel (Web)
- Issue management with status tracking, priority, and assignment
- Service provider scheduling with time slot availability
- Time extension request approval workflow
- Category hierarchy (materialized path) for work types
- Consumables tracking
- Role & permission management via Shield
- Multi-language admin panel (Arabic / English)

### Mobile App
- Offline-first: create issues, update assignments, submit proofs — all without internet
- Real-time sync when back online with conflict resolution
- Image, PDF, audio, and video attachments
- Push notifications for status changes
- Geolocation and map integration
- Shimmer loading states, dark/light themes

---

## Architecture

### Backend
```
app/
├── Actions/          # Business logic (ApproveIssueAction, etc.)
├── DTOs/             # Typed data transfer objects
├── Services/         # Reusable services (TimeSlotAvailabilityService, etc.)
├── Enums/            # IssueStatus, IssuePriority, AssignmentStatus, ...
├── Filament/         # Admin panel resources, pages, widgets
├── Http/
│   ├── Controllers/Api/V1/   # REST API controllers
│   └── Requests/             # Form request validation
└── Models/           # Eloquent models with relationships
```

### Mobile — Clean Architecture
```
lib/
├── core/             # API client, sync engine, theme, router, extensions
├── domain/           # Entities, enums
├── data/             # Remote & local datasources, models, repositories
│   ├── datasources/  # *_remote_datasource.dart + *_local_datasource.dart
│   ├── models/       # JSON + Hive models
│   └── repositories/ # Coordinate local ↔ remote
└── presentation/
    ├── screens/      # admin/, tenant/, service_provider/, auth/
    ├── widgets/      # Reusable UI components
    └── providers/    # Riverpod providers
```

### Offline-First Pattern
```
User Action → Save to Hive → Update UI immediately → Queue for sync → Sync when online
```
- Pending operations survive app restarts and user switches
- Server refreshes never overwrite locally pending changes
- Offline-created items use negative IDs, routed via `/local/:localId`

---

## Getting Started

### Prerequisites
- PHP 8.2+, Composer
- Node.js 20+ (for Vite)
- MySQL 8.0+
- Flutter SDK 3.10+

---

### Backend Setup

```bash
cd backend

# Install dependencies
composer install
npm install

# Environment
cp .env.example .env
php artisan key:generate

# Configure .env: DB_*, JWT secret, Firebase credentials

# Database
php artisan migrate
php artisan db:seed

# Generate JWT secret
php artisan jwt:secret

# Development server (Laravel + queue + Vite)
composer dev
```

The admin panel is available at `http://localhost:8000/admin`.

---

### Mobile Setup

```bash
cd mobile_new

# Install packages
flutter pub get

# Run code generation (after modifying providers or Freezed models)
dart run build_runner build --delete-conflicting-outputs

# Run on device or emulator
flutter run
```

> **Note:** Add `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` (excluded from version control). Add your Google Maps API key to `ios/Runner/AppDelegate.swift`.

---

## API

Base URL: `/api/v1/`
Authentication: `Authorization: Bearer <JWT token>`

| Endpoint | Description |
|----------|-------------|
| `POST /auth/login` | Login — returns JWT token |
| `GET /auth/me` | Authenticated user with permissions |
| `GET /issues` | Tenant: list issues |
| `POST /issues` | Tenant: create issue |
| `GET /assignments` | SP: list assignments |
| `PATCH /assignments/{id}` | SP: update assignment status |
| `GET /admin/issues` | Admin: list all issues |
| `POST /admin/issues/{id}/assign` | Admin: assign issue to SP |
| `POST /admin/issues/{id}/approve` | Admin: approve completed work |
| `POST /sync` | Batch sync endpoint for offline operations |

---

## Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Super Admin | admin@maintenance.local | password |
| Tenant | tenant1@maintenance.local | password |
| Service Provider | plumber@maintenance.local | password |

---

## Development Commands

### Backend
```bash
composer dev          # Start all dev services (server + queue + logs + Vite)
php artisan migrate   # Run migrations
php artisan db:seed   # Seed database
composer test         # Run Pest tests
php artisan pint      # Fix code style
```

### Mobile
```bash
flutter run           # Run on connected device
flutter test          # Run tests
flutter analyze       # Lint and analyze
dart format lib/      # Format code
flutter build apk     # Build Android APK
```

---

## License

Private — All rights reserved.
