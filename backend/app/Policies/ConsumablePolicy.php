<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Consumable;
use Illuminate\Auth\Access\HandlesAuthorization;
use Illuminate\Foundation\Auth\User as AuthUser;

class ConsumablePolicy
{
    use HandlesAuthorization;

    public function viewAny(AuthUser $authUser): bool
    {
        return $authUser->can('ViewAny:Consumable');
    }

    public function view(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('View:Consumable');
    }

    public function create(AuthUser $authUser): bool
    {
        return $authUser->can('Create:Consumable');
    }

    public function update(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('Update:Consumable');
    }

    public function delete(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('Delete:Consumable');
    }

    public function deleteAny(AuthUser $authUser): bool
    {
        return $authUser->can('DeleteAny:Consumable');
    }

    public function restore(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('Restore:Consumable');
    }

    public function forceDelete(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('ForceDelete:Consumable');
    }

    public function forceDeleteAny(AuthUser $authUser): bool
    {
        return $authUser->can('ForceDeleteAny:Consumable');
    }

    public function restoreAny(AuthUser $authUser): bool
    {
        return $authUser->can('RestoreAny:Consumable');
    }

    public function replicate(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('Replicate:Consumable');
    }

    public function reorder(AuthUser $authUser): bool
    {
        return $authUser->can('Reorder:Consumable');
    }

    public function toggleActive(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('Update:Consumable');
    }

    public function changeCategory(AuthUser $authUser, Consumable $consumable): bool
    {
        return $authUser->can('Update:Consumable');
    }
}
