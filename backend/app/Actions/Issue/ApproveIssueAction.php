<?php

declare(strict_types=1);

namespace App\Actions\Issue;

use App\Actions\Notification\SendFcmNotificationAction;
use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Enums\NotificationType;
use App\Enums\TimelineAction;
use App\Models\IssueAssignment;
use App\Models\IssueTimeline;
use App\Models\User;
use App\Notifications\IssueNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ApproveIssueAction
{
    public function __construct(
        private SendFcmNotificationAction $fcmNotification
    ) {}

    /**
     * Approve an issue assignment as completed.
     *
     * @param  int|null  $approvedBy  User ID performing approval, null for system auto-approval
     * @return bool Success status
     */
    public function execute(IssueAssignment $assignment, ?int $approvedBy = null): bool
    {
        if (! $assignment->canApprove()) {
            Log::warning('[APPROVE_ISSUE] Cannot approve assignment', [
                'assignment_id' => $assignment->id,
                'status' => $assignment->status->value,
            ]);

            return false;
        }

        try {
            DB::beginTransaction();

            $now = now();
            $issue = $assignment->issue;

            // Update assignment status
            $assignment->update([
                'status' => AssignmentStatus::COMPLETED,
                'completed_at' => $now,
            ]);

            // Recalculate issue status based on ALL assignments
            $newIssueStatus = $issue->calculateStatusFromAssignments();
            $issue->update(['status' => $newIssueStatus]);

            $issueFullyCompleted = $newIssueStatus === IssueStatus::COMPLETED;

            // Create timeline entry
            IssueTimeline::create([
                'issue_id' => $assignment->issue_id,
                'issue_assignment_id' => $assignment->id,
                'action' => TimelineAction::APPROVED,
                'performed_by' => $approvedBy, // NULL for system auto-approval
                'metadata' => [
                    'approved_at' => $now->format('Y-m-d\TH:i:s\Z'),
                    'auto_approved' => $approvedBy === null,
                    'issue_status' => $newIssueStatus->value,
                    'issue_fully_completed' => $issueFullyCompleted,
                ],
                'created_at' => $now,
            ]);

            DB::commit();

            // Send notifications based on completion status
            $this->sendNotifications($assignment, $issueFullyCompleted);

            Log::info('[APPROVE_ISSUE] Successfully approved', [
                'issue_id' => $assignment->issue_id,
                'assignment_id' => $assignment->id,
                'approved_by' => $approvedBy ?? 'system',
                'auto_approved' => $approvedBy === null,
                'issue_status' => $newIssueStatus->value,
                'issue_fully_completed' => $issueFullyCompleted,
            ]);

            return true;
        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('[APPROVE_ISSUE] Failed to approve', [
                'issue_id' => $assignment->issue_id,
                'assignment_id' => $assignment->id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return false;
        }
    }

    /**
     * Send notifications after approval.
     *
     * @param  bool  $issueFullyCompleted  Whether ALL assignments are now completed
     */
    private function sendNotifications(IssueAssignment $assignment, bool $issueFullyCompleted): void
    {
        $assignment->load(['issue', 'serviceProvider.user']);
        $issue = $assignment->issue;

        // Always notify the service provider whose assignment was approved
        $spUser = $assignment->serviceProvider?->user;
        if ($spUser) {
            try {
                $notificationType = $issueFullyCompleted
                    ? NotificationType::ISSUE_COMPLETED
                    : NotificationType::ASSIGNMENT_APPROVED;

                $this->fcmNotification->toUser(
                    $spUser,
                    $notificationType,
                    ['title' => $issue->title, 'issue_id' => (string) $issue->id]
                );
            } catch (\Exception $e) {
                Log::error('[APPROVE_ISSUE] FCM notification failed for SP', [
                    'user_id' => $spUser->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // Notify tenant
        $issue->load('tenant.user');
        $tenantUser = $issue->tenant?->user;
        if ($tenantUser) {
            try {
                if ($issueFullyCompleted) {
                    // Issue fully completed - send completion notification
                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::ISSUE_COMPLETED,
                        ['title' => $issue->title, 'issue_id' => (string) $issue->id]
                    );
                } else {
                    // Partial progress - send progress notification
                    $completedCount = $issue->getCompletedAssignmentCount();
                    $totalCount = $issue->getTotalAssignmentCount();

                    $this->fcmNotification->toUser(
                        $tenantUser,
                        NotificationType::PARTIAL_PROGRESS,
                        [
                            'title' => $issue->title,
                            'issue_id' => (string) $issue->id,
                            'completed' => (string) $completedCount,
                            'total' => (string) $totalCount,
                        ]
                    );
                }
            } catch (\Exception $e) {
                Log::error('[APPROVE_ISSUE] FCM notification failed for tenant', [
                    'user_id' => $tenantUser->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // Database notifications for admins - only when issue is fully completed
        if ($issueFullyCompleted) {
            try {
                Log::info('[NOTIFICATION] Starting ISSUE_COMPLETED database notifications', [
                    'issue_id' => $issue->id,
                    'issue_title' => $issue->title,
                ]);

                $adminUsers = User::admins()->get();
                foreach ($adminUsers as $admin) {
                    try {
                        $admin->notify(new IssueNotification($issue, NotificationType::ISSUE_COMPLETED));
                        Log::info('[NOTIFICATION] Successfully sent ISSUE_COMPLETED notification', [
                            'admin_id' => $admin->id,
                        ]);
                    } catch (\Exception $e) {
                        Log::error('[NOTIFICATION] Failed to send notification to admin', [
                            'admin_id' => $admin->id,
                            'error' => $e->getMessage(),
                        ]);
                    }
                }
            } catch (\Exception $e) {
                Log::error('[NOTIFICATION] Failed to send admin notifications', [
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }
}
