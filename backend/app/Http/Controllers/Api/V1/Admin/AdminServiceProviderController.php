<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\ApiController;
use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminServiceProviderController extends ApiController
{
    /**
     * List all service providers with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'search' => ['nullable', 'string', 'max:255'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'is_available' => ['nullable', 'boolean'],
            'is_active' => ['nullable', 'boolean'],
            'sort_by' => ['nullable', 'string', Rule::in(['created_at', 'name', 'category_id'])],
            'sort_order' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = ServiceProvider::with([
            'user:id,name,email,phone,profile_photo,is_active,created_at',
            'categories:id,name_en,name_ar,icon',
        ])->withCount(['assignments', 'assignments as active_assignments_count' => fn ($q) => $q->active()]);

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->whereHas('user', fn ($uq) => $uq->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                );
            });
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->input('category_id'));
        }

        if ($request->has('is_available')) {
            $query->where('is_available', $request->boolean('is_available'));
        }

        if ($request->has('is_active')) {
            $query->whereHas('user', fn ($q) => $q->where('is_active', $request->boolean('is_active')));
        }

        // Apply sorting
        $sortBy = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');

        if ($sortBy === 'name') {
            $query->join('users', 'service_providers.user_id', '=', 'users.id')
                ->orderBy('users.name', $sortOrder)
                ->select('service_providers.*');
        } else {
            $query->orderBy($sortBy, $sortOrder);
        }

        $perPage = $request->input('per_page', 15);
        $providers = $query->paginate($perPage);

        $data = $providers->getCollection()->map(fn ($sp) => $this->formatServiceProvider($sp));

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => [
                'current_page' => $providers->currentPage(),
                'last_page' => $providers->lastPage(),
                'per_page' => $providers->perPage(),
                'total' => $providers->total(),
            ],
        ]);
    }

    /**
     * Create a new service provider.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::min(8)->mixedCase()->numbers()],
            'phone' => ['required', 'string', 'max:20'],
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'is_available' => ['nullable', 'boolean'],
            'is_active' => ['nullable', 'boolean'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'time_slots' => ['nullable', 'array'],
            'time_slots.*.day_of_week' => ['required_with:time_slots', 'integer', 'between:0,6'],
            'time_slots.*.is_full_day' => ['nullable', 'boolean'],
            'time_slots.*.start_time' => ['required_without:time_slots.*.is_full_day', 'nullable', 'date_format:H:i'],
            'time_slots.*.end_time' => ['required_without:time_slots.*.is_full_day', 'nullable', 'date_format:H:i', 'after:time_slots.*.start_time'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Create user
            $user = User::create([
                'name' => $request->input('name'),
                'email' => $request->input('email'),
                'password' => Hash::make($request->input('password')),
                'phone' => $request->input('phone'),
                'is_active' => $request->input('is_active', true),
                'locale' => $request->input('locale', 'en'),
            ]);

            // Assign service provider role
            $user->assignRole(UserRole::SERVICE_PROVIDER->value);

            // Create service provider profile
            $serviceProvider = ServiceProvider::create([
                'user_id' => $user->id,
                'category_id' => $request->input('category_id'),
                'is_available' => $request->input('is_available', true),
                'latitude' => $request->input('latitude'),
                'longitude' => $request->input('longitude'),
            ]);

            // Create time slots if provided
            if ($request->has('time_slots')) {
                foreach ($request->input('time_slots') as $slot) {
                    $isFullDay = $slot['is_full_day'] ?? false;
                    TimeSlot::create([
                        'service_provider_id' => $serviceProvider->id,
                        'day_of_week' => $slot['day_of_week'],
                        'start_time' => $isFullDay ? '00:00' : $slot['start_time'],
                        'end_time' => $isFullDay ? '23:59' : $slot['end_time'],
                        'is_active' => true,
                    ]);
                }
            }

            $serviceProvider->load([
                'user:id,name,email,phone,profile_photo,is_active,created_at',
                'categories:id,name_en,name_ar,icon',
                'timeSlots',
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('service_providers.created_successfully'),
                'data' => $this->formatServiceProviderDetail($serviceProvider),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Get service provider details with time slots.
     */
    public function show(int $id): JsonResponse
    {
        $serviceProvider = ServiceProvider::with([
            'user:id,name,email,phone,profile_photo,is_active,locale,created_at,updated_at',
            'categories:id,name_en,name_ar,icon',
            'timeSlots' => fn ($q) => $q->orderBy('day_of_week')->orderBy('start_time'),
        ])->withCount([
            'assignments',
            'assignments as active_assignments_count' => fn ($q) => $q->active(),
            'assignments as completed_assignments_count' => fn ($q) => $q->where('status', 'completed'),
        ])->find($id);

        if (! $serviceProvider) {
            return response()->json([
                'success' => false,
                'message' => __('service_providers.not_found'),
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatServiceProviderDetail($serviceProvider),
        ]);
    }

    /**
     * Update service provider.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $serviceProvider = ServiceProvider::with('user')->find($id);

        if (! $serviceProvider) {
            return response()->json([
                'success' => false,
                'message' => __('service_providers.not_found'),
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($serviceProvider->user_id)],
            'phone' => ['sometimes', 'required', 'string', 'max:20'],
            'category_id' => ['sometimes', 'required', 'integer', 'exists:categories,id'],
            'is_available' => ['nullable', 'boolean'],
            'is_active' => ['nullable', 'boolean'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'locale' => ['nullable', 'string', Rule::in(['en', 'ar'])],
            'time_slots' => ['nullable', 'array'],
            'time_slots.*.id' => ['nullable', 'integer', 'exists:time_slots,id'],
            'time_slots.*.day_of_week' => ['required_with:time_slots', 'integer', 'between:0,6'],
            'time_slots.*.is_full_day' => ['nullable', 'boolean'],
            'time_slots.*.start_time' => ['required_without:time_slots.*.is_full_day', 'nullable', 'date_format:H:i'],
            'time_slots.*.end_time' => ['required_without:time_slots.*.is_full_day', 'nullable', 'date_format:H:i', 'after:time_slots.*.start_time'],
            'time_slots.*.is_active' => ['nullable', 'boolean'],
            'time_slots.*._delete' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Update user fields
            $userFields = [];
            if ($request->has('name')) {
                $userFields['name'] = $request->input('name');
            }
            if ($request->has('email')) {
                $userFields['email'] = $request->input('email');
            }
            if ($request->has('phone')) {
                $userFields['phone'] = $request->input('phone');
            }
            if ($request->has('is_active')) {
                $userFields['is_active'] = $request->boolean('is_active');
            }
            if ($request->has('locale')) {
                $userFields['locale'] = $request->input('locale');
            }

            if (! empty($userFields)) {
                $serviceProvider->user->update($userFields);
            }

            // Update service provider fields
            $spFields = [];
            if ($request->has('category_id')) {
                $spFields['category_id'] = $request->input('category_id');
            }
            if ($request->has('is_available')) {
                $spFields['is_available'] = $request->boolean('is_available');
            }
            if ($request->has('latitude')) {
                $spFields['latitude'] = $request->input('latitude');
            }
            if ($request->has('longitude')) {
                $spFields['longitude'] = $request->input('longitude');
            }

            if (! empty($spFields)) {
                $serviceProvider->update($spFields);
            }

            // Update time slots if provided
            if ($request->has('time_slots')) {
                foreach ($request->input('time_slots') as $slot) {
                    $isFullDay = $slot['is_full_day'] ?? false;
                    $startTime = $isFullDay ? '00:00' : $slot['start_time'];
                    $endTime = $isFullDay ? '23:59' : $slot['end_time'];

                    if (isset($slot['_delete']) && $slot['_delete'] && isset($slot['id'])) {
                        // Delete time slot
                        TimeSlot::where('id', $slot['id'])
                            ->where('service_provider_id', $serviceProvider->id)
                            ->delete();
                    } elseif (isset($slot['id'])) {
                        // Update existing time slot
                        TimeSlot::where('id', $slot['id'])
                            ->where('service_provider_id', $serviceProvider->id)
                            ->update([
                                'day_of_week' => $slot['day_of_week'],
                                'start_time' => $startTime,
                                'end_time' => $endTime,
                                'is_active' => $slot['is_active'] ?? true,
                            ]);
                    } else {
                        // Create new time slot
                        TimeSlot::create([
                            'service_provider_id' => $serviceProvider->id,
                            'day_of_week' => $slot['day_of_week'],
                            'start_time' => $startTime,
                            'end_time' => $endTime,
                            'is_active' => $slot['is_active'] ?? true,
                        ]);
                    }
                }
            }

            $serviceProvider->refresh();
            $serviceProvider->load([
                'user:id,name,email,phone,profile_photo,is_active,created_at',
                'categories:id,name_en,name_ar,icon',
                'timeSlots',
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('service_providers.updated_successfully'),
                'data' => $this->formatServiceProviderDetail($serviceProvider),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Delete service provider.
     */
    public function destroy(int $id): JsonResponse
    {
        $serviceProvider = ServiceProvider::with('user')->withCount([
            'assignments as active_assignments_count' => fn ($q) => $q->active(),
        ])->find($id);

        if (! $serviceProvider) {
            return response()->json([
                'success' => false,
                'message' => __('service_providers.not_found'),
            ], 404);
        }

        // Check for active assignments
        if ($serviceProvider->active_assignments_count > 0) {
            return response()->json([
                'success' => false,
                'message' => __('service_providers.has_active_assignments', [
                    'count' => $serviceProvider->active_assignments_count,
                ]),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Delete time slots
            $serviceProvider->timeSlots()->delete();

            // Delete service provider profile
            $serviceProvider->delete();

            // Delete user account
            $serviceProvider->user->delete();

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => __('service_providers.deleted_successfully'),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Get service provider availability for a specific date.
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
        $minDurationMinutes = $request->input('min_duration_minutes');

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

            return [
                'id' => $slot->id,
                'day_of_week' => $slot->day_of_week,
                'day_name' => $slot->day_name,
                'start_time' => $startTime,
                'end_time' => $endTime,
                'duration_minutes' => $durationMinutes,
                'display' => $slot->formatted_time_range,
                'is_full_day' => $startTime === '00:00' && $endTime === '23:59',

                // Capacity information
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
        ]);
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

        $duration = $request->input('duration_minutes');
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
                    $minutesToUse = min($capacity['available_minutes'], $remainingNeeded);

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
                                'start_time' => substr($slot->start_time, 0, 5),
                                'end_time' => substr($slot->end_time, 0, 5),
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
        ]);
    }

    /**
     * Format service provider for list response.
     */
    private function formatServiceProvider(ServiceProvider $sp): array
    {
        // Get first category for backward compatibility
        $firstCategory = $sp->categories->first();

        return [
            'id' => $sp->id,
            'user_id' => $sp->user_id,
            'user_name' => $sp->user?->name,
            'user_email' => $sp->user?->email,
            'user_phone' => $sp->user?->phone,
            'user_is_active' => $sp->user?->is_active ?? false,
            'user_profile_photo_url' => $sp->user?->profile_photo_url,
            // Backward compatibility (single category)
            'category_id' => $firstCategory?->id,
            'category' => $firstCategory ? [
                'id' => $firstCategory->id,
                'name_en' => $firstCategory->name_en,
                'name_ar' => $firstCategory->name_ar,
                'icon' => $firstCategory->icon,
            ] : null,
            // Multi-category support
            'category_ids' => $sp->categories->pluck('id')->toArray(),
            'categories' => $sp->categories->map(fn ($cat) => [
                'id' => $cat->id,
                'name_en' => $cat->name_en,
                'name_ar' => $cat->name_ar,
                'icon' => $cat->icon,
            ])->toArray(),
            'is_available' => $sp->is_available,
            'latitude' => $sp->latitude,
            'longitude' => $sp->longitude,
            'assignments_count' => $sp->assignments_count ?? 0,
            'active_jobs' => $sp->active_assignments_count ?? 0,
            'rating' => null, // TODO: Implement rating system
            'created_at' => $sp->created_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * Format service provider for detail response.
     */
    private function formatServiceProviderDetail(ServiceProvider $sp): array
    {
        $firstCategory = $sp->categories->first();

        return [
            'id' => $sp->id,
            'user_id' => $sp->user_id,
            'user_name' => $sp->user?->name,
            'user_email' => $sp->user?->email,
            'user_phone' => $sp->user?->phone,
            'user_is_active' => $sp->user?->is_active ?? false,
            'user_profile_photo_url' => $sp->user?->profile_photo_url,
            'user_locale' => $sp->user?->locale ?? 'en',
            // Backward compatibility (single category)
            'category_id' => $firstCategory?->id,
            'category' => $firstCategory ? [
                'id' => $firstCategory->id,
                'name_en' => $firstCategory->name_en,
                'name_ar' => $firstCategory->name_ar,
                'icon' => $firstCategory->icon,
            ] : null,
            // Multi-category support
            'category_ids' => $sp->categories->pluck('id')->toArray(),
            'categories' => $sp->categories->map(fn ($cat) => [
                'id' => $cat->id,
                'name_en' => $cat->name_en,
                'name_ar' => $cat->name_ar,
                'icon' => $cat->icon,
            ])->toArray(),
            'is_available' => $sp->is_available,
            'location' => $sp->hasLocation() ? [
                'latitude' => $sp->latitude,
                'longitude' => $sp->longitude,
            ] : null,
            'time_slots' => $sp->timeSlots->map(function ($slot) {
                $startTime = Carbon::parse($slot->start_time)->format('H:i');
                $endTime = Carbon::parse($slot->end_time)->format('H:i');

                return [
                    'id' => $slot->id,
                    'day_of_week' => $slot->day_of_week,
                    'day_name' => $slot->day_name,
                    'start_time' => $startTime,
                    'end_time' => $endTime,
                    'display' => $slot->formatted_time_range,
                    'is_full_day' => $startTime === '00:00' && $endTime === '23:59',
                    'is_active' => $slot->is_active,
                ];
            }),
            'assignments_count' => $sp->assignments_count ?? 0,
            'active_jobs' => $sp->active_assignments_count ?? 0,
            'completed_assignments_count' => $sp->completed_assignments_count ?? 0,
            'rating' => null, // TODO: Implement rating system
            'created_at' => $sp->created_at?->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $sp->updated_at?->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
