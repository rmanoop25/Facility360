<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\Admin\AdminCalendarController;
use App\Http\Controllers\Api\V1\Admin\AdminCategoryController;
use App\Http\Controllers\Api\V1\Admin\AdminIssueController;
use App\Http\Controllers\Api\V1\Admin\AdminTimeExtensionController;
use App\Http\Controllers\Api\V1\Admin\AdminUserController;
use App\Http\Controllers\Api\V1\Admin\AdminWorkTypeController;
use App\Http\Controllers\Api\V1\Admin\ConsumableController as AdminConsumableController;
use App\Http\Controllers\Api\V1\Admin\DashboardController;
use App\Http\Controllers\Api\V1\Admin\ServiceProviderController as AdminServiceProviderController;
use App\Http\Controllers\Api\V1\Admin\TenantController as AdminTenantController;
use App\Http\Controllers\Api\V1\AssignmentController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\ConsumableController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\IssueController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Controllers\Api\V1\TimeExtensionController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group.
|
*/

Route::prefix('v1')->group(function () {
    /*
    |--------------------------------------------------------------------------
    | Authentication Routes (Public)
    |--------------------------------------------------------------------------
    */
    Route::prefix('auth')->group(function () {
        Route::post('login', [AuthController::class, 'login'])->name('api.auth.login');
    });

    /*
    |--------------------------------------------------------------------------
    | Protected Routes (Requires JWT Authentication)
    |--------------------------------------------------------------------------
    */
    Route::middleware('auth:api')->group(function () {
        /*
        |----------------------------------------------------------------------
        | Authentication Routes (Protected)
        |----------------------------------------------------------------------
        */
        Route::prefix('auth')->group(function () {
            Route::post('logout', [AuthController::class, 'logout'])->name('api.auth.logout');
            Route::post('refresh', [AuthController::class, 'refresh'])->name('api.auth.refresh');
            Route::get('me', [AuthController::class, 'me'])->name('api.auth.me');
        });

        /*
        |----------------------------------------------------------------------
        | Issues Routes (Tenant)
        |----------------------------------------------------------------------
        */
        Route::prefix('issues')->group(function () {
            Route::get('/', [IssueController::class, 'index'])->name('api.issues.index');
            Route::post('/', [IssueController::class, 'store'])->name('api.issues.store');
            Route::get('{issue}', [IssueController::class, 'show'])->name('api.issues.show');
            Route::post('{issue}/cancel', [IssueController::class, 'cancel'])->name('api.issues.cancel');
        });

        /*
        |----------------------------------------------------------------------
        | Assignments Routes (Service Provider)
        |----------------------------------------------------------------------
        */
        Route::prefix('assignments')->group(function () {
            Route::get('/', [AssignmentController::class, 'index'])->name('api.assignments.index');
            Route::get('{issue}', [AssignmentController::class, 'show'])->name('api.assignments.show');
            Route::post('{issue}/start', [AssignmentController::class, 'start'])->name('api.assignments.start');
            Route::post('{issue}/hold', [AssignmentController::class, 'hold'])->name('api.assignments.hold');
            Route::post('{issue}/resume', [AssignmentController::class, 'resume'])->name('api.assignments.resume');
            Route::post('{issue}/finish', [AssignmentController::class, 'finish'])->name('api.assignments.finish');
        });

        /*
        |----------------------------------------------------------------------
        | Time Extension Routes (Service Provider)
        |----------------------------------------------------------------------
        */
        Route::prefix('time-extensions')->group(function () {
            Route::post('request', [TimeExtensionController::class, 'request'])->name('api.time-extensions.request');
            Route::get('my-requests', [TimeExtensionController::class, 'myRequests'])->name('api.time-extensions.my-requests');
        });

        /*
        |----------------------------------------------------------------------
        | Master Data Routes
        |----------------------------------------------------------------------
        */
        Route::get('categories', [CategoryController::class, 'index'])->name('api.categories.index');
        Route::get('categories/tree', [CategoryController::class, 'tree'])->name('api.categories.tree');
        Route::get('categories/{category}/children', [CategoryController::class, 'children'])->name('api.categories.children');
        Route::get('consumables', [ConsumableController::class, 'index'])->name('api.consumables.index');

        /*
        |----------------------------------------------------------------------
        | Profile Routes
        |----------------------------------------------------------------------
        */
        Route::prefix('profile')->group(function () {
            Route::get('/', [ProfileController::class, 'show'])->name('api.profile.show');
            Route::put('/', [ProfileController::class, 'update'])->name('api.profile.update');
            Route::put('locale', [ProfileController::class, 'updateLocale'])->name('api.profile.locale');
            Route::post('photo', [ProfileController::class, 'uploadPhoto'])->name('api.profile.photo.upload');
            Route::delete('photo', [ProfileController::class, 'deletePhoto'])->name('api.profile.photo.delete');
        });

        /*
        |----------------------------------------------------------------------
        | Device (FCM) Routes
        |----------------------------------------------------------------------
        */
        Route::prefix('devices')->group(function () {
            Route::post('/', [DeviceController::class, 'store'])->name('api.devices.store');
            Route::delete('{token}', [DeviceController::class, 'destroy'])->name('api.devices.destroy');
        });

        /*
        |----------------------------------------------------------------------
        | Sync Routes
        |----------------------------------------------------------------------
        */
        Route::prefix('sync')->group(function () {
            Route::get('master-data', [SyncController::class, 'masterData'])->name('api.sync.master-data');
            Route::post('batch', [SyncController::class, 'batch'])->name('api.sync.batch');
        });

        /*
        |----------------------------------------------------------------------
        | Admin Routes (Dynamic - any admin role can access)
        |----------------------------------------------------------------------
        */
        Route::prefix('admin')->middleware('is_admin')->group(function () {
            /*
            |------------------------------------------------------------------
            | Admin Issue Management
            |------------------------------------------------------------------
            */
            Route::prefix('issues')->group(function () {
                Route::get('/', [AdminIssueController::class, 'index'])->name('api.admin.issues.index');
                Route::post('/', [AdminIssueController::class, 'store'])->name('api.admin.issues.store');
                Route::get('{issue}', [AdminIssueController::class, 'show'])->name('api.admin.issues.show');
                Route::put('{issue}', [AdminIssueController::class, 'update'])
                    ->middleware('is_admin')
                    ->name('api.admin.issues.update');
                Route::post('{issue}/assign', [AdminIssueController::class, 'assign'])
                    ->middleware('is_admin')
                    ->name('api.admin.issues.assign');
                Route::post('{issue}/approve', [AdminIssueController::class, 'approve'])
                    ->middleware('is_admin')
                    ->name('api.admin.issues.approve');
                Route::post('{issue}/cancel', [AdminIssueController::class, 'cancel'])
                    ->middleware('is_admin')
                    ->name('api.admin.issues.cancel');
                Route::put('{issue}/assignments/{assignment}', [AdminIssueController::class, 'updateAssignment'])
                    ->middleware('is_admin')
                    ->name('api.admin.issues.assignments.update');
            });

            /*
            |------------------------------------------------------------------
            | Admin Tenant Management
            |------------------------------------------------------------------
            */
            Route::prefix('tenants')->middleware('is_admin')->group(function () {
                Route::get('/', [AdminTenantController::class, 'index'])->name('api.admin.tenants.index');
                Route::post('/', [AdminTenantController::class, 'store'])->name('api.admin.tenants.store');
                Route::get('{tenant}', [AdminTenantController::class, 'show'])->name('api.admin.tenants.show');
                Route::put('{tenant}', [AdminTenantController::class, 'update'])->name('api.admin.tenants.update');
                Route::delete('{tenant}', [AdminTenantController::class, 'destroy'])
                    ->middleware('role:super_admin')
                    ->name('api.admin.tenants.destroy');
            });

            /*
            |------------------------------------------------------------------
            | Admin Service Provider Management
            |------------------------------------------------------------------
            */
            Route::prefix('service-providers')->middleware('is_admin')->group(function () {
                Route::get('/', [AdminServiceProviderController::class, 'index'])
                    ->name('api.admin.service-providers.index');
                Route::post('/', [AdminServiceProviderController::class, 'store'])
                    ->name('api.admin.service-providers.store');
                Route::get('{serviceProvider}', [AdminServiceProviderController::class, 'show'])
                    ->name('api.admin.service-providers.show');
                Route::put('{serviceProvider}', [AdminServiceProviderController::class, 'update'])
                    ->name('api.admin.service-providers.update');
                Route::delete('{serviceProvider}', [AdminServiceProviderController::class, 'destroy'])
                    ->middleware('role:super_admin')
                    ->name('api.admin.service-providers.destroy');
                Route::get('{serviceProvider}/availability', [AdminServiceProviderController::class, 'availability'])
                    ->name('api.admin.service-providers.availability');
                Route::post('{serviceProvider}/auto-select-slots', [AdminServiceProviderController::class, 'autoSelectSlots'])
                    ->name('api.admin.service-providers.auto-select-slots');
            });

            /*
            |------------------------------------------------------------------
            | Admin Category Management
            |------------------------------------------------------------------
            */
            Route::prefix('categories')->middleware('is_admin')->group(function () {
                Route::get('/', [AdminCategoryController::class, 'index'])->name('api.admin.categories.index');
                Route::get('tree', [AdminCategoryController::class, 'tree'])->name('api.admin.categories.tree');
                Route::post('/', [AdminCategoryController::class, 'store'])->name('api.admin.categories.store');
                Route::get('{category}', [AdminCategoryController::class, 'show'])->name('api.admin.categories.show');
                Route::get('{category}/children', [AdminCategoryController::class, 'children'])->name('api.admin.categories.children');
                Route::put('{category}', [AdminCategoryController::class, 'update'])->name('api.admin.categories.update');
                Route::post('{category}/move', [AdminCategoryController::class, 'move'])->name('api.admin.categories.move');
                Route::post('{category}/restore', [AdminCategoryController::class, 'restore'])->name('api.admin.categories.restore');
                Route::delete('{category}', [AdminCategoryController::class, 'destroy'])
                    ->middleware('role:super_admin')
                    ->name('api.admin.categories.destroy');
            });

            /*
            |------------------------------------------------------------------
            | Admin Consumable Management
            |------------------------------------------------------------------
            */
            Route::prefix('consumables')->middleware('is_admin')->group(function () {
                Route::get('/', [AdminConsumableController::class, 'index'])->name('api.admin.consumables.index');
                Route::post('/', [AdminConsumableController::class, 'store'])->name('api.admin.consumables.store');
                Route::put('{consumable}', [AdminConsumableController::class, 'update'])
                    ->name('api.admin.consumables.update');
                Route::delete('{consumable}', [AdminConsumableController::class, 'destroy'])
                    ->middleware('role:super_admin')
                    ->name('api.admin.consumables.destroy');
            });

            /*
            |------------------------------------------------------------------
            | Admin Work Type Management
            |------------------------------------------------------------------
            */
            Route::prefix('work-types')->middleware('is_admin')->group(function () {
                Route::get('/', [AdminWorkTypeController::class, 'index'])->name('api.admin.work-types.index');
                Route::post('/', [AdminWorkTypeController::class, 'store'])->name('api.admin.work-types.store');
                Route::get('{id}', [AdminWorkTypeController::class, 'show'])->name('api.admin.work-types.show');
                Route::put('{id}', [AdminWorkTypeController::class, 'update'])->name('api.admin.work-types.update');
                Route::delete('{id}', [AdminWorkTypeController::class, 'destroy'])
                    ->middleware('role:super_admin')
                    ->name('api.admin.work-types.destroy');
            });

            /*
            |------------------------------------------------------------------
            | Admin Time Extension Management
            |------------------------------------------------------------------
            */
            Route::prefix('time-extensions')->middleware('is_admin')->group(function () {
                Route::get('/', [AdminTimeExtensionController::class, 'index'])->name('api.admin.time-extensions.index');
                Route::post('{id}/approve', [AdminTimeExtensionController::class, 'approve'])->name('api.admin.time-extensions.approve');
                Route::post('{id}/reject', [AdminTimeExtensionController::class, 'reject'])->name('api.admin.time-extensions.reject');
            });

            /*
            |------------------------------------------------------------------
            | Admin User Management
            |------------------------------------------------------------------
            */
            Route::prefix('users')->middleware('role:super_admin')->group(function () {
                Route::get('/', [AdminUserController::class, 'index'])->name('api.admin.users.index');
                Route::post('/', [AdminUserController::class, 'store'])->name('api.admin.users.store');
                Route::get('{user}', [AdminUserController::class, 'show'])->name('api.admin.users.show');
                Route::put('{user}', [AdminUserController::class, 'update'])->name('api.admin.users.update');
                Route::delete('{user}', [AdminUserController::class, 'destroy'])->name('api.admin.users.destroy');
                Route::post('{user}/reset-password', [AdminUserController::class, 'resetPassword'])
                    ->name('api.admin.users.reset-password');
                Route::post('{user}/toggle-active', [AdminUserController::class, 'toggleActive'])
                    ->name('api.admin.users.toggle-active');
            });

            /*
            |------------------------------------------------------------------
            | Admin Dashboard
            |------------------------------------------------------------------
            */
            Route::get('dashboard/stats', [DashboardController::class, 'stats'])
                ->name('api.admin.dashboard.stats');

            /*
            |------------------------------------------------------------------
            | Admin Calendar
            |------------------------------------------------------------------
            */
            Route::get('calendar/events', [AdminCalendarController::class, 'events'])
                ->name('api.admin.calendar.events');
        });
    });
});
