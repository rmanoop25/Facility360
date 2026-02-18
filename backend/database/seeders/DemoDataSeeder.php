<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\MediaType;
use App\Enums\ProofStage;
use App\Enums\ProofType;
use App\Enums\TimelineAction;
use App\Models\Category;
use App\Models\Consumable;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\IssueAssignmentConsumable;
use App\Models\IssueMedia;
use App\Models\IssueTimeline;
use App\Models\Proof;
use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use App\Models\User;
use App\Models\WorkType;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class DemoDataSeeder extends Seeder
{
    private ?User $adminUser = null;

    public function run(): void
    {
        $this->adminUser = User::where('email', 'admin@maintenance.local')->first();

        if (! $this->adminUser) {
            $this->command->warn('Admin user not found. Run AdminUserSeeder first.');

            return;
        }

        // Copy sample files to storage
        $this->copySampleFilesToStorage();

        // Assign profile photos to existing users
        $this->assignProfilePhotosToUsers();

        $this->createIssueMedia();
        $this->createAssignmentsAndRelatedData();

        // Validate data consistency
        $this->validateDataConsistency();

        $this->command->info('Demo data seeding completed!');
    }

    private function copySampleFilesToStorage(): void
    {
        $sampleDataPath = base_path('../SampleDatas');
        $storagePath = storage_path('app/public');

        // Create directories if they don't exist
        if (! file_exists("{$storagePath}/issues")) {
            mkdir("{$storagePath}/issues", 0755, true);
        }
        if (! file_exists("{$storagePath}/proofs")) {
            mkdir("{$storagePath}/proofs", 0755, true);
        }
        if (! file_exists("{$storagePath}/profiles")) {
            mkdir("{$storagePath}/profiles", 0755, true);
        }
        if (! file_exists("{$storagePath}/profiles/tenants")) {
            mkdir("{$storagePath}/profiles/tenants", 0755, true);
        }
        if (! file_exists("{$storagePath}/profiles/service-providers")) {
            mkdir("{$storagePath}/profiles/service-providers", 0755, true);
        }

        // Copy issue media files
        $issueFiles = [
            '3785602.jpg',
            '40796.jpg',
            'Work_7.jpg',
            'Work_from_home.jpg',
            '1112999_Brainstorm_Typing_3840x2160.mp4',
            'capaholiczsfx-water-splashing-403197.mp3',
            'basic-text.pdf',
        ];

        foreach ($issueFiles as $file) {
            $source = "{$sampleDataPath}/{$file}";
            $destination = "{$storagePath}/issues/{$file}";
            if (file_exists($source) && ! file_exists($destination)) {
                copy($source, $destination);
            }
        }

        // Copy proof files (use same files for proofs)
        foreach ($issueFiles as $file) {
            $source = "{$sampleDataPath}/{$file}";
            $destination = "{$storagePath}/proofs/{$file}";
            if (file_exists($source) && ! file_exists($destination)) {
                copy($source, $destination);
            }
        }

        // Copy and rename tenant profile photos
        $tenantProfileSources = [
            "{$sampleDataPath}/Tenant-ProfileSameples/close-up-portrait-young-bearded-man-white-shirt-jacket-posing-camera-with-broad-smile-isolated-gray.jpg" => 'tenant-1.jpg',
            "{$sampleDataPath}/Tenant-ProfileSameples/young-bearded-man-with-striped-shirt.jpg" => 'tenant-2.jpg',
            "{$sampleDataPath}/Tenant-ProfileSameples/young-beautiful-woman-pink-warm-sweater-natural-look-smiling-portrait-isolated-long-hair.jpg" => 'tenant-3.jpg',
        ];

        foreach ($tenantProfileSources as $source => $destName) {
            $destination = "{$storagePath}/profiles/tenants/{$destName}";
            if (file_exists($source) && ! file_exists($destination)) {
                copy($source, $destination);
            }
        }

        // Copy and rename service provider profile photos
        $spProfileSources = [
            "{$sampleDataPath}/SP-Profilesamples/young-bearded-handsome-engineer-wearing-security-helmet-vest-standing-with-crossed-arms-with-smile-face-isolated-pink-wall.jpg" => 'sp-1.jpg',
            "{$sampleDataPath}/SP-Profilesamples/Screenshot 2026-02-17 023908.png" => 'sp-2.png',
            "{$sampleDataPath}/SP-Profilesamples/Screenshot 2026-02-17 023924.png" => 'sp-3.png',
            "{$sampleDataPath}/SP-Profilesamples/Screenshot 2026-02-17 023948.png" => 'sp-4.png',
        ];

        foreach ($spProfileSources as $source => $destName) {
            $destination = "{$storagePath}/profiles/service-providers/{$destName}";
            if (file_exists($source) && ! file_exists($destination)) {
                copy($source, $destination);
            }
        }

        $this->command->info('Sample files copied to storage (including tenant and SP profile photos).');
    }

    private function assignProfilePhotosToUsers(): void
    {
        // Assign profile photos to tenants
        $tenantPhotos = [
            'profiles/tenants/tenant-1.jpg',
            'profiles/tenants/tenant-2.jpg',
            'profiles/tenants/tenant-3.jpg',
        ];

        $tenants = User::whereHas('tenant')->get();
        foreach ($tenants as $index => $tenant) {
            $photoIndex = $index % count($tenantPhotos);
            $tenant->update(['profile_photo' => $tenantPhotos[$photoIndex]]);
        }

        // Assign profile photos to service providers
        $spPhotos = [
            'profiles/service-providers/sp-1.jpg',
            'profiles/service-providers/sp-2.png',
            'profiles/service-providers/sp-3.png',
            'profiles/service-providers/sp-4.png',
        ];

        $serviceProviders = User::whereHas('serviceProvider')->get();
        foreach ($serviceProviders as $index => $sp) {
            $photoIndex = $index % count($spPhotos);
            $sp->update(['profile_photo' => $spPhotos[$photoIndex]]);
        }

        $this->command->info(sprintf(
            'Profile photos assigned: %d tenants, %d service providers',
            $tenants->count(),
            $serviceProviders->count()
        ));
    }

    private function createIssueMedia(): void
    {
        $issues = Issue::all();

        // Available real media files (all types)
        $availablePhotos = [
            'issues/3785602.jpg',
            'issues/40796.jpg',
            'issues/Work_7.jpg',
            'issues/Work_from_home.jpg',
        ];

        $availableVideos = [
            'issues/1112999_Brainstorm_Typing_3840x2160.mp4',
        ];

        $availableAudio = [
            'issues/capaholiczsfx-water-splashing-403197.mp3',
        ];

        $availablePdfs = [
            'issues/basic-text.pdf',
        ];

        $mediaCount = 0;
        foreach ($issues as $issue) {
            // Skip if media already added by seeder
            if ($issue->media()->exists()) {
                $mediaCount += $issue->media()->count();

                continue;
            }

            // Add 1-3 media items for each issue (to showcase variety)
            $numMedia = rand(1, 3);

            for ($i = 1; $i <= $numMedia; $i++) {
                // Distribute types: 50% photo, 25% video, 15% pdf, 10% audio
                $rand = rand(1, 100);
                if ($rand <= 50) {
                    $type = MediaType::PHOTO;
                    $filePath = $availablePhotos[array_rand($availablePhotos)];
                } elseif ($rand <= 75) {
                    $type = MediaType::VIDEO;
                    $filePath = $availableVideos[array_rand($availableVideos)];
                } elseif ($rand <= 90) {
                    $type = MediaType::PDF;
                    $filePath = $availablePdfs[array_rand($availablePdfs)];
                } else {
                    $type = MediaType::AUDIO;
                    $filePath = $availableAudio[array_rand($availableAudio)];
                }

                IssueMedia::firstOrCreate(
                    [
                        'issue_id' => $issue->id,
                        'file_path' => $filePath,
                    ],
                    [
                        'issue_id' => $issue->id,
                        'type' => $type,
                        'file_path' => $filePath,
                    ]
                );
                $mediaCount++;
            }
        }

        $this->command->info("Issue media created: {$mediaCount} (photos, videos, PDFs, audio)");
    }

    private function createAssignmentsAndRelatedData(): void
    {
        // Get issues that need assignments (not pending and not cancelled)
        $issuesNeedingAssignments = Issue::whereNotIn('status', [
            IssueStatus::PENDING,
            IssueStatus::CANCELLED,
        ])->with('categories')->get();

        $assignmentCount = 0;
        $timelineCount = 0;
        $proofCount = 0;
        $consumableCount = 0;

        // Track which issues we've processed
        $processedIssueIds = [];

        foreach ($issuesNeedingAssignments as $index => $issue) {
            // For some issues, create multi-slot/multi-day assignments
            $forceMultiSlot = in_array($index, [0, 3, 6]); // First, 4th, and 7th issue

            $result = $this->createAssignmentForIssue($issue, $forceMultiSlot);

            if ($result) {
                $assignmentCount++;
                $timelineCount += $result['timeline_count'];
                $proofCount += $result['proof_count'];
                $consumableCount += $result['consumable_count'];
                $processedIssueIds[] = $issue->id;
            }
        }

        // Also create timeline entries for pending issues (created event)
        $pendingIssues = Issue::where('status', IssueStatus::PENDING)->get();
        foreach ($pendingIssues as $issue) {
            $this->createTimelineEntry($issue, null, TimelineAction::CREATED, $issue->tenant->user);
            $timelineCount++;
        }

        // Create timeline entries for cancelled issues
        $cancelledIssues = Issue::where('status', IssueStatus::CANCELLED)->get();
        foreach ($cancelledIssues as $issue) {
            $this->createTimelineEntry($issue, null, TimelineAction::CREATED, $issue->tenant->user);
            $this->createTimelineEntry(
                $issue,
                null,
                TimelineAction::CANCELLED,
                $this->adminUser,
                $issue->cancelled_reason ?? 'Issue cancelled'
            );
            $timelineCount += 2;
        }

        $this->command->info("Issue assignments created: {$assignmentCount}");
        $this->command->info("Timeline entries created: {$timelineCount}");
        $this->command->info("Proofs created: {$proofCount}");
        $this->command->info("Consumables used: {$consumableCount}");
    }

    private function createAssignmentForIssue(Issue $issue, bool $forceMultiSlot = false): ?array
    {
        // Find a suitable service provider based on issue categories
        $categoryIds = $issue->categories->pluck('id')->toArray();

        if (empty($categoryIds)) {
            $this->command->warn("Issue #{$issue->id} has no categories. Skipping assignment.");

            return null;
        }

        // IMPROVED: Try to find matching ServiceProvider, with fallback
        $serviceProvider = $this->findOrCreateServiceProvider($categoryIds);

        if (! $serviceProvider) {
            $this->command->error("Could not find or create ServiceProvider for Issue #{$issue->id} (categories: ".implode(',', $categoryIds).'). Skipping.');

            return null;
        }

        // Select a category that both the issue and service provider share
        $sharedCategoryId = $serviceProvider->categories()
            ->whereIn('categories.id', $categoryIds)
            ->first()?->id ?? $categoryIds[0];

        // Get work types for the shared category
        $workTypes = WorkType::whereHas('categories', function ($query) use ($sharedCategoryId) {
            $query->where('categories.id', $sharedCategoryId);
        })->where('is_active', true)->get();

        // Select a single work type randomly
        $selectedWorkType = $workTypes->isEmpty()
            ? null
            : $workTypes->random();

        // Get duration from work type or use a default
        if ($forceMultiSlot) {
            // Force large durations for multi-slot/multi-day examples
            $allocatedDuration = [480, 720, 960, 1200, 1440, 2220][array_rand([480, 720, 960, 1200, 1440, 2220])];
            // Override work type to null for custom duration
            $selectedWorkType = null;
        } else {
            $allocatedDuration = $selectedWorkType?->duration_minutes
                ?? [60, 90, 120, 180, 240][array_rand([60, 90, 120, 180, 240])];
        }

        $now = now();

        // CRITICAL FIX: Get days when service provider actually has time slots
        $providerWorkingDays = TimeSlot::where('service_provider_id', $serviceProvider->id)
            ->where('is_active', true)
            ->distinct()
            ->pluck('day_of_week')
            ->toArray();

        if (empty($providerWorkingDays)) {
            $this->command->warn("ServiceProvider #{$serviceProvider->id} has no active time slots. Skipping assignment for Issue #{$issue->id}.");

            return null;
        }

        // Find a date within next 14 days that falls on one of the provider's working days
        $scheduledDate = $now->copy()->addDays(1);
        $maxAttempts = 14;
        $attempts = 0;

        while (! in_array($scheduledDate->dayOfWeek, $providerWorkingDays) && $attempts < $maxAttempts) {
            $scheduledDate->addDay();
            $attempts++;
        }

        if ($attempts >= $maxAttempts) {
            $this->command->warn("Could not find suitable working day for ServiceProvider #{$serviceProvider->id}. Skipping assignment for Issue #{$issue->id}.");

            return null;
        }

        // For multi-day assignments, we need to collect slots across multiple days
        $selectedSlots = [];
        $accumulatedMinutes = 0;
        $maxDays = $forceMultiSlot ? 10 : 1; // Allow up to 10 days for multi-slot
        $daysProcessed = 0;
        $currentDate = $scheduledDate->copy();

        while ($accumulatedMinutes < $allocatedDuration && $daysProcessed < $maxDays) {
            $dayOfWeek = $currentDate->dayOfWeek;

            // Only process if this is a working day for the provider
            if (in_array($dayOfWeek, $providerWorkingDays)) {
                // Get time slots for this day
                $daySlots = TimeSlot::where('service_provider_id', $serviceProvider->id)
                    ->where('day_of_week', $dayOfWeek)
                    ->where('is_active', true)
                    ->orderBy('start_time')
                    ->get();

                if ($daySlots->isNotEmpty()) {
                    foreach ($daySlots as $slot) {
                        $slotStart = Carbon::parse($slot->start_time);
                        $slotEnd = Carbon::parse($slot->end_time);
                        $slotDuration = $slotStart->diffInMinutes($slotEnd);

                        $selectedSlots[] = $slot->id;
                        $accumulatedMinutes += $slotDuration;

                        // Stop if we've accumulated enough
                        if ($accumulatedMinutes >= $allocatedDuration) {
                            break 2;
                        }
                    }
                }
            }

            $currentDate->addDay();
            $daysProcessed++;
        }

        if (empty($selectedSlots)) {
            $this->command->warn("No time slots accumulated for Issue #{$issue->id} (ServiceProvider #{$serviceProvider->id}, allocated: {$allocatedDuration} min). Skipping assignment.");

            return null; // No slots available at all
        }

        // Calculate time ranges
        // Get all selected slot models
        $selectedSlotModels = TimeSlot::whereIn('id', $selectedSlots)->orderBy('day_of_week')->orderBy('start_time')->get();
        $timeRangeData = $this->calculateTimeRanges($selectedSlotModels, $selectedSlots, $allocatedDuration);

        // Determine assignment status based on issue status
        $assignmentData = $this->getAssignmentDataForIssueStatus($issue->status, $now);

        // Create the assignment with new capacity-based fields
        $assignment = IssueAssignment::firstOrCreate(
            [
                'issue_id' => $issue->id,
                'service_provider_id' => $serviceProvider->id,
            ],
            [
                'issue_id' => $issue->id,
                'service_provider_id' => $serviceProvider->id,
                'category_id' => $sharedCategoryId,
                'work_type_id' => $selectedWorkType?->id, // NEW: Work type
                'time_slot_ids' => $selectedSlots, // NEW: Array (Laravel will auto-cast to JSON)
                'scheduled_date' => $scheduledDate->format('Y-m-d'),
                'allocated_duration_minutes' => $allocatedDuration, // NEW: Duration
                'assigned_start_time' => $timeRangeData['start_time'], // NEW: Time range
                'assigned_end_time' => $timeRangeData['end_time'], // NEW: Time range
                'status' => $assignmentData['status'],
                'proof_required' => $issue->proof_required,
                'started_at' => $assignmentData['started_at'],
                'held_at' => $assignmentData['held_at'],
                'resumed_at' => $assignmentData['resumed_at'],
                'finished_at' => $assignmentData['finished_at'],
                'completed_at' => $assignmentData['completed_at'],
                'notes' => $assignmentData['notes'],
            ]
        );

        // Create timeline entries
        $timelineCount = $this->createTimelineForAssignment($issue, $assignment, $serviceProvider);

        // Create proofs if applicable
        $proofCount = 0;
        if (in_array($issue->status, [IssueStatus::IN_PROGRESS, IssueStatus::ON_HOLD, IssueStatus::FINISHED, IssueStatus::COMPLETED])) {
            $proofCount = $this->createProofsForAssignment($assignment);
        }

        // Create consumable usage if work has started
        $consumableCount = 0;
        if (in_array($issue->status, [IssueStatus::IN_PROGRESS, IssueStatus::ON_HOLD, IssueStatus::FINISHED, IssueStatus::COMPLETED])) {
            $consumableCount = $this->createConsumablesForAssignment($assignment, $sharedCategoryId);
        }

        return [
            'timeline_count' => $timelineCount,
            'proof_count' => $proofCount,
            'consumable_count' => $consumableCount,
        ];
    }

    /**
     * Calculate time ranges for the assignment.
     * For single or consecutive same-day slots, set actual time ranges.
     * For multi-slot with gaps or multi-day, set NULL to avoid gap overcounting.
     */
    private function calculateTimeRanges($selectedSlotModels, array $selectedSlotIds, int $allocatedDuration): array
    {
        if ($selectedSlotModels->count() === 1) {
            // Single slot - use actual time range from slot start
            $slot = $selectedSlotModels->first();
            $slotStart = Carbon::parse($slot->start_time);
            $startTime = $slotStart->format('H:i:s');
            $endTime = $slotStart->copy()->addMinutes($allocatedDuration)->format('H:i:s');

            return [
                'start_time' => $startTime,
                'end_time' => $endTime,
            ];
        }

        if ($selectedSlotModels->count() > 1) {
            // Check if slots are all on same day
            $uniqueDays = $selectedSlotModels->pluck('day_of_week')->unique();

            if ($uniqueDays->count() > 1) {
                // Multi-day assignment - set NULL
                return [
                    'start_time' => null,
                    'end_time' => null,
                ];
            }

            // Same day - check if consecutive (no gaps)
            $hasGaps = false;
            $previousEnd = null;

            foreach ($selectedSlotModels as $slot) {
                $slotStart = Carbon::parse($slot->start_time);

                if ($previousEnd !== null) {
                    // If there's a gap between previous end and current start
                    if ($previousEnd->lt($slotStart)) {
                        $hasGaps = true;
                        break;
                    }
                }

                $previousEnd = Carbon::parse($slot->end_time);
            }

            if ($hasGaps) {
                // Same day but with gaps - set NULL to avoid overcounting
                return [
                    'start_time' => null,
                    'end_time' => null,
                ];
            }

            // Consecutive same-day slots - use combined range
            $firstSlot = $selectedSlotModels->first();
            $startTime = Carbon::parse($firstSlot->start_time)->format('H:i:s');
            $endTime = Carbon::parse($firstSlot->start_time)
                ->addMinutes($allocatedDuration)
                ->format('H:i:s');

            return [
                'start_time' => $startTime,
                'end_time' => $endTime,
            ];
        }

        return [
            'start_time' => null,
            'end_time' => null,
        ];
    }

    private function getAssignmentDataForIssueStatus(IssueStatus $issueStatus, $now): array
    {
        return match ($issueStatus) {
            IssueStatus::ASSIGNED => [
                'status' => AssignmentStatus::ASSIGNED,
                'started_at' => null,
                'held_at' => null,
                'resumed_at' => null,
                'finished_at' => null,
                'completed_at' => null,
                'notes' => 'Assignment scheduled, waiting for service provider to start work.',
            ],
            IssueStatus::IN_PROGRESS => [
                'status' => AssignmentStatus::IN_PROGRESS,
                'started_at' => $now->copy()->subHours(2)->format('Y-m-d H:i:s'),
                'held_at' => null,
                'resumed_at' => null,
                'finished_at' => null,
                'completed_at' => null,
                'notes' => 'Work is currently in progress.',
            ],
            IssueStatus::ON_HOLD => [
                'status' => AssignmentStatus::ON_HOLD,
                'started_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s'),
                'held_at' => $now->copy()->subHours(4)->format('Y-m-d H:i:s'),
                'resumed_at' => null,
                'finished_at' => null,
                'completed_at' => null,
                'notes' => 'Work on hold - waiting for parts/materials.',
            ],
            IssueStatus::FINISHED => [
                'status' => AssignmentStatus::FINISHED,
                'started_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s'),
                'held_at' => null,
                'resumed_at' => null,
                'finished_at' => $now->copy()->subHours(3)->format('Y-m-d H:i:s'),
                'completed_at' => null,
                'notes' => 'Work finished, waiting for manager approval.',
            ],
            IssueStatus::COMPLETED => [
                'status' => AssignmentStatus::COMPLETED,
                'started_at' => $now->copy()->subDays(10)->format('Y-m-d H:i:s'),
                'held_at' => null,
                'resumed_at' => null,
                'finished_at' => $now->copy()->subDays(8)->format('Y-m-d H:i:s'),
                'completed_at' => $now->copy()->subDays(7)->format('Y-m-d H:i:s'),
                'notes' => 'Work completed and approved.',
            ],
            default => [
                'status' => AssignmentStatus::ASSIGNED,
                'started_at' => null,
                'held_at' => null,
                'resumed_at' => null,
                'finished_at' => null,
                'completed_at' => null,
                'notes' => 'Assignment created.',
            ],
        };
    }

    private function createTimelineForAssignment(Issue $issue, IssueAssignment $assignment, ServiceProvider $serviceProvider): int
    {
        $count = 0;
        $tenantUser = $issue->tenant->user;
        $spUser = $serviceProvider->user;

        // Always create 'created' entry
        $this->createTimelineEntry($issue, null, TimelineAction::CREATED, $tenantUser);
        $count++;

        // Create 'assigned' entry
        $this->createTimelineEntry($issue, $assignment, TimelineAction::ASSIGNED, $this->adminUser, "Assigned to {$spUser->name}");
        $count++;

        // Add more timeline entries based on status
        if (in_array($issue->status, [IssueStatus::IN_PROGRESS, IssueStatus::ON_HOLD, IssueStatus::FINISHED, IssueStatus::COMPLETED])) {
            $this->createTimelineEntry($issue, $assignment, TimelineAction::STARTED, $spUser);
            $count++;
        }

        if ($issue->status === IssueStatus::ON_HOLD) {
            $this->createTimelineEntry($issue, $assignment, TimelineAction::HELD, $spUser, 'Waiting for parts');
            $count++;
        }

        if (in_array($issue->status, [IssueStatus::FINISHED, IssueStatus::COMPLETED])) {
            $this->createTimelineEntry($issue, $assignment, TimelineAction::FINISHED, $spUser);
            $count++;
        }

        if ($issue->status === IssueStatus::COMPLETED) {
            $this->createTimelineEntry($issue, $assignment, TimelineAction::APPROVED, $this->adminUser, 'Work verified and approved');
            $count++;
        }

        return $count;
    }

    private function createTimelineEntry(
        Issue $issue,
        ?IssueAssignment $assignment,
        TimelineAction $action,
        ?User $performedBy,
        ?string $notes = null
    ): void {
        IssueTimeline::firstOrCreate(
            [
                'issue_id' => $issue->id,
                'issue_assignment_id' => $assignment?->id,
                'action' => $action,
            ],
            [
                'issue_id' => $issue->id,
                'issue_assignment_id' => $assignment?->id,
                'action' => $action,
                'performed_by' => $performedBy?->id,
                'notes' => $notes,
                'metadata' => json_encode(['seeded' => true]),
                'created_at' => now()->subMinutes(rand(10, 1000))->format('Y-m-d H:i:s'),
            ]
        );
    }

    private function createProofsForAssignment(IssueAssignment $assignment): int
    {
        $count = 0;

        // Available real proof files (all types)
        $availablePhotos = [
            'proofs/3785602.jpg',
            'proofs/40796.jpg',
            'proofs/Work_7.jpg',
            'proofs/Work_from_home.jpg',
        ];

        $availableVideos = [
            'proofs/1112999_Brainstorm_Typing_3840x2160.mp4',
        ];

        $availableAudio = [
            'proofs/capaholiczsfx-water-splashing-403197.mp3',
        ];

        $availablePdfs = [
            'proofs/basic-text.pdf',
        ];

        // Create during_work proofs
        if (in_array($assignment->status, [AssignmentStatus::IN_PROGRESS, AssignmentStatus::ON_HOLD, AssignmentStatus::FINISHED, AssignmentStatus::COMPLETED])) {
            $numProofs = rand(1, 2);
            for ($i = 1; $i <= $numProofs; $i++) {
                // During work: mostly photos (80%), some audio notes (20%)
                if (rand(1, 100) <= 80) {
                    $type = ProofType::PHOTO;
                    $filePath = $availablePhotos[array_rand($availablePhotos)];
                } else {
                    $type = ProofType::AUDIO;
                    $filePath = $availableAudio[array_rand($availableAudio)];
                }

                Proof::firstOrCreate(
                    [
                        'issue_assignment_id' => $assignment->id,
                        'file_path' => $filePath,
                        'stage' => ProofStage::DURING_WORK,
                    ],
                    [
                        'issue_assignment_id' => $assignment->id,
                        'type' => $type,
                        'file_path' => $filePath,
                        'stage' => ProofStage::DURING_WORK,
                    ]
                );
                $count++;
            }
        }

        // Create completion proofs
        if (in_array($assignment->status, [AssignmentStatus::FINISHED, AssignmentStatus::COMPLETED])) {
            $numProofs = rand(2, 4);
            for ($i = 1; $i <= $numProofs; $i++) {
                // Completion: diverse types - 40% photo, 30% video, 20% pdf (warranty/receipt), 10% audio
                $rand = rand(1, 100);
                if ($rand <= 40) {
                    $type = ProofType::PHOTO;
                    $filePath = $availablePhotos[array_rand($availablePhotos)];
                } elseif ($rand <= 70) {
                    $type = ProofType::VIDEO;
                    $filePath = $availableVideos[array_rand($availableVideos)];
                } elseif ($rand <= 90) {
                    $type = ProofType::PDF;
                    $filePath = $availablePdfs[array_rand($availablePdfs)];
                } else {
                    $type = ProofType::AUDIO;
                    $filePath = $availableAudio[array_rand($availableAudio)];
                }

                Proof::firstOrCreate(
                    [
                        'issue_assignment_id' => $assignment->id,
                        'file_path' => $filePath,
                        'stage' => ProofStage::COMPLETION,
                    ],
                    [
                        'issue_assignment_id' => $assignment->id,
                        'type' => $type,
                        'file_path' => $filePath,
                        'stage' => ProofStage::COMPLETION,
                    ]
                );
                $count++;
            }
        }

        return $count;
    }

    private function createConsumablesForAssignment(IssueAssignment $assignment, int $categoryId): int
    {
        $count = 0;

        // Get consumables for the category
        $consumables = Consumable::where('category_id', $categoryId)
            ->where('is_active', true)
            ->get();

        if ($consumables->isEmpty()) {
            // If no consumables for this category, get any active consumables
            $consumables = Consumable::where('is_active', true)->take(3)->get();
        }

        // Add 1-3 standard consumables
        $selectedConsumables = $consumables->random(min(rand(1, 3), $consumables->count()));

        foreach ($selectedConsumables as $consumable) {
            IssueAssignmentConsumable::firstOrCreate(
                [
                    'issue_assignment_id' => $assignment->id,
                    'consumable_id' => $consumable->id,
                ],
                [
                    'issue_assignment_id' => $assignment->id,
                    'consumable_id' => $consumable->id,
                    'custom_name' => null,
                    'quantity' => rand(1, 5),
                ]
            );
            $count++;
        }

        // Sometimes add a custom consumable (not from the standard list)
        if (rand(0, 2) === 0) {
            $customNames = [
                'Special adhesive',
                'Custom fitting',
                'Extra screws',
                'Replacement valve',
                'Gasket set',
                'Sealant tape',
                'Wire connectors',
                'Mounting brackets',
            ];

            IssueAssignmentConsumable::firstOrCreate(
                [
                    'issue_assignment_id' => $assignment->id,
                    'custom_name' => $customNames[array_rand($customNames)],
                ],
                [
                    'issue_assignment_id' => $assignment->id,
                    'consumable_id' => null,
                    'custom_name' => $customNames[array_rand($customNames)],
                    'quantity' => rand(1, 3),
                ]
            );
            $count++;
        }

        return $count;
    }

    /**
     * Find a matching ServiceProvider or create a fallback one if none exists
     */
    private function findOrCreateServiceProvider(array $categoryIds): ?ServiceProvider
    {
        // Try to find existing ServiceProvider with matching categories
        $serviceProvider = ServiceProvider::whereHas('categories', function ($query) use ($categoryIds) {
            $query->whereIn('categories.id', $categoryIds);
        })->where('is_available', true)
            ->whereHas('user', fn ($q) => $q->where('is_active', true))
            ->inRandomOrder()
            ->first();

        if ($serviceProvider) {
            return $serviceProvider;
        }

        // FALLBACK: Create a generic ServiceProvider for this category
        $this->command->warn('No ServiceProvider found for categories ['.implode(',', $categoryIds).']. Creating fallback...');

        $category = Category::find($categoryIds[0]);

        if (! $category) {
            return null;
        }

        // Create user for the service provider
        $user = User::firstOrCreate(
            ['email' => "sp_fallback_{$category->id}@maintenance.local"],
            [
                'name' => "Generic {$category->name_en} Provider",
                'email' => "sp_fallback_{$category->id}@maintenance.local",
                'password' => bcrypt('password'),
                'phone' => '+966500000'.str_pad((string) $category->id, 3, '0', STR_PAD_LEFT),
                'is_active' => true,
            ]
        );

        // Assign service_provider role
        $user->assignRole('service_provider');

        // Create ServiceProvider profile
        $serviceProvider = ServiceProvider::firstOrCreate(
            ['user_id' => $user->id],
            [
                'user_id' => $user->id,
                'company_name' => "{$category->name_en} Services Co.",
                'license_number' => 'LIC-FALLBACK-'.$category->id,
                'is_available' => true,
                'is_verified' => true,
            ]
        );

        // Attach category
        $serviceProvider->categories()->syncWithoutDetaching($categoryIds);

        // Create time slots for the service provider (required for assignment)
        $this->createTimeSlotsForServiceProvider($serviceProvider);

        $this->command->info("Created fallback ServiceProvider: {$user->name}");

        return $serviceProvider;
    }

    /**
     * Create basic time slots for a service provider
     */
    private function createTimeSlotsForServiceProvider(ServiceProvider $serviceProvider): void
    {
        // Create time slots for Sunday to Thursday (typical work week in Saudi Arabia)
        $workDays = [0, 1, 2, 3, 4]; // Sunday to Thursday

        foreach ($workDays as $day) {
            // Morning slot: 8 AM - 12 PM
            TimeSlot::firstOrCreate([
                'service_provider_id' => $serviceProvider->id,
                'day_of_week' => $day,
                'start_time' => '08:00:00',
            ], [
                'end_time' => '12:00:00',
                'is_active' => true,
            ]);

            // Afternoon slot: 2 PM - 6 PM
            TimeSlot::firstOrCreate([
                'service_provider_id' => $serviceProvider->id,
                'day_of_week' => $day,
                'start_time' => '14:00:00',
            ], [
                'end_time' => '18:00:00',
                'is_active' => true,
            ]);
        }
    }

    /**
     * Validate that seeded data is consistent
     */
    private function validateDataConsistency(): void
    {
        $this->command->info('Validating data consistency...');

        $errors = [];

        // Check 1: Issues with non-PENDING status should have assignments
        $issuesNeedingAssignments = Issue::whereNotIn('status', [
            IssueStatus::PENDING,
            IssueStatus::CANCELLED,
        ])->whereDoesntHave('assignments')->get();

        if ($issuesNeedingAssignments->count() > 0) {
            $errors[] = "{$issuesNeedingAssignments->count()} issues with status requiring assignment have NO assignments: "
                .$issuesNeedingAssignments->pluck('id')->implode(', ');
        }

        // Check 2: FINISHED/COMPLETED issues should have proofs
        $issuesNeedingProofs = Issue::whereIn('status', [
            IssueStatus::FINISHED,
            IssueStatus::COMPLETED,
        ])->whereHas('assignments', function ($query) {
            $query->whereDoesntHave('proofs');
        })->get();

        if ($issuesNeedingProofs->count() > 0) {
            $errors[] = "{$issuesNeedingProofs->count()} FINISHED/COMPLETED issues have NO proofs: "
                .$issuesNeedingProofs->pluck('id')->implode(', ');
        }

        // Check 3: All issues should have at least one timeline entry
        $issuesWithoutTimeline = Issue::whereDoesntHave('timeline')->get();

        if ($issuesWithoutTimeline->count() > 0) {
            $errors[] = "{$issuesWithoutTimeline->count()} issues have NO timeline entries: "
                .$issuesWithoutTimeline->pluck('id')->implode(', ');
        }

        // Check 4: Assignments should have matching time slots from their service provider
        $invalidAssignments = IssueAssignment::whereHas('serviceProvider', function ($query) {
            $query->whereDoesntHave('timeSlots');
        })->get();

        if ($invalidAssignments->count() > 0) {
            $errors[] = "{$invalidAssignments->count()} assignments have service providers with NO time slots: "
                .$invalidAssignments->pluck('id')->implode(', ');
        }

        if (empty($errors)) {
            $this->command->info('✓ Data consistency validation passed!');
        } else {
            $this->command->error('✗ Data consistency validation FAILED:');
            foreach ($errors as $error) {
                $this->command->error("  - {$error}");
            }
        }
    }
}
