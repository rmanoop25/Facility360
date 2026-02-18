<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\IssueStatus;
use App\Http\Controllers\Api\V1\ApiController;
use App\Http\Resources\CalendarEventResource;
use App\Http\Resources\PendingIssueEventResource;
use App\Models\Issue;
use App\Models\IssueAssignment;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminCalendarController extends ApiController
{
    /**
     * Get calendar events for the specified date range.
     *
     * Returns both:
     * - Assigned issues (with scheduled_date)
     * - Pending issues (shown on created_at date)
     */
    public function events(Request $request): JsonResponse
    {
        $request->validate([
            'start_date' => 'required|date',
            'end_date' => 'required|date|after_or_equal:start_date',
            'status' => 'nullable|string',
            'service_provider_id' => 'nullable|exists:service_providers,id',
            'category_id' => 'nullable|exists:categories,id',
        ]);

        $startDate = Carbon::parse($request->start_date)->startOfDay();
        $endDate = Carbon::parse($request->end_date)->endOfDay();

        // Fetch assignments with scheduled dates
        $assignments = $this->getAssignments(
            $startDate,
            $endDate,
            $request->status,
            $request->service_provider_id,
            $request->category_id
        );

        // Fetch pending issues (no assignment yet)
        $pendingIssues = $this->getPendingIssues(
            $startDate,
            $endDate,
            $request->category_id
        );

        return response()->json([
            'success' => true,
            'data' => [
                'assignments' => CalendarEventResource::collection($assignments),
                'pending_issues' => PendingIssueEventResource::collection($pendingIssues),
            ],
            'meta' => [
                'start_date' => $startDate->toDateString(),
                'end_date' => $endDate->toDateString(),
                'total_assignments' => $assignments->count(),
                'total_pending' => $pendingIssues->count(),
            ],
        ]);
    }

    /**
     * Get assignments within the date range.
     */
    private function getAssignments(
        Carbon $startDate,
        Carbon $endDate,
        ?string $status,
        ?int $serviceProviderId,
        ?int $categoryId
    ) {
        return IssueAssignment::with([
            'issue.tenant.user',
            'issue.categories',
            'serviceProvider.user',
            'timeSlot',
            'category',
        ])
            ->whereNotNull('scheduled_date')
            ->whereBetween('scheduled_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->when($status, fn ($query) => $query->where('status', $status))
            ->when($serviceProviderId, fn ($query) => $query->where('service_provider_id', $serviceProviderId))
            ->when($categoryId, fn ($query) => $query->where('category_id', $categoryId))
            ->orderBy('scheduled_date')
            ->get();
    }

    /**
     * Get unassigned issues within the date range (by created_at).
     * Includes all statuses (COMPLETED/CANCELLED shown to indicate freed time slots).
     */
    private function getPendingIssues(
        Carbon $startDate,
        Carbon $endDate,
        ?int $categoryId
    ) {
        return Issue::with(['tenant.user', 'categories'])
            ->whereDoesntHave('assignments', function ($query) {
                $query->whereNotNull('scheduled_date');
            })
            ->whereBetween('created_at', [$startDate, $endDate])
            ->when($categoryId, fn ($query) =>
                $query->whereHas('categories', fn ($q) => $q->where('categories.id', $categoryId))
            )
            ->orderBy('created_at')
            ->get();
    }
}
