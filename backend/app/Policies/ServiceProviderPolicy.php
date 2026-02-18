<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\ServiceProvider;
use Illuminate\Auth\Access\HandlesAuthorization;
use Illuminate\Foundation\Auth\User as AuthUser;

class ServiceProviderPolicy
{
    use HandlesAuthorization;

    public function viewAny(AuthUser $authUser): bool
    {
        return $authUser->can('ViewAny:ServiceProvider');
    }

    public function view(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('View:ServiceProvider');
    }

    public function create(AuthUser $authUser): bool
    {
        return $authUser->can('Create:ServiceProvider');
    }

    public function update(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('Update:ServiceProvider');
    }

    public function delete(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('Delete:ServiceProvider');
    }

    public function deleteAny(AuthUser $authUser): bool
    {
        return $authUser->can('DeleteAny:ServiceProvider');
    }

    public function restore(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('Restore:ServiceProvider');
    }

    public function forceDelete(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('ForceDelete:ServiceProvider');
    }

    public function forceDeleteAny(AuthUser $authUser): bool
    {
        return $authUser->can('ForceDeleteAny:ServiceProvider');
    }

    public function restoreAny(AuthUser $authUser): bool
    {
        return $authUser->can('RestoreAny:ServiceProvider');
    }

    public function replicate(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('Replicate:ServiceProvider');
    }

    public function reorder(AuthUser $authUser): bool
    {
        return $authUser->can('Reorder:ServiceProvider');
    }

    public function resetPassword(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('Update:ServiceProvider');
    }

    public function toggleAvailability(AuthUser $authUser, ServiceProvider $serviceProvider): bool
    {
        return $authUser->can('Update:ServiceProvider');
    }
}
