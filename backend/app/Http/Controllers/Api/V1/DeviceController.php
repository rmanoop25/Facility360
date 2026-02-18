<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DeviceController extends ApiController
{
    /**
     * Register or update FCM device token.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:500'],
            'device_type' => ['nullable', 'string', 'in:ios,android,web'],
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        // Clear this token from any other users first (device can only belong to one user)
        User::where('fcm_token', $validated['token'])
            ->where('id', '!=', $user->id)
            ->update(['fcm_token' => null]);

        $user->update(['fcm_token' => $validated['token']]);

        return $this->success(
            ['registered' => true],
            __('api.devices.registered')
        );
    }

    /**
     * Remove FCM device token.
     */
    public function destroy(string $token): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        // Only remove if the token matches the user's current token
        if ($user->fcm_token === $token) {
            $user->update(['fcm_token' => null]);

            return $this->success(
                ['removed' => true],
                __('api.devices.removed')
            );
        }

        return $this->success(
            ['removed' => false],
            __('api.devices.token_not_found')
        );
    }
}
