<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\ApiController;
use App\Models\ServiceProvider;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class ServiceProviderController extends ApiController
{
    /**
     * List all service providers with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'is_active' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = ServiceProvider::with([
            'user:id,name,email,phone,profile_photo,is_active,locale',
            'categories:id,name_en,name_ar,icon',
        ])->orderBy('created_at', 'desc');

        if ($request->filled('search')) {
            $search = $validated['search'];
            $query->whereHas('user', function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        if ($request->filled('category_id')) {
            $category = \App\Models\Category::find($validated['category_id']);
            $categoryIds = $category ? [...$category->getAncestorIds(), $category->id] : [$validated['category_id']];
            $query->whereHas('categories', fn ($q) => $q->whereIn('categories.id', $categoryIds));
        }

        if ($request->has('is_active')) {
            $query->whereHas('user', fn ($q) => $q->where('is_active', $validated['is_active']));
        }

        $perPage = $validated['per_page'] ?? 15;
        $providers = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => \App\Http\Resources\ServiceProviderResource::collection($providers->items()),
            'message' => __('api.service_providers.list_success'),
            'meta' => [
                'current_page' => $providers->currentPage(),
                'last_page' => $providers->lastPage(),
                'per_page' => $providers->perPage(),
                'total' => $providers->total(),
            ],
            'links' => [
                'first' => $providers->url(1),
                'last' => $providers->url($providers->lastPage()),
                'prev' => $providers->previousPageUrl(),
                'next' => $providers->nextPageUrl(),
            ],
        ]);
    }

    /**
     * Create a new service provider.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:20'],
            'password' => ['required', 'string', 'min:8'],
            'profile_photo' => ['nullable', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
            'category_ids' => ['required', 'array', 'min:1'],
            'category_ids.*' => ['integer', 'exists:categories,id'],
            'locale' => ['nullable', 'string', Rule::in(['en', 'ar'])],
            'is_active' => ['nullable', 'boolean'],
        ]);

        try {
            DB::beginTransaction();

            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'phone' => $validated['phone'] ?? null,
                'password' => Hash::make($validated['password']),
                'locale' => $validated['locale'] ?? 'en',
                'is_active' => $validated['is_active'] ?? true,
            ]);

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                $path = $request->file('profile_photo')->store("profile-photos/{$user->id}", 'public');
                $user->update(['profile_photo' => $path]);
            }

            $provider = ServiceProvider::create([
                'user_id' => $user->id,
            ]);

            // Sync categories
            $provider->categories()->sync($validated['category_ids']);

            DB::commit();

            $provider->load([
                'user:id,name,email,phone,profile_photo,is_active,locale',
                'categories:id,name_en,name_ar,icon',
            ]);

            return $this->created($provider, __('api.service_providers.created_success'));
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.service_providers.create_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Show service provider details.
     */
    public function show(int $id): JsonResponse
    {
        $provider = ServiceProvider::with([
            'user:id,name,email,phone,profile_photo,is_active,locale,created_at',
            'categories:id,name_en,name_ar,icon',
            'timeSlots',
        ])->find($id);

        if (! $provider) {
            return $this->notFound(__('api.service_providers.not_found'));
        }

        return $this->success(new \App\Http\Resources\ServiceProviderResource($provider), __('api.service_providers.show_success'));
    }

    /**
     * Update service provider details.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $provider = ServiceProvider::with('user')->find($id);

        if (! $provider) {
            return $this->notFound(__('api.service_providers.not_found'));
        }

        // Cast is_active from multipart string ("true"/"false"/"1"/"0") to boolean
        if ($request->has('is_active')) {
            $request->merge([
                'is_active' => filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE),
            ]);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', Rule::unique('users')->ignore($provider->user_id)],
            'phone' => ['nullable', 'string', 'max:20'],
            'password' => ['nullable', 'string', 'min:8'],
            'profile_photo' => ['nullable', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
            'category_ids' => ['sometimes', 'array'],
            'category_ids.*' => ['integer', 'exists:categories,id'],
            'locale' => ['nullable', 'string', Rule::in(['en', 'ar'])],
            'is_active' => ['nullable', 'boolean'],
        ]);

        try {
            DB::beginTransaction();

            // Handle profile photo upload
            if ($request->hasFile('profile_photo')) {
                // Delete old photo if exists
                if ($provider->user->profile_photo) {
                    Storage::disk('public')->delete($provider->user->profile_photo);
                }
                $path = $request->file('profile_photo')->store("profile-photos/{$provider->user_id}", 'public');
                $provider->user->update(['profile_photo' => $path]);
            }

            // Update user
            $userUpdates = array_filter([
                'name' => $validated['name'] ?? null,
                'email' => $validated['email'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'locale' => $validated['locale'] ?? null,
                'is_active' => $validated['is_active'] ?? null,
            ], fn ($value) => $value !== null);

            if (isset($validated['password'])) {
                $userUpdates['password'] = Hash::make($validated['password']);
            }

            if (! empty($userUpdates)) {
                $provider->user->update($userUpdates);
            }

            // Update provider (currently no provider-specific fields to update)
            // Future: Add provider-specific fields here if needed

            // Sync categories if provided
            if (isset($validated['category_ids'])) {
                $provider->categories()->sync($validated['category_ids']);
            }

            DB::commit();

            $provider->refresh();
            $provider->load([
                'user:id,name,email,phone,profile_photo,is_active,locale',
                'categories:id,name_en,name_ar,icon',
            ]);

            return $this->success(new \App\Http\Resources\ServiceProviderResource($provider), __('api.service_providers.updated_success'));
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.service_providers.update_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Delete a service provider.
     */
    public function destroy(int $id): JsonResponse
    {
        $provider = ServiceProvider::with('user')->find($id);

        if (! $provider) {
            return $this->notFound(__('api.service_providers.not_found'));
        }

        try {
            DB::beginTransaction();

            $provider->user->update(['is_active' => false]);
            $provider->delete();

            DB::commit();

            return $this->success(null, __('api.service_providers.deleted_success'));
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.service_providers.delete_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Get service provider availability for a date range.
     */
    public function availability(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'date' => ['required', 'date', 'after_or_equal:today'],
            'min_duration_minutes' => ['nullable', 'integer', 'min:1', 'max:1440'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $serviceProvider = ServiceProvider::with([
            'user:id,name',
            'categories:id,name_en,name_ar',
            'timeSlots' => fn ($q) => $q->active(),
        ])->find($id);

        if (! $serviceProvider) {
            return response()->json([
                'success' => false,
                'message' => __('service_providers.not_found'),
            ], 404);
        }

        $date = Carbon::parse($request->input('date'));
        $dayOfWeek = $date->dayOfWeek;
        $minDurationMinutes = $request->input('min_duration_minutes')
            ? (int) $request->input('min_duration_minutes')
            : null;

        // Get time slots for this day of week
        $dayTimeSlots = $serviceProvider->timeSlots->where('day_of_week', $dayOfWeek);

        $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);

        $availability = $dayTimeSlots->map(function ($slot) use ($date, $minDurationMinutes, $availabilityService) {
            $startTime = Carbon::parse($slot->start_time)->format('H:i');
            $endTime = Carbon::parse($slot->end_time)->format('H:i');

            // Calculate total slot duration
            $start = Carbon::parse($slot->start_time);
            $end = Carbon::parse($slot->end_time);
            $durationMinutes = $start->diffInMinutes($end);

            // Get capacity info for this slot
            $capacity = $availabilityService->getSlotCapacity($slot, $date);

            // Check if slot can fit the requested duration
            $canFitDuration = $minDurationMinutes
                ? $capacity['available_minutes'] >= $minDurationMinutes
                : $capacity['has_capacity'];

            // Calculate next available time if duration specified
            $nextAvailable = $minDurationMinutes && $canFitDuration
                ? $availabilityService->calculateNextAvailableTime($slot, $date, $minDurationMinutes)
                : null;

            // Convert gaps to HH:mm format for client consumption
            $formattedGaps = collect($capacity['gaps'] ?? [])->map(function ($gap) {
                return [
                    'start' => substr($gap['start'], 0, 5), // HH:mm
                    'end' => substr($gap['end'], 0, 5),     // HH:mm
                    'duration_minutes' => $gap['duration_minutes'],
                ];
            })->toArray();

            return [
                'id' => $slot->id,
                'day_of_week' => $slot->day_of_week,
                'day_name' => $slot->day_name,
                'start_time' => $startTime,
                'end_time' => $endTime,
                'duration_minutes' => $durationMinutes,
                'display' => $slot->formatted_time_range,
                'is_full_day' => $startTime === '00:00' && $endTime === '23:59',

                // Capacity information (NEW)
                'total_minutes' => $capacity['total_minutes'],
                'booked_minutes' => $capacity['booked_minutes'],
                'available_minutes' => $capacity['available_minutes'],
                'utilization_percent' => $capacity['total_minutes'] > 0
                    ? round(($capacity['booked_minutes'] / $capacity['total_minutes']) * 100)
                    : 0,

                // Availability flags
                'is_available' => $canFitDuration,
                'has_capacity' => $capacity['has_capacity'],

                // Next available time suggestion
                'next_available_start' => $nextAvailable ? substr($nextAvailable['start'], 0, 5) : null,
                'next_available_end' => $nextAvailable ? substr($nextAvailable['end'], 0, 5) : null,

                // Available gaps within the slot (NEW - for visual indication)
                'available_gaps' => $formattedGaps,
            ];
        })
            ->filter(function ($slot) use ($minDurationMinutes) {
                // Filter out slots that can't fit the requested duration
                if ($minDurationMinutes === null) {
                    return true; // No filter
                }

                return $slot['available_minutes'] >= $minDurationMinutes;
            })
            ->values();

        return response()->json([
            'success' => true,
            'data' => [
                'service_provider' => [
                    'id' => $serviceProvider->id,
                    'name' => $serviceProvider->name,
                    'categories' => $serviceProvider->categories->map(fn ($c) => [
                        'id' => $c->id,
                        'name' => $c->name,
                    ]),
                    'is_available' => $serviceProvider->is_available,
                ],
                'date' => $date->toDateString(),
                'day_of_week' => $dayOfWeek,
                'day_name' => $date->format('l'),
                'time_slots' => $availability,
                'has_available_slots' => $availability->where('has_capacity', true)->isNotEmpty(),
                'slots_with_requested_duration' => $minDurationMinutes
                    ? $availability->where('is_available', true)->count()
                    : null,
            ],
            'message' => __('service_providers.availability_retrieved'),
        ], 200);
    }

    /**
     * Auto-select time slots across multiple days for a given duration.
     * Replicates the Filament admin panel's multi-day auto-selection logic.
     */
    public function autoSelectSlots(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'start_date' => ['required', 'date', 'after_or_equal:today'],
            'duration_minutes' => ['required', 'integer', 'min:1', 'max:43200'], // Max 30 days worth
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $serviceProvider = ServiceProvider::with([
            'user:id,name',
            'categories:id,name_en,name_ar',
            'timeSlots' => fn ($q) => $q->active(),
        ])->find($id);

        if (! $serviceProvider) {
            return response()->json([
                'success' => false,
                'message' => __('service_providers.not_found'),
            ], 404);
        }

        $duration = (int) $request->input('duration_minutes');
        $startDate = Carbon::parse($request->input('start_date'));

        $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
        $currentDate = $startDate->copy();

        $selectedSlots = []; // Array of {slot_id, date, start_time, end_time, minutes, slot}
        $accumulatedMinutes = 0;
        $maxDays = 90; // Maximum 90 days (3 months)
        $daysProcessed = 0;
        $lastDateWithSlots = $currentDate->copy();

        // Try to fill the duration across multiple days using available capacity
        while ($accumulatedMinutes < $duration && $daysProcessed < $maxDays) {
            $dayOfWeek = $currentDate->dayOfWeek;

            // Get all time slots for this day
            $allSlots = $serviceProvider->timeSlots
                ->where('day_of_week', $dayOfWeek)
                ->sortBy('start_time');

            if ($allSlots->isNotEmpty()) {
                foreach ($allSlots as $slot) {
                    // Get actual available capacity
                    $capacity = $availabilityService->getSlotCapacity($slot, $currentDate);

                    if ($capacity['available_minutes'] <= 0) {
                        continue; // Skip fully booked slots
                    }

                    $remainingNeeded = $duration - $accumulatedMinutes;

                    // How much can we take from this slot?
                    $minutesToUse = (int) min($capacity['available_minutes'], $remainingNeeded);

                    // Find the best gap to fit these minutes
                    $nextAvailable = $availabilityService->calculateNextAvailableTime(
                        $slot,
                        $currentDate,
                        $minutesToUse
                    );

                    if ($nextAvailable) {
                        $selectedSlots[] = [
                            'slot_id' => $slot->id,
                            'date' => $currentDate->toDateString(),
                            'start_time' => $nextAvailable['start'],
                            'end_time' => $nextAvailable['end'],
                            'minutes' => $minutesToUse,
                            'slot' => [
                                'id' => $slot->id,
                                'day_of_week' => $slot->day_of_week,
                                'day_name' => $slot->day_name,
                                'start_time' => $slot->start_time->format('H:i'),
                                'end_time' => $slot->end_time->format('H:i'),
                                'display' => $slot->formatted_time_range,
                            ],
                        ];

                        $accumulatedMinutes += $minutesToUse;
                        $lastDateWithSlots = $currentDate->copy();

                        // Stop if we've accumulated enough
                        if ($accumulatedMinutes >= $duration) {
                            break 2;
                        }
                    }
                }
            }

            // Move to next day
            $currentDate->addDay();
            $daysProcessed++;
        }

        // Extract unique slot IDs for the CheckboxList
        $slotIds = array_values(array_unique(array_column($selectedSlots, 'slot_id')));

        // Calculate time ranges for the assignment
        $assignedStartTime = null;
        $assignedEndTime = null;
        $scheduledEndDate = null;

        if (count($selectedSlots) === 1) {
            // Single slot: use the exact partial range
            $assignedStartTime = substr($selectedSlots[0]['start_time'], 0, 5);
            $assignedEndTime = substr($selectedSlots[0]['end_time'], 0, 5);
        } elseif (count($selectedSlots) > 1) {
            // Multi-slot: use combined range (earliest start to latest end)
            $earliestStart = min(array_column($selectedSlots, 'start_time'));
            $latestEnd = max(array_column($selectedSlots, 'end_time'));
            $assignedStartTime = substr($earliestStart, 0, 5);
            $assignedEndTime = substr($latestEnd, 0, 5);

            // Calculate end date if multi-day
            $dates = array_unique(array_column($selectedSlots, 'date'));
            if (count($dates) > 1) {
                $scheduledEndDate = max($dates);
            }
        }

        // Calculate span days
        $spanDays = $startDate->diffInDays($lastDateWithSlots) + 1;
        $isMultiDay = $spanDays > 1;

        // Check if we fulfilled the duration
        $isSufficient = $accumulatedMinutes >= $duration;

        return response()->json([
            'success' => true,
            'data' => [
                'service_provider' => [
                    'id' => $serviceProvider->id,
                    'name' => $serviceProvider->name,
                ],
                'start_date' => $startDate->toDateString(),
                'end_date' => $scheduledEndDate,
                'is_multi_day' => $isMultiDay,
                'span_days' => $spanDays,
                'requested_duration_minutes' => $duration,
                'accumulated_minutes' => $accumulatedMinutes,
                'is_sufficient' => $isSufficient,
                'shortfall_minutes' => $isSufficient ? 0 : ($duration - $accumulatedMinutes),
                'time_slot_ids' => $slotIds,
                'assigned_start_time' => $assignedStartTime,
                'assigned_end_time' => $assignedEndTime,
                'selected_slots' => $selectedSlots,
                'days_processed' => $daysProcessed,
            ],
            'message' => $isSufficient
                ? __('Successfully allocated {minutes} minutes across {days} day(s)', [
                    'minutes' => $accumulatedMinutes,
                    'days' => $spanDays,
                ])
                : __('Could only allocate {accumulated} out of {required} minutes across {days} day(s)', [
                    'accumulated' => $accumulatedMinutes,
                    'required' => $duration,
                    'days' => $spanDays,
                ]),
        ], 200);
    }
}
