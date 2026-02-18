<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Requests\Api\UpdateProfileRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class ProfileController extends ApiController
{
    /**
     * Get the authenticated user's profile.
     */
    public function show(): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $data = [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'profile_photo_url' => $user->profile_photo
                ? Storage::disk('public')->url($user->profile_photo)
                : null,
            'locale' => $user->locale ?? 'en',
            'is_active' => $user->is_active,
            'roles' => $user->getRoleNames(),
            'created_at' => $user->created_at->format('Y-m-d\TH:i:s\Z'),
        ];

        // Include tenant details if user is a tenant
        if ($user->isTenant()) {
            $tenant = $user->tenant;
            $data['tenant'] = [
                'id' => $tenant->id,
                'unit_number' => $tenant->unit_number,
                'building_name' => $tenant->building_name,
                'full_address' => $tenant->full_address,
            ];
            $data['user_type'] = 'tenant';
        }

        // Include service provider details if user is a service provider
        if ($user->isServiceProvider()) {
            $sp = $user->serviceProvider;
            $sp->load('category');

            $data['service_provider'] = [
                'id' => $sp->id,
                'category' => $sp->category ? [
                    'id' => $sp->category->id,
                    'name' => $sp->category->name,
                ] : null,
                'is_available' => $sp->is_available,
                'location' => $sp->hasLocation() ? [
                    'latitude' => (float) $sp->latitude,
                    'longitude' => (float) $sp->longitude,
                ] : null,
            ];
            $data['user_type'] = 'service_provider';
        }

        // Check if user is admin
        if ($user->isAdmin()) {
            $data['user_type'] = 'admin';
        }

        return $this->success($data, __('api.profile.show_success'));
    }

    /**
     * Update the user's preferred locale.
     */
    public function updateLocale(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'locale' => ['required', 'string', 'in:en,ar'],
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();
        $user->update(['locale' => $validated['locale']]);

        return $this->success(
            ['locale' => $user->locale],
            __('api.profile.locale_updated')
        );
    }

    /**
     * Update the user's profile.
     */
    public function update(UpdateProfileRequest $request): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        $data = $request->validated();

        // Update user fields
        $user->update([
            'name' => $data['name'] ?? $user->name,
            'phone' => $data['phone'] ?? $user->phone,
        ]);

        // Update tenant-specific fields
        if ($user->isTenant() && $user->tenant) {
            $user->tenant->update([
                'unit_number' => $data['unit_number'] ?? $user->tenant->unit_number,
                'building_name' => $data['building_name'] ?? $user->tenant->building_name,
            ]);
        }

        return $this->success(
            $this->getProfileData($user->fresh()),
            __('api.profile.updated')
        );
    }

    /**
     * Upload a profile photo.
     */
    public function uploadPhoto(Request $request): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        /** @var \App\Models\User $user */
        $user = Auth::user();

        // Delete old photo if exists
        if ($user->profile_photo) {
            Storage::disk('public')->delete($user->profile_photo);
        }

        $path = $request->file('photo')->store("profile-photos/{$user->id}", 'public');
        $user->update(['profile_photo' => $path]);

        return $this->success([
            'profile_photo_url' => Storage::disk('public')->url($path),
        ], __('api.profile.photo_uploaded'));
    }

    /**
     * Delete the user's profile photo.
     */
    public function deletePhoto(): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = Auth::user();

        if (!$user->profile_photo) {
            return $this->error(__('api.profile.no_photo'), 404);
        }

        Storage::disk('public')->delete($user->profile_photo);
        $user->update(['profile_photo' => null]);

        return $this->success(null, __('api.profile.photo_deleted'));
    }

    /**
     * Get formatted profile data for a user.
     */
    private function getProfileData($user): array
    {
        $data = [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'profile_photo_url' => $user->profile_photo
                ? Storage::disk('public')->url($user->profile_photo)
                : null,
            'locale' => $user->locale ?? 'en',
            'is_active' => $user->is_active,
            'roles' => $user->getRoleNames(),
            'created_at' => $user->created_at->format('Y-m-d\TH:i:s\Z'),
        ];

        if ($user->isTenant()) {
            $tenant = $user->tenant;
            $data['tenant'] = [
                'id' => $tenant->id,
                'unit_number' => $tenant->unit_number,
                'building_name' => $tenant->building_name,
                'full_address' => $tenant->full_address,
            ];
            $data['user_type'] = 'tenant';
        }

        if ($user->isServiceProvider()) {
            $sp = $user->serviceProvider;
            $sp->load('category');
            $data['service_provider'] = [
                'id' => $sp->id,
                'category' => $sp->category ? [
                    'id' => $sp->category->id,
                    'name' => $sp->category->name,
                ] : null,
                'is_available' => $sp->is_available,
                'location' => $sp->hasLocation() ? [
                    'latitude' => (float) $sp->latitude,
                    'longitude' => (float) $sp->longitude,
                ] : null,
            ];
            $data['user_type'] = 'service_provider';
        }

        if ($user->isAdmin()) {
            $data['user_type'] = 'admin';
        }

        return $data;
    }
}
