<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Actions\Notification\SendFcmNotificationAction;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Enums\MediaType;
use App\Enums\NotificationType;
use App\Enums\TimelineAction;
use App\Models\Issue;
use App\Models\IssueMedia;
use App\Models\IssueTimeline;
use App\Models\User;
use App\Notifications\IssueNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class IssueController extends ApiController
{
    public function __construct(
        private readonly SendFcmNotificationAction $fcmNotification
    ) {}

    /**
     * List authenticated tenant's issues (paginated).
     */
    public function index(Request $request): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isTenant()) {
            return $this->forbidden(__('api.tenant_only'));
        }

        $tenant = $user->tenant;

        $query = Issue::with([
            'categories',
            'media',
            'assignments' => function ($query) {
                $query->with([
                    'serviceProvider.user',
                    'timeSlot', // Legacy single slot
                    // Note: timeSlots() is a method, not a relationship - loaded on access
                    'workType', // NEW: Work type
                    'category',
                ]);
            },
        ])
            ->forTenant($tenant->id)
            ->orderBy('created_at', 'desc');

        // Filter by status
        if ($request->has('status') && $request->status) {
            $status = IssueStatus::tryFrom($request->status);
            if ($status) {
                $query->withStatus($status);
            }
        }

        // Filter by priority
        if ($request->has('priority') && $request->priority) {
            $priority = IssuePriority::tryFrom($request->priority);
            if ($priority) {
                $query->where('priority', $priority);
            }
        }

        // Filter active issues only
        if ($request->boolean('active_only')) {
            $query->active();
        }

        $perPage = min($request->integer('per_page', 15), 50);
        $issues = $query->paginate($perPage);

        // Transform data
        $issues->getCollection()->transform(fn (Issue $issue) => $this->transformIssue($issue));

        return $this->paginated($issues, __('api.issues.list_success'));
    }

    /**
     * Create a new issue.
     */
    public function store(Request $request): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isTenant()) {
            return $this->forbidden(__('api.tenant_only'));
        }

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string', 'max:5000'],
            'priority' => ['sometimes', Rule::enum(IssuePriority::class)],
            'category_ids' => ['required', 'array', 'min:1'],
            'category_ids.*' => ['required', 'integer', 'exists:categories,id'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'address' => ['nullable', 'string', 'max:500'],
            'media' => ['nullable', 'array', 'max:10'],
            'media.*' => ['file', 'mimes:jpg,jpeg,png,mp4,mp3,pdf', 'max:102400'], // 100MB max
        ]);

        $tenant = $user->tenant;

        try {
            DB::beginTransaction();

            // Create the issue
            $issue = Issue::create([
                'tenant_id' => $tenant->id,
                'title' => $validated['title'],
                'description' => $validated['description'],
                'priority' => $validated['priority'] ?? IssuePriority::MEDIUM,
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
                    $mimeType = $file->getMimeType();

                    // Determine type from MIME
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

            // Timeline entry is automatically created by IssueObserver

            DB::commit();

            // Send notifications after successful creation
            try {
                // Notify admins about new issue
                $adminUsers = User::admins()->get();
                $this->fcmNotification->toUsers(
                    $adminUsers,
                    NotificationType::ISSUE_CREATED,
                    [
                        'title' => $issue->title,
                        'issue_id' => (string) $issue->id,
                    ]
                );

                // Also create database notification for admin panel
                foreach ($adminUsers as $admin) {
                    $admin->notify(new IssueNotification($issue, NotificationType::ISSUE_CREATED));
                }
            } catch (\Exception $e) {
                // Log error but don't fail the request
                Log::error('Failed to send issue created notification: '.$e->getMessage());
            }

            // Reload with relationships
            $issue->load(['categories', 'media', 'timeline.performedByUser']);

            return $this->created(
                $this->transformIssue($issue),
                __('api.issues.created_success')
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.issues.create_failed'),
                500,
                ['exception' => config('app.debug') ? $e->getMessage() : null]
            );
        }
    }

    /**
     * Get issue details (only if owner).
     */
    public function show(int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isTenant()) {
            return $this->forbidden(__('api.tenant_only'));
        }

        $tenant = $user->tenant;

        $issue = Issue::with([
            'categories',
            'media',
            'assignments' => function ($query) {
                $query->with([
                    'serviceProvider.user',
                    'serviceProvider.categories',
                    'category',
                    'timeSlot', // Legacy single slot
                    // Note: timeSlots() is a method, not a relationship - loaded on access
                    'workType', // NEW: Work type
                    'proofs',
                    'consumables.consumable',
                ]);
            },
            'timeline.performedByUser',
        ])
            ->forTenant($tenant->id)
            ->find($id);

        if (! $issue) {
            return $this->notFound(__('api.issues.not_found'));
        }

        return $this->success(
            $this->transformIssueDetailed($issue),
            __('api.issues.show_success')
        );
    }

    /**
     * Request issue cancellation.
     */
    public function cancel(Request $request, int $id): JsonResponse
    {
        $user = Auth::user();

        if (! $user->isTenant()) {
            return $this->forbidden(__('api.tenant_only'));
        }

        $tenant = $user->tenant;

        $issue = Issue::forTenant($tenant->id)->find($id);

        if (! $issue) {
            return $this->notFound(__('api.issues.not_found'));
        }

        if (! $issue->canBeCancelled()) {
            return $this->error(
                __('api.issues.cannot_cancel'),
                400
            );
        }

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        try {
            DB::beginTransaction();

            $issue->update([
                'status' => IssueStatus::CANCELLED,
                'cancelled_reason' => $validated['reason'] ?? null,
                'cancelled_by' => $user->id,
                'cancelled_at' => now(),
            ]);

            // Create timeline entry
            IssueTimeline::create([
                'issue_id' => $issue->id,
                'action' => TimelineAction::CANCELLED,
                'performed_by' => $user->id,
                'notes' => $validated['reason'] ?? null,
                'created_at' => now(),
            ]);

            DB::commit();

            $issue->refresh();
            $issue->load(['categories', 'media', 'timeline.performedByUser']);

            return $this->success(
                $this->transformIssue($issue),
                __('api.issues.cancelled_success')
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return $this->error(
                __('api.issues.cancel_failed'),
                500
            );
        }
    }

    /**
     * Transform issue for list view.
     */
    private function transformIssue(Issue $issue): array
    {
        return [
            'id' => $issue->id,
            'title' => $issue->title,
            'description' => $issue->description,
            'status' => [
                'value' => $issue->status->value,
                'label' => $issue->status->label(),
                'color' => $issue->status->color(),
            ],
            'priority' => [
                'value' => $issue->priority->value,
                'label' => $issue->priority->label(),
            ],
            'categories' => $issue->categories->map(fn ($cat) => [
                'id' => $cat->id,
                'name' => $cat->name,
                'icon' => $cat->icon,
            ]),
            'location' => $issue->hasLocation() ? [
                'latitude' => (float) $issue->latitude,
                'longitude' => (float) $issue->longitude,
                'address' => $issue->address,
                'directions_url' => $issue->getDirectionsUrl(),
            ] : null,
            'media' => $issue->media->map(fn ($m) => [
                'id' => $m->id,
                'type' => $m->type->value,
                'url' => $m->url,
            ]),
            'current_assignment' => $issue->getCurrentAssignment() ? [
                'id' => $issue->getCurrentAssignment()->id,
                'service_provider' => [
                    'id' => $issue->getCurrentAssignment()->serviceProvider->id,
                    'name' => $issue->getCurrentAssignment()->serviceProvider->name,
                ],
                'scheduled_date' => $issue->getCurrentAssignment()->scheduled_date?->format('Y-m-d'),
                'status' => $issue->getCurrentAssignment()->status->value,
            ] : null,
            'created_at' => $issue->created_at->format('Y-m-d\TH:i:s\Z'),
            'updated_at' => $issue->updated_at->format('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * Transform issue for detailed view.
     */
    private function transformIssueDetailed(Issue $issue): array
    {
        $base = $this->transformIssue($issue);

        $base['assignments'] = $issue->assignments->map(fn ($assignment) => [
            'id' => $assignment->id,
            'status' => [
                'value' => $assignment->status->value,
                'label' => $assignment->status->label(),
                'color' => $assignment->status->color(),
            ],
            'service_provider' => [
                'id' => $assignment->serviceProvider->id,
                'name' => $assignment->serviceProvider->name,
                'phone' => $assignment->serviceProvider->phone,
                'categories' => $assignment->serviceProvider->categories->map(fn ($cat) => [
                    'id' => $cat->id,
                    'name' => $cat->name,
                ]),
            ],
            'category' => $assignment->category ? [
                'id' => $assignment->category->id,
                'name' => $assignment->category->name,
            ] : null,
            'time_slot' => $assignment->timeSlot ? [
                'id' => $assignment->timeSlot->id,
                'start_time' => $assignment->timeSlot->start_time?->format('H:i'),
                'end_time' => $assignment->timeSlot->end_time?->format('H:i'),
            ] : null,
            'scheduled_date' => $assignment->scheduled_date?->format('Y-m-d'),
            'started_at' => $assignment->started_at?->format('Y-m-d\TH:i:s\Z'),
            'finished_at' => $assignment->finished_at?->format('Y-m-d\TH:i:s\Z'),
            'completed_at' => $assignment->completed_at?->format('Y-m-d\TH:i:s\Z'),
            'notes' => $assignment->notes,
            'proofs' => $assignment->proofs->map(fn ($proof) => [
                'id' => $proof->id,
                'type' => $proof->type->value,
                'stage' => $proof->stage->value,
                'url' => $proof->url,
            ]),
            'consumables' => $assignment->consumables->map(fn ($c) => [
                'id' => $c->id,
                'name' => $c->name,
                'quantity' => $c->quantity,
                'is_custom' => $c->is_custom,
            ]),
            'duration_minutes' => $assignment->getDurationInMinutes(),
        ]);

        $base['timeline'] = $issue->timeline->map(fn ($entry) => [
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

        $base['can_be_cancelled'] = $issue->canBeCancelled();

        if ($issue->cancelled_at) {
            $base['cancellation'] = [
                'reason' => $issue->cancelled_reason,
                'cancelled_by' => $issue->cancelledByUser ? [
                    'id' => $issue->cancelledByUser->id,
                    'name' => $issue->cancelledByUser->name,
                ] : null,
                'cancelled_at' => $issue->cancelled_at->format('Y-m-d\TH:i:s\Z'),
            ];
        }

        return $base;
    }
}
