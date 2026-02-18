<?php

namespace App\Providers;

use App\Models\Category;
use App\Models\Consumable;
use App\Models\Issue;
use App\Models\ServiceProvider as ServiceProviderModel;
use App\Models\Tenant;
use App\Models\TimeExtensionRequest;
use App\Models\User;
use App\Models\WorkType;
use App\Observers\IssueObserver;
use App\Policies\CategoryPolicy;
use App\Policies\ConsumablePolicy;
use App\Policies\IssuePolicy;
use App\Policies\RolePolicy;
use App\Policies\ServiceProviderPolicy;
use App\Policies\TenantPolicy;
use App\Policies\TimeExtensionRequestPolicy;
use App\Policies\UserPolicy;
use App\Policies\WorkTypePolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;
use Spatie\Permission\Models\Role;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Register observers
        Issue::observe(IssueObserver::class);

        // Register policies (Shield auto-discovers, but explicit is better)
        Gate::policy(User::class, UserPolicy::class);
        Gate::policy(Tenant::class, TenantPolicy::class);
        Gate::policy(Issue::class, IssuePolicy::class);
        Gate::policy(ServiceProviderModel::class, ServiceProviderPolicy::class);
        Gate::policy(Category::class, CategoryPolicy::class);
        Gate::policy(Consumable::class, ConsumablePolicy::class);
        Gate::policy(WorkType::class, WorkTypePolicy::class);
        Gate::policy(TimeExtensionRequest::class, TimeExtensionRequestPolicy::class);
        Gate::policy(Role::class, RolePolicy::class);

        // Define custom gates for business logic permissions
        // Use hasPermissionTo() to avoid infinite recursion (can() would call the gate again)
        Gate::define('assign_issues', function (User $user) {
            return $user->hasPermissionTo('assign_issues');
        });

        Gate::define('approve_issues', function (User $user) {
            return $user->hasPermissionTo('approve_issues');
        });

        Gate::define('cancel_issues', function (User $user) {
            return $user->hasPermissionTo('cancel_issues');
        });

        Gate::define('view_reports', function (User $user) {
            return $user->hasPermissionTo('view_reports');
        });

        Gate::define('export_reports', function (User $user) {
            return $user->hasPermissionTo('export_reports');
        });

        Gate::define('manage_settings', function (User $user) {
            return $user->hasPermissionTo('manage_settings');
        });
    }
}
