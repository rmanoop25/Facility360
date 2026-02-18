<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\User;
use App\Models\WorkType;

class WorkTypePolicy
{
    /**
     * Determine whether the user can view any models.
     */
    public function viewAny(User $user): bool
    {
        return $user->can('ViewAny:WorkType');
    }

    /**
     * Determine whether the user can view the model.
     */
    public function view(User $user, WorkType $workType): bool
    {
        return $user->can('View:WorkType');
    }

    /**
     * Determine whether the user can create models.
     */
    public function create(User $user): bool
    {
        return $user->can('Create:WorkType');
    }

    /**
     * Determine whether the user can update the model.
     */
    public function update(User $user, WorkType $workType): bool
    {
        return $user->can('Update:WorkType');
    }

    /**
     * Determine whether the user can delete the model.
     */
    public function delete(User $user, WorkType $workType): bool
    {
        // Check if work type is in use by any assignments
        if ($workType->assignments()->exists()) {
            return false; // Cannot delete if referenced by assignments
        }

        return $user->can('Delete:WorkType');
    }

    /**
     * Determine whether the user can override work type duration during assignment.
     */
    public function overrideDuration(User $user): bool
    {
        return $user->can('override_work_type_duration');
    }
}
