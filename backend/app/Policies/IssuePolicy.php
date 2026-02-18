<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Issue;
use Illuminate\Auth\Access\HandlesAuthorization;
use Illuminate\Foundation\Auth\User as AuthUser;

class IssuePolicy
{
    use HandlesAuthorization;

    public function viewAny(AuthUser $authUser): bool
    {
        return $authUser->can('ViewAny:Issue');
    }

    public function view(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('View:Issue');
    }

    public function create(AuthUser $authUser): bool
    {
        return $authUser->can('Create:Issue');
    }

    public function update(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('Update:Issue');
    }

    public function delete(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('Delete:Issue');
    }

    public function deleteAny(AuthUser $authUser): bool
    {
        return $authUser->can('DeleteAny:Issue');
    }

    public function restore(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('Restore:Issue');
    }

    public function forceDelete(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('ForceDelete:Issue');
    }

    public function forceDeleteAny(AuthUser $authUser): bool
    {
        return $authUser->can('ForceDeleteAny:Issue');
    }

    public function restoreAny(AuthUser $authUser): bool
    {
        return $authUser->can('RestoreAny:Issue');
    }

    public function replicate(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('Replicate:Issue');
    }

    public function reorder(AuthUser $authUser): bool
    {
        return $authUser->can('Reorder:Issue');
    }

    public function assign(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('assign_issues');
    }

    public function approve(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('approve_issues');
    }

    public function cancel(AuthUser $authUser, Issue $issue): bool
    {
        return $authUser->can('cancel_issues');
    }
}
