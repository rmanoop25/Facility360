<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Actions\Notification\SendFcmNotificationAction;
use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\NotificationType;
use App\Enums\ProofStage;
use App\Enums\ProofType;
use App\Enums\TimelineAction;
use App\Models\IssueAssignment;
use App\Models\IssueAssignmentConsumable;
use App\Models\IssueTimeline;
use App\Models\Proof;
use App\Models\User;
use App\Notifications\IssueNotification;
use App\Settings\IssueSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class AssignmentController extends ApiController
{
    public function __construct(
        private readonly SendFcmNotificationAction $fcmNotification
    ) {}

    /**
     * List service provider's assignments (paginated).
     */
    public function index(Request $request): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isServiceProvider()) {
            return $this->forbidden(__('api.service_provider_only'));
        }

        $serviceProvider = $user->serviceProvider;

        $query = IssueAssignment::with([
            'issue' => function ($query) {
                $query->with(['categories', 'media', 'tenant.user']);
            },
            'category',
            'timeSlot', // Legacy single slot
            // Note: timeSlots() is a method, not a relationship - loaded on access
            'workType', // NEW: Work type
        ])
            ->forServiceProvider($serviceProvider->id)
            ->orderBy('scheduled_date', 'asc')
            ->orderBy('created_at', 'desc');

        // Filter by status
        if ($request->has('status') && $request->status) {
            $status = AssignmentStatus::tryFrom($request->status);
            if ($status) {
                $query->where('status', $status);
            }
        }

        // Filter by date
        if ($request->has('date') && $request->date) {
            $query->scheduledOn($request->date);
        }

        // Filter active assignments only
        if ($request->boolean('active_only')) {
            $query->active();
        }

        // Filter in-progress only
        if ($request->boolean('in_progress_only')) {
            $query->inProgress();
        }

        $perPage = min($request->integer('per_page', 15), 50);
        $assignments = $query->paginate($perPage);

        // Transform data
        $assignments->getCollection()->transform(
            fn (IssueAssignment $assignment) => $this->transformAssignment($assignment)
        );

        return $this->paginated($assignments, __('api.assignments.list_success'));
    }

    /**
     * Get assignment details.
     * Note: $id parameter is actually the issue_id (for mobile app compatibility)
     */
    public function show(int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isServiceProvider()) {
            return $this->forbidden(__('api.service_provider_only'));
        }

        $serviceProvider = $user->serviceProvider;

        $assignment = IssueAssignment::with([
            'issue' => function ($query) {
                $query->with([
                    'categories',
                    'media',
                    'tenant.user',
                    'timeline.performedByUser',
                ]);
            },
            'category',
            'timeSlot', // Legacy
            // Note: timeSlots() is a method, not a relationship - loaded on access
            'workType', // NEW: Work type
            'proofs',
            'consumables.consumable',
            'timeline.performedByUser',
            'timeExtensionRequests.responder', // NEW: Extension requests with responder name
        ])
            ->forServiceProvider($serviceProvider->id)
            ->where('issue_id', $id)
            ->first();

        if (! $assignment) {
            return $this->notFound(__('api.assignments.not_found'));
        }

        return $this->success(
            $this->transformAssignmentDetailed($assignment),
            __('api.assignments.show_success')
        );
    }

    /**
     * Start work on assignment.
     * Note: $id parameter is actually the issue_id (for mobile app compatibility)
     */
    public function start(int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isServiceProvider()) {
            return $this->forbidden(__('api.service_provider_only'));
        }

        $serviceProvider = $user->serviceProvider;

        $assignment = IssueAssignment::with('issue')
            ->forServiceProvider($serviceProvider->id)
            ->where('issue_id', $id)
            ->first();

        if (! $assignment) {
            return $this->notFound(__('api.assignments.not_found'));
        }

        if (! $assignment->canStart()) {
            return $this->error(
                __('api.assignments.cannot_start'),
                400
            );
        }

        try {
            DB::beginTransaction();

            $now = now();

            // Update assignment
            $assignment->update([
                'status' => AssignmentStatus::IN_PROGRESS,
                'started_at' => $now,
            ]);

            // Update parent issue status
            $assignment->issue->update([
                'status' => IssueStatus::IN_PROGRESS,
            ]);

            // Create timeline entry
            IssueTimeline::create([
                'issue_id' => $assignment->issue_id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::STARTED,
                'performed_by' => $user->id,
                'created_at' => $now,
            ]);

            DB::commit();

            $assignment->refresh();
            $assignment->load([
                'issue.categories',
                'issue.media',
                'issue.tenant.user',
                'category',
                'timeSlot',
            ]);

            // Notify tenant that work has started
            $tenantUser = $assignment->issue->tenant?->user;
            if ($tenantUser) {
                $this->fcmNotification->toUser(
                    $tenantUser,
                    NotificationType::WORK_STARTED,
                    ['title' => $assignment->issue->title, 'issue_id' => (string) $assignment->issue_id]
                );
            }

            // Store database notifications for admin panel
            try {
                $adminUsers = User::admins()->get();
                foreach ($adminUsers as $admin) {
                    $admin->notify(new IssueNotification($assignment->issue, NotificationType::WORK_STARTED));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send work started database notification: '.$e->getMessage());
            }

            return $this->success(
                $this->transformAssignment($assignment),
                __('api.assignments.started_success')
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.assignments.start_failed'),
                500
            );
        }
    }

    /**
     * Put assignment on hold.
     * Note: $id parameter is actually the issue_id (for mobile app compatibility)
     */
    public function hold(Request $request, int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isServiceProvider()) {
            return $this->forbidden(__('api.service_provider_only'));
        }

        $serviceProvider = $user->serviceProvider;

        $assignment = IssueAssignment::with('issue')
            ->forServiceProvider($serviceProvider->id)
            ->where('issue_id', $id)
            ->first();

        if (! $assignment) {
            return $this->notFound(__('api.assignments.not_found'));
        }

        if (! $assignment->canHold()) {
            return $this->error(
                __('api.assignments.cannot_hold'),
                400
            );
        }

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        try {
            DB::beginTransaction();

            $now = now();

            // Update assignment
            $assignment->update([
                'status' => AssignmentStatus::ON_HOLD,
                'held_at' => $now,
            ]);

            // Update parent issue status
            $assignment->issue->update([
                'status' => IssueStatus::ON_HOLD,
            ]);

            // Create timeline entry
            IssueTimeline::create([
                'issue_id' => $assignment->issue_id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::HELD,
                'performed_by' => $user->id,
                'notes' => $validated['reason'] ?? null,
                'created_at' => $now,
            ]);

            DB::commit();

            $assignment->refresh();
            $assignment->load([
                'issue.categories',
                'issue.media',
                'issue.tenant.user',
                'category',
                'timeSlot',
            ]);

            // Notify tenant that work is on hold
            $tenantUser = $assignment->issue->tenant?->user;
            if ($tenantUser) {
                $this->fcmNotification->toUser(
                    $tenantUser,
                    NotificationType::WORK_ON_HOLD,
                    ['title' => $assignment->issue->title, 'issue_id' => (string) $assignment->issue_id]
                );
            }

            // Store database notifications for admin panel
            try {
                $adminUsers = User::admins()->get();
                foreach ($adminUsers as $admin) {
                    $admin->notify(new IssueNotification($assignment->issue, NotificationType::WORK_ON_HOLD));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send work on hold database notification: '.$e->getMessage());
            }

            return $this->success(
                $this->transformAssignment($assignment),
                __('api.assignments.held_success')
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.assignments.hold_failed'),
                500
            );
        }
    }

    /**
     * Resume work on assignment.
     * Note: $id parameter is actually the issue_id (for mobile app compatibility)
     */
    public function resume(int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isServiceProvider()) {
            return $this->forbidden(__('api.service_provider_only'));
        }

        $serviceProvider = $user->serviceProvider;

        $assignment = IssueAssignment::with('issue')
            ->forServiceProvider($serviceProvider->id)
            ->where('issue_id', $id)
            ->first();

        if (! $assignment) {
            return $this->notFound(__('api.assignments.not_found'));
        }

        if (! $assignment->canResume()) {
            return $this->error(
                __('api.assignments.cannot_resume'),
                400
            );
        }

        try {
            DB::beginTransaction();

            $now = now();

            // Update assignment
            $assignment->update([
                'status' => AssignmentStatus::IN_PROGRESS,
                'resumed_at' => $now,
            ]);

            // Update parent issue status
            $assignment->issue->update([
                'status' => IssueStatus::IN_PROGRESS,
            ]);

            // Create timeline entry
            IssueTimeline::create([
                'issue_id' => $assignment->issue_id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::RESUMED,
                'performed_by' => $user->id,
                'created_at' => $now,
            ]);

            DB::commit();

            $assignment->refresh();
            $assignment->load([
                'issue.categories',
                'issue.media',
                'issue.tenant.user',
                'category',
                'timeSlot',
            ]);

            // Notify tenant that work has resumed
            $tenantUser = $assignment->issue->tenant?->user;
            if ($tenantUser) {
                $this->fcmNotification->toUser(
                    $tenantUser,
                    NotificationType::WORK_RESUMED,
                    ['title' => $assignment->issue->title, 'issue_id' => (string) $assignment->issue_id]
                );
            }

            // Store database notifications for admin panel
            try {
                $adminUsers = User::admins()->get();
                foreach ($adminUsers as $admin) {
                    $admin->notify(new IssueNotification($assignment->issue, NotificationType::WORK_RESUMED));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send work resumed database notification: '.$e->getMessage());
            }

            return $this->success(
                $this->transformAssignment($assignment),
                __('api.assignments.resumed_success')
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.assignments.resume_failed'),
                500
            );
        }
    }

    /**
     * Finish work on assignment (with proofs, consumables, notes).
     * Note: $id parameter is actually the issue_id (for mobile app compatibility)
     */
    public function finish(Request $request, int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isServiceProvider()) {
            return $this->forbidden(__('api.service_provider_only'));
        }

        $serviceProvider = $user->serviceProvider;

        $assignment = IssueAssignment::with('issue')
            ->forServiceProvider($serviceProvider->id)
            ->where('issue_id', $id)
            ->first();

        if (! $assignment) {
            return $this->notFound(__('api.assignments.not_found'));
        }

        if (! $assignment->canFinish()) {
            return $this->error(
                __('api.assignments.cannot_finish'),
                400
            );
        }

        $validated = $request->validate([
            'notes' => ['nullable', 'string', 'max:5000'],
            'proofs' => ['nullable', 'array', 'max:20'],
            'proofs.*' => ['file', 'mimes:jpg,jpeg,png,mp4,mp3,pdf', 'max:102400'], // 100MB max
            'consumables' => ['nullable', 'array'],
            'consumables.*.consumable_id' => ['nullable', 'integer', 'exists:consumables,id'],
            'consumables.*.custom_name' => ['nullable', 'string', 'max:255'],
            'consumables.*.quantity' => ['required_with:consumables.*', 'integer', 'min:1'],
        ]);

        // Validate proof requirement
        if ($assignment->proof_required) {
            if (empty($validated['proofs']) && ! $request->hasFile('proofs')) {
                return $this->validationError(
                    ['proofs' => [__('api.assignments.proof_required')]],
                    __('api.assignments.proof_required')
                );
            }
        }

        try {
            DB::beginTransaction();

            $now = now();

            // Handle proof uploads
            if ($request->hasFile('proofs')) {
                foreach ($request->file('proofs') as $file) {
                    $mimeType = $file->getMimeType();

                    // Determine type from MIME
                    $type = match (true) {
                        str_starts_with($mimeType, 'video/') => ProofType::VIDEO,
                        str_starts_with($mimeType, 'audio/') => ProofType::AUDIO,
                        $mimeType === 'application/pdf' => ProofType::PDF,
                        default => ProofType::PHOTO,
                    };

                    $path = $file->store("proofs/{$assignment->id}", 'public');

                    Proof::create([
                        'issue_assignment_id' => $assignment->id,
                        'type' => $type,
                        'file_path' => $path,
                        'stage' => ProofStage::COMPLETION,
                    ]);
                }
            }

            // Handle consumables
            if (! empty($validated['consumables'])) {
                foreach ($validated['consumables'] as $consumableData) {
                    // Skip if neither consumable_id nor custom_name is provided
                    if (empty($consumableData['consumable_id']) && empty($consumableData['custom_name'])) {
                        continue;
                    }

                    IssueAssignmentConsumable::create([
                        'issue_assignment_id' => $assignment->id,
                        'consumable_id' => $consumableData['consumable_id'] ?? null,
                        'custom_name' => $consumableData['custom_name'] ?? null,
                        'quantity' => $consumableData['quantity'],
                    ]);
                }
            }

            // Update assignment to FINISHED first
            $assignment->update([
                'status' => AssignmentStatus::FINISHED,
                'finished_at' => $now,
                'notes' => $validated['notes'] ?? $assignment->notes,
            ]);

            // Check if auto-approval is enabled
            $issueSettings = app(IssueSettings::class);
            $issue = $assignment->issue;

            Log::info('[AUTO-APPROVAL] Checking auto-approval setting', [
                'issue_id' => $assignment->issue_id,
                'assignment_id' => $assignment->id,
                'auto_approve_enabled' => $issueSettings->auto_approve_finished_issues,
            ]);

            // Create FINISHED timeline entry first (always)
            IssueTimeline::create([
                'issue_id' => $assignment->issue_id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::FINISHED,
                'performed_by' => $user->id,
                'notes' => $validated['notes'] ?? null,
                'metadata' => [
                    'proof_count' => $request->hasFile('proofs') ? count($request->file('proofs')) : 0,
                    'consumable_count' => count($validated['consumables'] ?? []),
                    'duration_minutes' => $assignment->started_at
                        ? $assignment->started_at->diffInMinutes($now)
                        : null,
                ],
                'created_at' => $now,
            ]);

            if ($issueSettings->auto_approve_finished_issues) {
                // Auto-approve: Set this assignment to COMPLETED
                $assignment->update([
                    'status' => AssignmentStatus::COMPLETED,
                    'completed_at' => $now,
                ]);

                // Recalculate issue status based on ALL assignments
                $newIssueStatus = $issue->calculateStatusFromAssignments();
                $issue->update(['status' => $newIssueStatus]);

                $issueFullyCompleted = $newIssueStatus === IssueStatus::COMPLETED;

                // Create APPROVED timeline entry (by System)
                IssueTimeline::create([
                    'issue_id' => $assignment->issue_id,
                    'issue_assignment_id' => $assignment->id,
                    'action' => TimelineAction::APPROVED,
                    'performed_by' => null, // NULL = System
                    'metadata' => [
                        'approved_at' => $now->format('Y-m-d\TH:i:s\Z'),
                        'auto_approved' => true,
                        'issue_status' => $newIssueStatus->value,
                        'issue_fully_completed' => $issueFullyCompleted,
                    ],
                    'created_at' => $now,
                ]);
            } else {
                // Normal flow: Set assignment to FINISHED, recalculate issue status
                $newIssueStatus = $issue->calculateStatusFromAssignments();
                $issue->update(['status' => $newIssueStatus]);

                $issueFullyCompleted = false; // Not completed since waiting for approval
            }

            DB::commit();

            $assignment->refresh();
            $assignment->load([
                'issue.categories',
                'issue.media',
                'issue.tenant.user',
                'category',
                'timeSlot',
                'proofs',
                'consumables.consumable',
            ]);

            // Notify tenant with appropriate message
            $tenantUser = $assignment->issue->tenant?->user;
            if ($tenantUser) {
                if ($issueSettings->auto_approve_finished_issues && $issueFullyCompleted) {
                    // Issue fully completed
                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::ISSUE_COMPLETED,
                        ['title' => $assignment->issue->title, 'issue_id' => (string) $assignment->issue_id]
                    );
                } elseif ($issueSettings->auto_approve_finished_issues) {
                    // Partial progress (auto-approved but not all done)
                    $completedCount = $assignment->issue->getCompletedAssignmentCount();
                    $totalCount = $assignment->issue->getTotalAssignmentCount();

                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::PARTIAL_PROGRESS,
                        [
                            'title' => $assignment->issue->title,
                            'issue_id' => (string) $assignment->issue_id,
                            'completed' => (string) $completedCount,
                            'total' => (string) $totalCount,
                        ]
                    );
                } else {
                    // Work finished, awaiting approval
                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::WORK_FINISHED,
                        ['title' => $assignment->issue->title, 'issue_id' => (string) $assignment->issue_id]
                    );
                }
            }

            // If auto-approved, also notify service provider
            if ($issueSettings->auto_approve_finished_issues) {
                $spUser = $assignment->serviceProvider?->user;
                if ($spUser) {
                    $spNotificationType = $issueFullyCompleted
                        ? NotificationType::ISSUE_COMPLETED
                        : NotificationType::ASSIGNMENT_APPROVED;

                    $this->fcmNotification->toUser(
                        $spUser,
                        $spNotificationType,
                        ['title' => $assignment->issue->title, 'issue_id' => (string) $assignment->issue_id]
                    );
                }
            }

            // Store database notifications for admin panel
            try {
                // Only send admin notifications when issue is fully completed or work finished (awaiting approval)
                $notificationType = null;
                if ($issueSettings->auto_approve_finished_issues && $issueFullyCompleted) {
                    $notificationType = NotificationType::ISSUE_COMPLETED;
                } elseif (! $issueSettings->auto_approve_finished_issues) {
                    $notificationType = NotificationType::WORK_FINISHED;
                }

                if ($notificationType) {
                    Log::info('[NOTIFICATION] Starting database notifications', [
                        'issue_id' => $assignment->issue_id,
                        'issue_title' => $assignment->issue->title,
                        'assignment_id' => $assignment->id,
                        'type' => $notificationType->value,
                        'auto_approved' => $issueSettings->auto_approve_finished_issues,
                        'issue_fully_completed' => $issueFullyCompleted,
                    ]);

                    $adminUsers = User::admins()->get();
                    Log::info('[NOTIFICATION] Found admin users for notification', [
                        'count' => $adminUsers->count(),
                        'admin_ids' => $adminUsers->pluck('id')->toArray(),
                    ]);

                    foreach ($adminUsers as $admin) {
                        try {
                            $admin->notify(new IssueNotification($assignment->issue, $notificationType));
                            Log::info('[NOTIFICATION] Successfully sent notification', [
                                'admin_id' => $admin->id,
                                'admin_name' => $admin->name,
                                'type' => $notificationType->value,
                            ]);
                        } catch (\Exception $e) {
                            Log::error('[NOTIFICATION] Failed to send notification to individual admin', [
                                'admin_id' => $admin->id,
                                'error' => $e->getMessage(),
                                'trace' => $e->getTraceAsString(),
                            ]);
                        }
                    }

                    Log::info('[NOTIFICATION] Completed database notifications');
                }
            } catch (\Exception $e) {
                Log::error('[NOTIFICATION] Failed to send database notifications', [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString(),
                ]);
            }

            return $this->success(
                $this->transformAssignmentDetailed($assignment),
                __('api.assignments.finished_success')
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.assignments.finish_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Transform assignment for list view.
     */
    private function transformAssignment(IssueAssignment $assignment): array
    {
        return [
            'id' => $assignment->id,
            'issue_id' => $assignment->issue_id,
            'service_provider_id' => $assignment->service_provider_id,
            'category_id' => $assignment->category_id,

            // TIME SLOT SUPPORT (Multi-slot + Legacy single slot)
            'time_slot_id' => $assignment->time_slot_id, // Legacy
            'time_slot_ids' => $assignment->time_slot_ids, // NEW: Array
            'time_slot' => $assignment->timeSlot ? [
                'id' => $assignment->timeSlot->id,
                'day_of_week' => $assignment->timeSlot->day_of_week,
                'start_time' => $assignment->timeSlot->start_time?->format('H:i'),
                'end_time' => $assignment->timeSlot->end_time?->format('H:i'),
                'display_name' => $assignment->timeSlot->display_name,
            ] : null,
            'time_slots' => $assignment->timeSlots()->map(fn ($slot) => [ // NEW: Multi-slot collection (method call)
                'id' => $slot->id,
                'day_of_week' => $slot->day_of_week,
                'start_time' => $slot->start_time?->format('H:i'),
                'end_time' => $slot->end_time?->format('H:i'),
                'display_name' => $slot->display_name,
            ])->toArray(),

            // SCHEDULING (Multi-day support + time ranges)
            'scheduled_date' => $assignment->scheduled_date?->format('Y-m-d'),
            'scheduled_end_date' => $assignment->scheduled_end_date?->format('Y-m-d'), // NEW
            'assigned_start_time' => $assignment->assigned_start_time, // NEW: H:i:s format
            'assigned_end_time' => $assignment->assigned_end_time, // NEW: H:i:s format
            'is_multi_day' => $assignment->isMultiDay(), // NEW
            'span_days' => $assignment->getSpanDays(), // NEW

            // WORK TYPE & DURATION
            'work_type_id' => $assignment->work_type_id,
            'work_type' => $assignment->workType ? [
                'id' => $assignment->workType->id,
                'name' => $assignment->workType->name,
                'description' => $assignment->workType->description,
                'duration_minutes' => $assignment->workType->duration_minutes,
            ] : null,
            'allocated_duration_minutes' => $assignment->allocated_duration_minutes,
            'is_custom_duration' => $assignment->is_custom_duration,

            'status' => [
                'value' => $assignment->status->value,
                'label' => $assignment->status->label(),
                'color' => $assignment->status->color(),
            ],
            'issue' => [
                'id' => $assignment->issue->id,
                'title' => $assignment->issue->title,
                'description' => $assignment->issue->description,
                'status' => [
                    'value' => $assignment->issue->status->value,
                    'label' => $assignment->issue->status->label(),
                    'color' => $assignment->issue->status->color(),
                ],
                'priority' => [
                    'value' => $assignment->issue->priority->value,
                    'label' => $assignment->issue->priority->label(),
                ],
                'categories' => $assignment->issue->categories->map(fn ($cat) => [
                    'id' => $cat->id,
                    'name' => $cat->name,
                    'icon' => $cat->icon,
                ]),
                'location' => $assignment->issue->hasLocation() ? [
                    'latitude' => (float) $assignment->issue->latitude,
                    'longitude' => (float) $assignment->issue->longitude,
                    'directions_url' => $assignment->issue->getDirectionsUrl(),
                ] : null,
                'media' => $assignment->issue->media->map(fn ($m) => [
                    'id' => $m->id,
                    'type' => $m->type->value,
                    'url' => $m->url,
                ]),
                'tenant' => [
                    'id' => $assignment->issue->tenant->id,
                    'name' => $assignment->issue->tenant->name,
                    'phone' => $assignment->issue->tenant->phone,
                    'unit_number' => $assignment->issue->tenant->unit_number,
                    'building_name' => $assignment->issue->tenant->building_name,
                ],
            ],
            'category' => $assignment->category ? [
                'id' => $assignment->category->id,
                'name' => $assignment->category->name,
            ] : null,
            'proof_required' => $assignment->proof_required,
            'started_at' => $assignment->started_at?->format('Y-m-d\TH:i:s\Z'),
            'held_at' => $assignment->held_at?->format('Y-m-d\TH:i:s\Z'),
            'resumed_at' => $assignment->resumed_at?->format('Y-m-d\TH:i:s\Z'),
            'finished_at' => $assignment->finished_at?->format('Y-m-d\TH:i:s\Z'),
            'completed_at' => $assignment->completed_at?->format('Y-m-d\TH:i:s\Z'),
            'can_start' => $assignment->canStart(),
            'can_hold' => $assignment->canHold(),
            'can_resume' => $assignment->canResume(),
            'can_finish' => $assignment->canFinish(),
            'created_at' => $assignment->created_at->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $assignment->updated_at->format('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * Transform assignment for detailed view.
     */
    private function transformAssignmentDetailed(IssueAssignment $assignment): array
    {
        $base = $this->transformAssignment($assignment);

        $base['notes'] = $assignment->notes;
        $base['duration_minutes'] = $assignment->getDurationInMinutes();

        // Extension requests (with admin notes so SP sees admin response)
        if ($assignment->relationLoaded('timeExtensionRequests')) {
            $base['extension_requests'] = $assignment->timeExtensionRequests->map(fn ($ext) => [
                'id' => $ext->id,
                'requested_minutes' => $ext->requested_minutes,
                'reason' => $ext->reason,
                'status' => $ext->status->value,
                'status_label' => $ext->status->label(),
                'admin_notes' => $ext->admin_notes,
                'responder_name' => $ext->responder?->name,
                'requested_at' => $ext->requested_at?->format('Y-m-d\TH:i:s\Z'),
                'responded_at' => $ext->responded_at?->format('Y-m-d\TH:i:s\Z'),
            ])->toArray();
        }

        $base['proofs'] = $assignment->proofs->map(fn ($proof) => [
            'id' => $proof->id,
            'type' => [
                'value' => $proof->type->value,
                'label' => $proof->type->label(),
            ],
            'stage' => [
                'value' => $proof->stage->value,
                'label' => $proof->stage->label(),
            ],
            'url' => $proof->url,
        ]);

        $base['consumables'] = $assignment->consumables->map(fn ($c) => [
            'id' => $c->id,
            'name' => $c->name,
            'quantity' => $c->quantity,
            'is_custom' => $c->is_custom,
            'consumable' => $c->consumable ? [
                'id' => $c->consumable->id,
                'name' => $c->consumable->name,
            ] : null,
        ]);

        if ($assignment->relationLoaded('timeline')) {
            $base['timeline'] = $assignment->timeline->map(fn ($entry) => [
                'id' => $entry->id,
                'action' => [
                    'value' => $entry->action->value,
                    'label' => $entry->action->label(),
                    'color' => $entry->action->color(),
                    'icon' => $entry->action->icon(),
                ],
                'performed_by' => $entry->performedByUser ? [
                    'id' => $entry->performedByUser->id,
                    'name' => $entry->performedByUser->name,
                ] : null,
                'notes' => $entry->notes,
                'metadata' => $entry->metadata,
                'created_at' => $entry->created_at?->format('Y-m-d\TH:i:s\Z'),
            ]);
        }

        // Add sibling assignments info (other assignments on the same issue)
        $siblingAssignments = IssueAssignment::where('issue_id', $assignment->issue_id)
            ->where('id', '!=', $assignment->id)
            ->with(['serviceProvider.user', 'category'])
            ->get();

        $base['sibling_assignments_count'] = $siblingAssignments->count();
        $base['sibling_assignments'] = $siblingAssignments->map(fn ($sibling) => [
            'id' => $sibling->id,
            'service_provider_name' => $sibling->serviceProvider?->user?->name,
            'category' => $sibling->category ? [
                'id' => $sibling->category->id,
                'name' => $sibling->category->name,
            ] : null,
            'status' => [
                'value' => $sibling->status->value,
                'label' => $sibling->status->label(),
            ],
            'scheduled_date' => $sibling->scheduled_date?->format('Y-m-d'),
        ]);

        return $base;
    }
}
