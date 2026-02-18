<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\TimeExtensionRequest;
use App\Models\User;

class TimeExtensionRequestPolicy
{
    /**
     * Determine whether the user can view any models.
     */
    public function viewAny(User $user): bool
    {
        return $user->can('ViewAny:TimeExtensionRequest');
    }

    /**
     * Determine whether the user can view the model.
     */
    public function view(User $user, TimeExtensionRequest $request): bool
    {
        // Admins can view all requests
        if ($user->can('View:TimeExtensionRequest')) {
            return true;
        }

        // SPs can view their own requests
        return $request->requested_by === $user->id;
    }

    /**
     * Determine whether the user can request a time extension.
     */
    public function request(User $user): bool
    {
        return $user->can('request_time_extension');
    }

    /**
     * Determine whether the user can approve the time extension request.
     */
    public function approve(User $user, TimeExtensionRequest $request): bool
    {
        return $user->can('approve_time_extensions') && $request->canBeApproved();
    }

    /**
     * Determine whether the user can reject the time extension request.
     */
    public function reject(User $user, TimeExtensionRequest $request): bool
    {
        return $user->can('reject_time_extensions') && $request->canBeRejected();
    }
}
