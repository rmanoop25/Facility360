<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Actions\Issue\ApproveIssueAction;
use App\Actions\Notification\SendFcmNotificationAction;
use App\Enums\AssignmentStatus;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Enums\MediaType;
use App\Enums\NotificationType;
use App\Enums\TimelineAction;
use App\Http\Controllers\Api\V1\ApiController;
use App\Http\Resources\IssueResource;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\IssueMedia;
use App\Models\IssueTimeline;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\TimeSlot;
use App\Models\User;
use App\Models\WorkType;
use App\Notifications\IssueNotification;
use App\Services\TimeSlotAvailabilityService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class AdminIssueController extends ApiController
{
    public function __construct(
        private readonly SendFcmNotificationAction $fcmNotification,
        private readonly ApproveIssueAction $approveIssueAction
    ) {}

    /**
     * List all issues with pagination and filters.
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => ['nullable', 'string', Rule::in(IssueStatus::values())],
            'priority' => ['nullable', 'string', Rule::in(IssuePriority::values())],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'tenant_id' => ['nullable', 'integer', 'exists:tenants,id'],
            'search' => ['nullable', 'string', 'max:255'],
            'sort_by' => ['nullable', 'string', Rule::in(['created_at', 'updated_at', 'priority', 'status'])],
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

        // Load minimal data for list view - assignments not needed in list
        $query = Issue::with([
            'tenant:id,user_id,unit_number,building_name',
            'tenant.user:id,name',
            'categories:id,name_en,name_ar,icon',
        ]);

        // Apply filters
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->filled('priority')) {
            $query->where('priority', $request->input('priority'));
        }

        if ($request->filled('category_id')) {
            $query->whereHas('categories', fn ($q) => $q->where('categories.id', $request->input('category_id')));
        }

        if ($request->filled('tenant_id')) {
            $query->where('tenant_id', $request->input('tenant_id'));
        }

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                    ->orWhere('description', 'like', "%{$search}%")
                    ->orWhere('id', $search);
            });
        }

        // Apply sorting
        $sortBy = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');
        $query->orderBy($sortBy, $sortOrder);

        $perPage = $request->input('per_page', 15);
        $issues = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => IssueResource::collection($issues->items()),
            'meta' => [
                'current_page' => $issues->currentPage(),
                'last_page' => $issues->lastPage(),
                'per_page' => $issues->perPage(),
                'total' => $issues->total(),
            ],
        ], 200, [], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    }

    /**
     * Get single issue with assignments and timeline.
     */
    public function show(int $id): JsonResponse
    {
        $issue = Issue::with([
            'tenant.user:id,name,email,phone,profile_photo',
            'categories:id,name_en,name_ar,icon',
            'media',
            'assignments' => fn ($q) => $q->with([
                'serviceProvider.user:id,name,email,phone,profile_photo',
                'serviceProvider.categories:id,name_en,name_ar',
                'category:id,name_en,name_ar',
                'timeSlot:id,day_of_week,start_time,end_time',
                'consumables.consumable:id,name_en,name_ar',
                'proofs',
            ])->orderBy('created_at', 'desc'),
            'timeline' => fn ($q) => $q->with('performedByUser:id,name')->orderBy('created_at', 'asc')->orderBy('id', 'asc'),
            'cancelledByUser:id,name',
        ])->find($id);

        if (! $issue) {
            return response()->json([
                'success' => false,
                'message' => __('issues.not_found'),
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => new IssueResource($issue),
        ], 200, [], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    }

    /**
     * Create a new issue on behalf of a tenant.
     */
    public function store(Request $request): JsonResponse
    {
        // Check permission
        if (! $request->user()->can('create_issues')) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'tenant_id' => ['required', 'integer', 'exists:tenants,id'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:5000'],
            'priority' => ['sometimes', Rule::in(IssuePriority::values())],
            'category_ids' => ['required', 'array', 'min:1'],
            'category_ids.*' => ['required', 'integer', 'exists:categories,id'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'address' => ['nullable', 'string', 'max:500'],
            'media' => ['nullable', 'array', 'max:10'],
            'media.*' => ['file', 'mimes:jpeg,jpg,png,webp,mp4,mov,webm', 'max:51200'], // 50MB max
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $validated = $validator->validated();
        $tenant = Tenant::find($validated['tenant_id']);

        try {
            DB::beginTransaction();

            // Create the issue
            $issue = Issue::create([
                'tenant_id' => $tenant->id,
                'title' => $validated['title'],
                'description' => $validated['description'] ?? null,
                'priority' => isset($validated['priority'])
                    ? IssuePriority::from($validated['priority'])
                    : IssuePriority::MEDIUM,
                'status' => IssueStatus::PENDING,
                'latitude' => $validated['latitude'] ?? null,
                'longitude' => $validated['longitude'] ?? null,
                'address' => $validated['address'] ?? null,
                'proof_required' => true,
            ]);

            // Attach categories
            $issue->categories()->attach($validated['category_ids']);

            // Handle media uploads
            if ($request->hasFile('media')) {
                foreach ($request->file('media') as $file) {
                    $type = str_starts_with($file->getMimeType(), 'video/')
                        ? MediaType::VIDEO
                        : MediaType::PHOTO;

                    $path = $file->store("issues/{$issue->id}", 'public');

                    IssueMedia::create([
                        'issue_id' => $issue->id,
                        'type' => $type,
                        'file_path' => $path,
                    ]);
                }
            }

            // Create timeline entry with admin as performer
            IssueTimeline::create([
                'issue_id' => $issue->id,
                'action' => TimelineAction::CREATED,
                'performed_by' => auth()->id(),
                'notes' => __('api.issues.created_by_admin', ['admin' => auth()->user()->name]),
                'metadata' => [
                    'created_by_admin' => true,
                    'admin_id' => auth()->id(),
                    'admin_name' => auth()->user()->name,
                    'on_behalf_of_tenant_id' => $tenant->id,
                ],
                'created_at' => now(),
            ]);

            DB::commit();

            // Send notifications after successful creation
            try {
                // Notify the tenant that an issue was created on their behalf
                $tenantUser = $tenant->user;
                if ($tenantUser) {
                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::ISSUE_CREATED,
                        [
                            'title' => $issue->title,
                            'issue_id' => (string) $issue->id,
                        ]
                    );
                }

                // Notify other admins about new issue
                $adminUsers = User::admins()
                    ->where('id', '!=', auth()->id())
                    ->get();

                $this->fcmNotification->toUsers(
                    $adminUsers,
                    NotificationType::ISSUE_CREATED,
                    [
                        'title' => $issue->title,
                        'issue_id' => (string) $issue->id,
                    ]
                );

                // Create database notification for admin panel
                foreach (User::admins()->get() as $admin) {
                    $admin->notify(new IssueNotification($issue, NotificationType::ISSUE_CREATED));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send issue created notification: '.$e->getMessage());
            }

            // Reload with relationships
            $issue->load(['tenant.user', 'categories', 'media', 'timeline.performedByUser']);

            return response()->json([
                'success' => true,
                'message' => __('api.issues.admin_created_success'),
                'data' => new IssueResource($issue),
            ], 201, [], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);

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
     * Update an existing issue.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $issue = Issue::with(['categories', 'media', 'tenant'])->findOrFail($id);

        if (! $request->user()->can('update_issues')) {
            return response()->json(['success' => false, 'message' => __('common.unauthorized')], 403);
        }

        $validated = $request->validate([
            'title' => 'required|string|min:3|max:255',
            'description' => 'nullable|string|max:5000',
            'priority' => 'nullable|in:low,medium,high',
            'category_ids' => 'nullable|array',
            'category_ids.*' => 'integer|exists:categories,id',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'address' => 'nullable|string|max:500',
            'media.*' => 'nullable|file|mimes:jpg,jpeg,png,mp4,mp3,pdf|max:102400',
        ]);

        DB::transaction(function () use ($issue, $validated, $request) {
            $issue->update([
                'title' => $validated['title'],
                'description' => $validated['description'] ?? null,
                'priority' => $validated['priority'] ?? $issue->priority,
                'latitude' => $validated['latitude'] ?? null,
                'longitude' => $validated['longitude'] ?? null,
                'address' => $validated['address'] ?? null,
            ]);

            if (! empty($validated['category_ids'])) {
                $issue->categories()->sync($validated['category_ids']);
            }

            if ($request->hasFile('media')) {
                foreach ($request->file('media') as $file) {
                    $mimeType = $file->getMimeType() ?? 'image/jpeg';
                    $type = match (true) {
                        str_starts_with($mimeType, 'video/') => MediaType::VIDEO,
                        str_starts_with($mimeType, 'audio/') => MediaType::AUDIO,
                        $mimeType === 'application/pdf' => MediaType::PDF,
                        default => MediaType::PHOTO,
                    };
                    $path = $file->store("issues/{$issue->id}", 'public');
                    IssueMedia::create([
                        'issue_id' => $issue->id,
                        'type' => $type,
                        'file_path' => $path,
                    ]);
                }
            }

            IssueTimeline::create([
                'issue_id' => $issue->id,
                'action' => TimelineAction::UPDATED,
                'performed_by' => $request->user()->id,
                'metadata' => ['updated_fields' => array_keys($validated)],
            ]);
        });

        $issue->load(['categories', 'media', 'tenant', 'timeline']);

        return response()->json([
            'success' => true,
            'message' => __('issues.updated_successfully'),
            'data' => new IssueResource($issue),
        ]);
    }

    /**
     * Assign a service provider to an issue.
     */
    public function assign(Request $request, int $id): JsonResponse
    {
        // Check permission
        if (! $request->user()->can('assign_issues')) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'service_provider_id' => ['required', 'integer', 'exists:service_providers,id'],
            'scheduled_date' => ['required', 'date', 'after_or_equal:today'],
            'time_slot_ids' => ['required', 'array', 'min:1'],
            'time_slot_ids.*' => ['integer', 'exists:time_slots,id'],
            'time_slot_id' => ['nullable', 'integer', 'exists:time_slots,id'], // Backward compatibility
            'work_type_id' => ['nullable', 'integer', 'exists:work_types,id'],
            'allocated_duration_minutes' => ['nullable', 'integer', 'min:15', 'max:43200'], // Max 30 days
            'assigned_start_time' => ['nullable', 'date_format:H:i', 'required_with:assigned_end_time'],
            'assigned_end_time' => ['nullable', 'date_format:H:i', 'required_with:assigned_start_time', 'after:assigned_start_time'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        // Normalize: if old single time_slot_id provided, convert to array
        $timeSlotIds = $request->input('time_slot_ids')
            ?? ($request->input('time_slot_id') ? [$request->input('time_slot_id')] : []);

        $issue = Issue::find($id);

        if (! $issue) {
            return response()->json([
                'success' => false,
                'message' => __('issues.not_found'),
            ], 404);
        }

        if (! $issue->canBeAssigned()) {
            return response()->json([
                'success' => false,
                'message' => __('issues.cannot_assign'),
            ], 422);
        }

        $serviceProvider = ServiceProvider::with('user')->find($request->input('service_provider_id'));
        $scheduledDate = \Carbon\Carbon::parse($request->input('scheduled_date'));

        // Validate all slots belong to this service provider (support multi-day assignments)
        $validSlots = TimeSlot::whereIn('id', $timeSlotIds)
            ->where('service_provider_id', $serviceProvider->id)
            ->where('is_active', true)
            ->pluck('id')
            ->toArray();

        if (count($validSlots) !== count($timeSlotIds)) {
            return response()->json([
                'success' => false,
                'message' => __('issues.invalid_time_slots_for_provider'),
            ], 422);
        }

        // Get time slots ordered by start time
        $timeSlots = TimeSlot::whereIn('id', $timeSlotIds)
            ->orderBy('start_time')
            ->get();

        // Handle work type and duration
        $workType = null;
        $allocatedDuration = null;
        $isCustomDuration = false;

        if ($request->filled('work_type_id')) {
            $workType = \App\Models\WorkType::find($request->input('work_type_id'));

            // If admin provided custom duration, use it (requires permission)
            if ($request->filled('allocated_duration_minutes')) {
                if (! $request->user()->can('override_work_type_duration')) {
                    return response()->json([
                        'success' => false,
                        'message' => __('work_types.no_override_permission'),
                    ], 403);
                }
                $allocatedDuration = $request->input('allocated_duration_minutes');
            } else {
                // Use work type's default duration
                $allocatedDuration = $workType->duration_minutes;
            }
        } elseif ($request->filled('allocated_duration_minutes')) {
            // Custom duration without work type
            $allocatedDuration = $request->input('allocated_duration_minutes');
            $isCustomDuration = true;
        }

        // Determine assigned time range (manual override or auto-calculate)
        $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
        $assignedStartTime = null;
        $assignedEndTime = null;

        if ($request->filled('assigned_start_time') && $request->filled('assigned_end_time')) {
            // Manual time override by admin
            $assignedStartTime = $request->input('assigned_start_time').':00';
            $assignedEndTime = $request->input('assigned_end_time').':00';

            // Validate that manual time fits within the combined slot range
            $earliestStart = $timeSlots->min('start_time');
            $latestEnd = $timeSlots->max('end_time');
            $slotStart = \Carbon\Carbon::parse($earliestStart);
            $slotEnd = \Carbon\Carbon::parse($latestEnd);
            $manualStart = \Carbon\Carbon::parse($assignedStartTime);
            $manualEnd = \Carbon\Carbon::parse($assignedEndTime);

            if ($manualStart->lt($slotStart) || $manualEnd->gt($slotEnd)) {
                return response()->json([
                    'success' => false,
                    'message' => __('issues.assigned_time_outside_slots', [
                        'start' => substr($earliestStart, 0, 5),
                        'end' => substr($latestEnd, 0, 5),
                    ]),
                ], 422);
            }
        } else {
            // Auto-calculate: use the full combined range of all selected slots
            $earliestStart = $timeSlots->min('start_time');
            $latestEnd = $timeSlots->max('end_time');
            $assignedStartTime = $earliestStart;
            $assignedEndTime = $latestEnd;
        }

        // Get existing assignment ID to exclude from overlap check (for re-assignment)
        $excludeAssignmentId = $issue->assignments()
            ->where('status', '!=', AssignmentStatus::COMPLETED->value)
            ->latest()
            ->value('id');

        // Check for time overlaps with existing assignments
        if ($availabilityService->hasMultiSlotOverlap(
            $serviceProvider->id,
            $scheduledDate,
            $timeSlotIds,
            $excludeAssignmentId
        )) {
            return response()->json([
                'success' => false,
                'message' => __('issues.time_slots_overlap_with_existing_assignment'),
            ], 422);
        }

        // Validate that selected slots can accommodate the duration
        $totalSlotMinutes = $timeSlots->sum(function ($slot) {
            return \Carbon\Carbon::parse($slot->start_time)
                ->diffInMinutes(\Carbon\Carbon::parse($slot->end_time));
        });

        if ($allocatedDuration && $totalSlotMinutes < $allocatedDuration) {
            return response()->json([
                'success' => false,
                'message' => __('issues.validation.slots_cannot_accommodate_duration', [
                    'slot_minutes' => $totalSlotMinutes,
                    'required_minutes' => $allocatedDuration,
                ]),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Use scheduled_end_date from request (auto-select API) or default to start date
            $scheduledEndDate = $request->filled('scheduled_end_date')
                ? \Carbon\Carbon::parse($request->input('scheduled_end_date'))
                : $scheduledDate;

            // Create assignment (allow multiple assignments for rework/reassignment)
            $assignment = IssueAssignment::create([
                'issue_id' => $issue->id,
                'service_provider_id' => $serviceProvider->id,
                'category_id' => $serviceProvider->categories->first()?->id,
                'time_slot_ids' => $timeSlotIds, // NEW: array of slot IDs
                'time_slot_id' => $timeSlotIds[0] ?? null, // Backward compat: store first slot
                'work_type_id' => $workType?->id,
                'allocated_duration_minutes' => $allocatedDuration,
                'is_custom_duration' => $isCustomDuration,
                'scheduled_date' => $scheduledDate->toDateString(),
                'scheduled_end_date' => $scheduledEndDate->toDateString(), // NEW: Multi-day support
                'assigned_start_time' => $assignedStartTime,
                'assigned_end_time' => $assignedEndTime,
                'status' => AssignmentStatus::ASSIGNED,
                'proof_required' => $issue->proof_required,
                'notes' => $request->input('notes'),
            ]);

            // Update issue status
            $issue->update(['status' => IssueStatus::ASSIGNED]);

            // Create timeline entry
            $timelineMetadata = [
                'service_provider_id' => $serviceProvider->id,
                'service_provider_name' => $serviceProvider->name,
                'scheduled_date' => $scheduledDate->toDateString(),
                'time_slots' => $timeSlots->map(fn ($slot) => $slot->formatted_time_range)->toArray(),
                'time_slot' => $timeSlots->first()?->formatted_time_range, // Backward compat
            ];

            if ($workType) {
                $timelineMetadata['work_type_id'] = $workType->id;
                $timelineMetadata['work_type_name'] = $workType->name_en;
                $timelineMetadata['allocated_duration_minutes'] = $allocatedDuration;
            } elseif ($isCustomDuration) {
                $timelineMetadata['custom_duration_minutes'] = $allocatedDuration;
            }

            IssueTimeline::create([
                'issue_id' => $issue->id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::ASSIGNED,
                'performed_by' => auth()->id(),
                'notes' => $request->input('notes'),
                'metadata' => $timelineMetadata,
                'created_at' => now(),
            ]);

            DB::commit();

            // Load relationships for response
            $assignment->load([
                'serviceProvider.user:id,name,email,phone,profile_photo',
                'timeSlot:id,day_of_week,start_time,end_time',
                'workType:id,name_en,name_ar,duration_minutes',
            ]);

            // Get remaining availability for the scheduled date (capacity-based)
            $dayOfWeek = $scheduledDate->dayOfWeek;
            $dayTimeSlots = TimeSlot::where('service_provider_id', $serviceProvider->id)
                ->where('day_of_week', $dayOfWeek)
                ->where('is_active', true)
                ->get();

            $remainingAvailability = $dayTimeSlots->map(function ($slot) use ($scheduledDate, $availabilityService) {
                $startTime = \Carbon\Carbon::parse($slot->start_time)->format('H:i');
                $endTime = \Carbon\Carbon::parse($slot->end_time)->format('H:i');

                // Get capacity info for this slot
                $capacity = $availabilityService->getSlotCapacity($slot, $scheduledDate);

                return [
                    'id' => $slot->id,
                    'day_of_week' => $slot->day_of_week,
                    'start_time' => $startTime,
                    'end_time' => $endTime,
                    'display' => $slot->formatted_time_range,
                    'is_full_day' => $startTime === '00:00' && $endTime === '23:59',
                    'total_minutes' => $capacity['total_minutes'],
                    'booked_minutes' => $capacity['booked_minutes'],
                    'available_minutes' => $capacity['available_minutes'],
                    'is_available' => $capacity['has_capacity'],
                    'has_capacity' => $capacity['has_capacity'],
                ];
            });

            // Notify service provider about new assignment
            if ($serviceProvider->user) {
                try {
                    Log::info('[FCM] Sending ISSUE_ASSIGNED notification to service provider', [
                        'user_id' => $serviceProvider->user->id,
                        'user_name' => $serviceProvider->user->name,
                        'has_fcm_token' => ! empty($serviceProvider->user->fcm_token),
                    ]);

                    $this->fcmNotification->toUser(
                        $serviceProvider->user,
                        NotificationType::ISSUE_ASSIGNED,
                        [
                            'title' => $issue->title,
                            'issue_id' => (string) $issue->id,
                            'assignment_id' => (string) $assignment->id,
                        ]
                    );

                    Log::info('[FCM] Successfully sent to service provider');
                } catch (\Exception $e) {
                    Log::error('[FCM] Failed to send to service provider', [
                        'error' => $e->getMessage(),
                        'trace' => $e->getTraceAsString(),
                    ]);
                }
            } else {
                Log::warning('[FCM] Service provider has no user account', [
                    'service_provider_id' => $serviceProvider->id,
                ]);
            }

            // Notify tenant that their issue has been assigned
            $issue->load('tenant.user');
            $tenantUser = $issue->tenant?->user;
            if ($tenantUser) {
                try {
                    Log::info('[FCM] Sending ISSUE_ASSIGNED notification to tenant', [
                        'user_id' => $tenantUser->id,
                        'user_name' => $tenantUser->name,
                        'has_fcm_token' => ! empty($tenantUser->fcm_token),
                    ]);

                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::ISSUE_ASSIGNED,
                        ['title' => $issue->title, 'issue_id' => (string) $issue->id]
                    );

                    Log::info('[FCM] Successfully sent to tenant');
                } catch (\Exception $e) {
                    Log::error('[FCM] Failed to send to tenant', [
                        'error' => $e->getMessage(),
                        'trace' => $e->getTraceAsString(),
                    ]);
                }
            }

            // Store database notifications for admin panel
            try {
                Log::info('[NOTIFICATION] Starting ISSUE_ASSIGNED database notifications', [
                    'issue_id' => $issue->id,
                    'issue_title' => $issue->title,
                ]);

                $adminUsers = User::admins()->get();
                Log::info('[NOTIFICATION] Found admin users for notification', [
                    'count' => $adminUsers->count(),
                    'admin_ids' => $adminUsers->pluck('id')->toArray(),
                    'admin_names' => $adminUsers->pluck('name')->toArray(),
                ]);

                foreach ($adminUsers as $admin) {
                    try {
                        $admin->notify(new IssueNotification($issue, NotificationType::ISSUE_ASSIGNED));
                        Log::info('[NOTIFICATION] Successfully sent ISSUE_ASSIGNED notification', [
                            'admin_id' => $admin->id,
                            'admin_name' => $admin->name,
                        ]);
                    } catch (\Exception $e) {
                        Log::error('[NOTIFICATION] Failed to send notification to individual admin', [
                            'admin_id' => $admin->id,
                            'admin_name' => $admin->name,
                            'error' => $e->getMessage(),
                            'trace' => $e->getTraceAsString(),
                        ]);
                    }
                }

                Log::info('[NOTIFICATION] Completed ISSUE_ASSIGNED database notifications');
            } catch (\Exception $e) {
                Log::error('[NOTIFICATION] Failed to send issue assigned database notifications', [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString(),
                ]);
            }

            return response()->json([
                'success' => true,
                'message' => __('issues.assigned_successfully'),
                'data' => [
                    'issue_id' => $issue->id,
                    'assignment' => [
                        'id' => $assignment->id,
                        'service_provider_id' => $assignment->service_provider_id,
                        'category_id' => $assignment->category_id,

                        // TIME SLOT SUPPORT (Multi-slot + Legacy)
                        'time_slot_id' => $assignment->time_slot_id, // Legacy
                        'time_slot_ids' => $assignment->time_slot_ids, // NEW: Array
                        'time_slots' => $timeSlots->map(fn ($s) => [
                            'id' => $s->id,
                            'day_of_week' => $s->day_of_week,
                            'start_time' => $s->start_time->format('H:i'),
                            'end_time' => $s->end_time->format('H:i'),
                            'display' => $s->formatted_time_range,
                        ])->toArray(),

                        // SCHEDULING (Multi-day support + time ranges)
                        'scheduled_date' => $assignment->scheduled_date->format('Y-m-d'),
                        'scheduled_end_date' => $assignment->scheduled_end_date?->format('Y-m-d'), // NEW
                        'assigned_start_time' => $assignment->assigned_start_time, // NEW
                        'assigned_end_time' => $assignment->assigned_end_time, // NEW
                        'assigned_time' => [ // Legacy format
                            'start' => substr($assignedStartTime, 0, 5),
                            'end' => substr($assignedEndTime, 0, 5),
                            'display' => substr($assignedStartTime, 0, 5).' - '.substr($assignedEndTime, 0, 5),
                        ],
                        'is_multi_day' => $assignment->isMultiDay(), // NEW
                        'span_days' => $assignment->getSpanDays(), // NEW

                        // WORK TYPE & DURATION
                        'work_type_id' => $assignment->work_type_id,
                        'work_type' => $workType ? [
                            'id' => $workType->id,
                            'name_en' => $workType->name_en,
                            'name_ar' => $workType->name_ar,
                            'duration_minutes' => $workType->duration_minutes,
                        ] : null,
                        'allocated_duration_minutes' => $assignment->allocated_duration_minutes,
                        'is_custom_duration' => $assignment->is_custom_duration,

                        // STATUS & DURATION
                        'total_duration_minutes' => $assignment->getTotalDurationMinutes(),
                        'status' => $assignment->status->value,
                    ],
                    'provider_availability' => [
                        'date' => $scheduledDate->toDateString(),
                        'day_name' => $scheduledDate->format('l'),
                        'time_slots' => $remainingAvailability,
                        'available_count' => $remainingAvailability->where('has_capacity', true)->count(),
                        'total_count' => $remainingAvailability->count(),
                    ],
                ],
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
     * Update an existing assignment.
     * PUT /api/v1/admin/issues/{issueId}/assignments/{assignmentId}
     */
    public function updateAssignment(Request $request, int $issueId, int $assignmentId): JsonResponse
    {
        // Permission check (use web guard where permissions are defined)
        if (! $request->user()->can('assign_issues')) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'service_provider_id' => ['required', 'integer', 'exists:service_providers,id'],
            'work_type_id' => ['nullable', 'integer', 'exists:work_types,id'],
            'allocated_duration_minutes' => ['nullable', 'integer', 'min:15', 'max:43200'],
            'is_custom_duration' => ['nullable', 'boolean'],
            'scheduled_date' => ['required', 'date', 'after_or_equal:today'],
            'scheduled_end_date' => ['nullable', 'date', 'after_or_equal:scheduled_date'],
            'time_slot_id' => ['nullable', 'integer', 'exists:time_slots,id'],
            'time_slot_ids' => ['nullable', 'array', 'min:1'],
            'time_slot_ids.*' => ['integer', 'exists:time_slots,id'],
            'assigned_start_time' => ['nullable', 'date_format:H:i', 'required_with:assigned_end_time'],
            'assigned_end_time' => ['nullable', 'date_format:H:i', 'required_with:assigned_start_time', 'after:assigned_start_time'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        // Find issue
        $issue = Issue::find($issueId);
        if (! $issue) {
            return response()->json([
                'success' => false,
                'message' => __('issues.not_found'),
            ], 404);
        }

        // Find assignment
        $assignment = IssueAssignment::where('id', $assignmentId)
            ->where('issue_id', $issueId)
            ->first();

        if (! $assignment) {
            return response()->json([
                'success' => false,
                'message' => __('assignments.not_found'),
            ], 404);
        }

        // Check if editable (only ASSIGNED status)
        if ($assignment->status !== AssignmentStatus::ASSIGNED) {
            return response()->json([
                'success' => false,
                'message' => __('assignments.cannot_edit_started'),
            ], 422);
        }

        $serviceProvider = ServiceProvider::with('user', 'categories')->find($request->input('service_provider_id'));

        // Determine which slots to use (array or single)
        $timeSlotIds = $request->input('time_slot_ids', []);
        if (empty($timeSlotIds) && $request->has('time_slot_id')) {
            $timeSlotIds = [$request->input('time_slot_id')];
        }

        if (empty($timeSlotIds)) {
            return response()->json([
                'success' => false,
                'message' => 'At least one time slot must be selected.',
            ], 422);
        }

        // Get work type for duration
        $workType = null;
        if ($request->has('work_type_id')) {
            $workType = WorkType::find($request->input('work_type_id'));
        }

        // Calculate allocated duration
        $allocatedDuration = null;
        $isCustomDuration = $request->boolean('is_custom_duration', false);
        if ($isCustomDuration && $request->has('allocated_duration_minutes')) {
            $allocatedDuration = (int) $request->input('allocated_duration_minutes');
        } elseif ($workType) {
            $allocatedDuration = $workType->duration_minutes;
        }

        // Get scheduled dates
        $scheduledDate = Carbon::parse($request->input('scheduled_date'));
        $scheduledEndDate = $request->has('scheduled_end_date')
            ? Carbon::parse($request->input('scheduled_end_date'))
            : $scheduledDate;

        // Time range overrides
        $assignedStartTime = $request->input('assigned_start_time');
        $assignedEndTime = $request->input('assigned_end_time');

        // Validate time slots belong to service provider
        $validSlots = TimeSlot::whereIn('id', $timeSlotIds)
            ->where('service_provider_id', $serviceProvider->id)
            ->where('is_active', true)
            ->pluck('id')->toArray();

        if (count($validSlots) !== count($timeSlotIds)) {
            return response()->json([
                'success' => false,
                'message' => 'One or more selected time slots do not belong to this service provider or are not active.',
            ], 422);
        }

        // Check availability using TimeSlotAvailabilityService
        $availabilityService = app(TimeSlotAvailabilityService::class);
        if ($availabilityService->hasMultiSlotOverlap(
            $serviceProvider->id,
            $scheduledDate,
            $timeSlotIds,
            $assignmentId  // Exclude this assignment from overlap check
        )) {
            return response()->json([
                'success' => false,
                'message' => 'Selected time slots conflict with an existing assignment for this service provider.',
            ], 422);
        }

        try {
            DB::beginTransaction();

            $oldServiceProviderId = $assignment->service_provider_id;
            $oldScheduledDate = $assignment->scheduled_date;

            // Calculate assigned time range if not manually overridden
            if ($assignedStartTime && $assignedEndTime) {
                // Use manual override
                $finalStartTime = $assignedStartTime;
                $finalEndTime = $assignedEndTime;
            } else {
                // Calculate from selected slots
                $slots = TimeSlot::whereIn('id', $timeSlotIds)->get();
                if ($slots->isNotEmpty()) {
                    $startTimes = $slots->map(fn ($s) => Carbon::parse($s->start_time));
                    $endTimes = $slots->map(fn ($s) => Carbon::parse($s->end_time));
                    $finalStartTime = $startTimes->min()->format('H:i');
                    $finalEndTime = $endTimes->max()->format('H:i');
                } else {
                    $finalStartTime = null;
                    $finalEndTime = null;
                }
            }

            // Update assignment
            $assignment->update([
                'service_provider_id' => $serviceProvider->id,
                'category_id' => $serviceProvider->categories->first()?->id ?? $assignment->category_id,
                'work_type_id' => $workType?->id,
                'allocated_duration_minutes' => $allocatedDuration,
                'is_custom_duration' => $isCustomDuration,
                'time_slot_id' => $timeSlotIds[0] ?? null,
                'time_slot_ids' => $timeSlotIds,
                'scheduled_date' => $scheduledDate->toDateString(),
                'scheduled_end_date' => $scheduledEndDate->toDateString(),
                'assigned_start_time' => $finalStartTime,
                'assigned_end_time' => $finalEndTime,
                'notes' => $request->input('notes'),
            ]);

            // Create timeline entry
            $timelineNotes = "Assignment updated: {$serviceProvider->user->name} on {$scheduledDate->format('M d, Y')}";
            if (count($timeSlotIds) > 1) {
                $timelineNotes .= " ({count($timeSlotIds)} time slots)";
            }
            if ($scheduledDate->toDateString() !== $scheduledEndDate->toDateString()) {
                $timelineNotes .= " to {$scheduledEndDate->format('M d, Y')}";
            }

            IssueTimeline::create([
                'issue_id' => $issue->id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::ASSIGNMENT_UPDATED,
                'performed_by' => auth()->id(),
                'notes' => $timelineNotes,
                'metadata' => [
                    'service_provider_id' => $serviceProvider->id,
                    'service_provider_name' => $serviceProvider->user->name ?? $serviceProvider->name,
                    'scheduled_date' => $scheduledDate->toDateString(),
                    'scheduled_end_date' => $scheduledEndDate->toDateString(),
                    'time_slot_ids' => $timeSlotIds,
                    'time_slot_count' => count($timeSlotIds),
                    'assigned_start_time' => $finalStartTime,
                    'assigned_end_time' => $finalEndTime,
                    'previous_service_provider_id' => $oldServiceProviderId,
                    'previous_scheduled_date' => $oldScheduledDate?->toDateString(),
                ],
                'created_at' => now(),
            ]);

            // Send notifications if SP changed
            if ($oldServiceProviderId !== $serviceProvider->id) {
                // Notify old SP about removal (if different)
                $oldSp = ServiceProvider::with('user')->find($oldServiceProviderId);
                if ($oldSp && $oldSp->user) {
                    try {
                        $this->fcmNotification->toUser(
                            $oldSp->user,
                            NotificationType::ASSIGNMENT_REMOVED,
                            [
                                'issue_id' => (string) $issue->id,
                                'title' => $issue->title,
                            ]
                        );
                    } catch (\Exception $e) {
                        Log::error('Failed to send assignment removed notification', [
                            'user_id' => $oldSp->user->id,
                            'error' => $e->getMessage(),
                        ]);
                    }
                }

                // Notify new SP about assignment
                if ($serviceProvider->user) {
                    try {
                        $this->fcmNotification->toUser(
                            $serviceProvider->user,
                            NotificationType::ISSUE_ASSIGNED,
                            [
                                'issue_id' => (string) $issue->id,
                                'assignment_id' => (string) $assignment->id,
                                'title' => $issue->title,
                                'scheduled_date' => $scheduledDate->format('Y-m-d'),
                            ]
                        );
                    } catch (\Exception $e) {
                        Log::error('Failed to send issue assigned notification', [
                            'user_id' => $serviceProvider->user->id,
                            'error' => $e->getMessage(),
                        ]);
                    }
                }
            }

            DB::commit();

            // Reload issue with all relationships
            $issue->load([
                'tenant.user:id,name,email,phone,profile_photo',
                'categories:id,name_en,name_ar,icon',
                'media',
                'assignments' => fn ($q) => $q->with([
                    'serviceProvider.user:id,name,email,phone,profile_photo',
                    'serviceProvider.categories:id,name_en,name_ar',
                    'category:id,name_en,name_ar',
                    'timeSlot:id,day_of_week,start_time,end_time', // Legacy single slot
                    // Note: timeSlots() is a method, not a relationship - loaded on access
                    'workType:id,name_en,name_ar,duration_minutes', // NEW: Work type
                    'consumables.consumable:id,name_en,name_ar',
                    'proofs',
                ])->orderBy('created_at', 'desc'),
                'timeline' => fn ($q) => $q->with('performedByUser:id,name')->orderBy('created_at', 'asc')->orderBy('id', 'asc'),
                'cancelledByUser:id,name',
            ]);

            return response()->json([
                'success' => true,
                'message' => __('assignments.updated'),
                'data' => new IssueResource($issue),
            ], 200, [], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Update assignment failed', [
                'issue_id' => $issueId,
                'assignment_id' => $assignmentId,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => __('common.operation_failed'),
                'error' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Approve finished work (mark as completed).
     */
    public function approve(Request $request, int $id): JsonResponse
    {
        // Check permission
        if (! $request->user()->can('approve_issues')) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $issue = Issue::with(['assignments'])->find($id);

        if (! $issue) {
            return response()->json([
                'success' => false,
                'message' => __('issues.not_found'),
            ], 404);
        }

        // Use new helper to check if issue can be approved
        if (! $issue->canBeApproved()) {
            return response()->json([
                'success' => false,
                'message' => __('issues.cannot_approve'),
                'data' => [
                    'pending_count' => $issue->getPendingApprovalCount(),
                    'completed_count' => $issue->getCompletedAssignmentCount(),
                    'total_count' => $issue->getTotalAssignmentCount(),
                ],
            ], 422);
        }

        // Get all finished assignments and approve them
        $finishedAssignments = $issue->assignments()
            ->where('status', AssignmentStatus::FINISHED)
            ->get();

        $successCount = 0;
        foreach ($finishedAssignments as $assignment) {
            if ($this->approveIssueAction->execute($assignment, auth()->id())) {
                $successCount++;
            }
        }

        // Refresh issue to get updated status
        $issue->refresh();

        return response()->json([
            'success' => true,
            'message' => __('issues.approved_successfully'),
            'data' => [
                'issue_id' => $issue->id,
                'status' => $issue->status->value,
                'approved_count' => $successCount,
                'total_count' => $issue->getTotalAssignmentCount(),
                'completed_count' => $issue->getCompletedAssignmentCount(),
            ],
        ]);
    }

    /**
     * Cancel an issue with reason.
     */
    public function cancel(Request $request, int $id): JsonResponse
    {
        // Check permission
        if (! $request->user()->can('cancel_issues')) {
            return response()->json([
                'success' => false,
                'message' => __('common.unauthorized'),
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'reason' => ['required', 'string', 'min:10', 'max:1000'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => __('validation.invalid_input'),
                'errors' => $validator->errors(),
            ], 422);
        }

        $issue = Issue::with(['assignments' => fn ($q) => $q->active()])->find($id);

        if (! $issue) {
            return response()->json([
                'success' => false,
                'message' => __('issues.not_found'),
            ], 404);
        }

        if (! $issue->canBeCancelled()) {
            return response()->json([
                'success' => false,
                'message' => __('issues.cannot_cancel'),
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Cancel any active assignments
            foreach ($issue->assignments as $assignment) {
                $assignment->update(['status' => AssignmentStatus::COMPLETED]);
            }

            // Update issue
            $issue->update([
                'status' => IssueStatus::CANCELLED,
                'cancelled_reason' => $request->input('reason'),
                'cancelled_by' => auth()->id(),
                'cancelled_at' => now(),
            ]);

            // Create timeline entry
            IssueTimeline::create([
                'issue_id' => $issue->id,
                'action' => TimelineAction::CANCELLED,
                'performed_by' => auth()->id(),
                'notes' => $request->input('reason'),
                'metadata' => [
                    'cancelled_at' => now()->format('Y-m-d\TH:i:s\Z'),
                ],
                'created_at' => now(),
            ]);

            DB::commit();

            // Notify tenant that issue was cancelled
            $issue->load('tenant.user');
            $tenantUser = $issue->tenant?->user;
            if ($tenantUser) {
                $this->fcmNotification->toUser(
                    $tenantUser,
                    NotificationType::ISSUE_CANCELLED,
                    ['title' => $issue->title, 'issue_id' => (string) $issue->id]
                );
            }

            // Notify assigned service providers about cancellation
            foreach ($issue->assignments as $assignment) {
                $assignment->load('serviceProvider.user');
                $spUser = $assignment->serviceProvider?->user;
                if ($spUser) {
                    $this->fcmNotification->toUser(
                        $spUser,
                        NotificationType::ISSUE_CANCELLED,
                        ['title' => $issue->title, 'issue_id' => (string) $issue->id]
                    );
                }
            }

            // Store database notifications for admin panel
            try {
                $adminUsers = User::admins()->get();
                foreach ($adminUsers as $admin) {
                    $admin->notify(new IssueNotification($issue, NotificationType::ISSUE_CANCELLED));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send issue cancelled database notification: '.$e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => __('issues.cancelled_successfully'),
                'data' => [
                    'issue_id' => $issue->id,
                    'status' => IssueStatus::CANCELLED->value,
                ],
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
     * Format issue detail for response.
     */
    private function formatIssueDetail(Issue $issue): array
    {
        return [
            'id' => $issue->id,
            'title' => $issue->title,
            'description' => $issue->description,
            'status' => $issue->status->value,
            'status_label' => $issue->status->label(),
            'status_color' => $issue->status->color(),
            'priority' => $issue->priority->value,
            'priority_label' => $issue->priority->label(),
            'priority_color' => $issue->priority->color(),
            'proof_required' => $issue->proof_required,
            'location' => $issue->hasLocation() ? [
                'latitude' => $issue->latitude,
                'longitude' => $issue->longitude,
                'address' => $issue->address,
                'directions_url' => $issue->getDirectionsUrl(),
            ] : null,
            'tenant' => $issue->tenant ? [
                'id' => $issue->tenant->id,
                'name' => $issue->tenant->name,
                'email' => $issue->tenant->email,
                'phone' => $issue->tenant->phone,
                'unit_number' => $issue->tenant->unit_number,
                'building_name' => $issue->tenant->building_name,
            ] : null,
            'categories' => $issue->categories->map(fn ($cat) => [
                'id' => $cat->id,
                'name' => $cat->name,
                'icon' => $cat->icon,
            ]),
            'media' => $issue->media->map(fn ($m) => [
                'id' => $m->id,
                'type' => $m->type,
                'url' => $m->url,
                'thumbnail_url' => $m->thumbnail_url,
            ]),
            'assignments' => $issue->assignments->map(fn ($a) => [
                'id' => $a->id,
                'status' => $a->status->value,
                'status_label' => $a->status->label(),
                'scheduled_date' => $a->scheduled_date?->format('Y-m-d'),
                'time_slot' => $a->timeSlot ? [
                    'id' => $a->timeSlot->id,
                    'display' => $a->timeSlot->formatted_time_range,
                ] : null,
                'service_provider' => $a->serviceProvider ? [
                    'id' => $a->serviceProvider->id,
                    'name' => $a->serviceProvider->name,
                    'phone' => $a->serviceProvider->phone,
                    'categories' => $a->serviceProvider->categories->map(fn ($c) => [
                        'id' => $c->id,
                        'name' => $c->name,
                    ]),
                ] : null,
                'started_at' => $a->started_at?->format('Y-m-d\TH:i:s\Z'),
                'finished_at' => $a->finished_at?->format('Y-m-d\TH:i:s\Z'),
                'completed_at' => $a->completed_at?->format('Y-m-d\TH:i:s\Z'),
                'duration_minutes' => $a->getDurationInMinutes(),
                'consumables' => $a->consumables->map(fn ($c) => [
                    'id' => $c->consumable_id,
                    'name' => $c->consumable?->name,
                    'quantity' => $c->quantity,
                ]),
                'proofs' => $a->proofs->map(fn ($p) => [
                    'id' => $p->id,
                    'stage' => $p->stage,
                    'type' => $p->type,
                    'url' => $p->url,
                ]),
                'notes' => $a->notes,
            ]),
            'timeline' => $issue->timeline->map(fn ($t) => [
                'id' => $t->id,
                'action' => $t->action->value,
                'action_label' => $t->action->label(),
                'action_color' => $t->action->color(),
                'action_icon' => $t->action->icon(),
                'performed_by' => $t->performedByUser?->name ?? 'System',
                'notes' => $t->notes,
                'metadata' => $t->metadata,
                'created_at' => $t->created_at?->format('Y-m-d\TH:i:s\Z'),
            ]),
            'cancelled_reason' => $issue->cancelled_reason,
            'cancelled_by' => $issue->cancelledByUser?->name,
            'cancelled_at' => $issue->cancelled_at?->format('Y-m-d\TH:i:s\Z'),
            'created_at' => $issue->created_at->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $issue->updated_at->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
