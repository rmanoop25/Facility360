<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\IssueStatus;
use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Issue;
use App\Models\IssueTimeline;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminDashboardController extends ApiController
{
    /**
     * Get dashboard statistics.
     */
    public function stats(Request $request): JsonResponse
    {
        $dateFrom = $request->input('date_from')
            ? Carbon::parse($request->input('date_from'))->startOfDay()
            : Carbon::now()->subDays(30)->startOfDay();

        $dateTo = $request->input('date_to')
            ? Carbon::parse($request->input('date_to'))->endOfDay()
            : Carbon::now()->endOfDay();

        // Get issue counts by status
        $issuesByStatus = $this->getIssuesByStatus();

        // Get issues summary
        $issuesSummary = $this->getIssuesSummary($dateFrom, $dateTo);

        // Get recent activity
        $recentActivity = $this->getRecentActivity(15);

        // Get entity counts
        $entityCounts = $this->getEntityCounts();

        // Get issues created over time (for charts)
        $issuesOverTime = $this->getIssuesOverTime($dateFrom, $dateTo);

        // Get top categories
        $topCategories = $this->getTopCategories();

        // Get service provider performance
        $spPerformance = $this->getServiceProviderPerformance($dateFrom, $dateTo);

        return response()->json([
            'success' => true,
            'data' => [
                'issues_by_status' => $issuesByStatus,
                'issues_summary' => $issuesSummary,
                'entity_counts' => $entityCounts,
                'recent_activity' => $recentActivity,
                'issues_over_time' => $issuesOverTime,
                'top_categories' => $topCategories,
                'sp_performance' => $spPerformance,
                'date_range' => [
                    'from' => $dateFrom->toDateString(),
                    'to' => $dateTo->toDateString(),
                ],
            ],
        ]);
    }

    /**
     * Get issue counts grouped by status.
     */
    private function getIssuesByStatus(): array
    {
        $statusCounts = Issue::select('status', DB::raw('COUNT(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();

        $result = [];
        foreach (IssueStatus::cases() as $status) {
            $result[] = [
                'status' => $status->value,
                'label' => $status->label(),
                'color' => $status->color(),
                'icon' => $status->icon(),
                'count' => $statusCounts[$status->value] ?? 0,
            ];
        }

        return $result;
    }

    /**
     * Get issues summary for a date range.
     */
    private function getIssuesSummary(Carbon $dateFrom, Carbon $dateTo): array
    {
        $total = Issue::whereBetween('created_at', [$dateFrom, $dateTo])->count();
        $completed = Issue::whereBetween('updated_at', [$dateFrom, $dateTo])
            ->where('status', IssueStatus::COMPLETED)
            ->count();
        $pending = Issue::where('status', IssueStatus::PENDING)->count();
        $inProgress = Issue::whereIn('status', [
            IssueStatus::ASSIGNED,
            IssueStatus::IN_PROGRESS,
            IssueStatus::ON_HOLD,
        ])->count();
        $awaitingApproval = Issue::where('status', IssueStatus::FINISHED)->count();

        // Calculate average resolution time (in hours)
        $avgResolutionTime = Issue::where('status', IssueStatus::COMPLETED)
            ->whereBetween('updated_at', [$dateFrom, $dateTo])
            ->whereNotNull('created_at')
            ->selectRaw('AVG(TIMESTAMPDIFF(HOUR, created_at, updated_at)) as avg_hours')
            ->value('avg_hours');

        return [
            'total_created' => $total,
            'completed' => $completed,
            'pending' => $pending,
            'in_progress' => $inProgress,
            'awaiting_approval' => $awaitingApproval,
            'avg_resolution_hours' => round($avgResolutionTime ?? 0, 1),
            'completion_rate' => $total > 0 ? round(($completed / $total) * 100, 1) : 0,
        ];
    }

    /**
     * Get recent activity from timeline.
     */
    private function getRecentActivity(int $limit = 15): array
    {
        return IssueTimeline::with([
            'issue:id,title,status',
            'performedByUser:id,name',
        ])
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get()
            ->map(fn ($timeline) => [
                'id' => $timeline->id,
                'issue_id' => $timeline->issue_id,
                'issue_title' => $timeline->issue?->title,
                'action' => $timeline->action->value,
                'action_label' => $timeline->action->label(),
                'action_color' => $timeline->action->color(),
                'action_icon' => $timeline->action->icon(),
                'performed_by' => $timeline->performedByUser?->name ?? 'System',
                'notes' => $timeline->notes,
                'created_at' => $timeline->created_at?->format('Y-m-d\TH:i:s\Z'),
                'time_ago' => $timeline->created_at?->diffForHumans(),
            ])
            ->toArray();
    }

    /**
     * Get entity counts (tenants, SPs, etc.).
     */
    private function getEntityCounts(): array
    {
        return [
            'tenants' => [
                'total' => Tenant::count(),
                'active' => Tenant::whereHas('user', fn ($q) => $q->where('is_active', true))->count(),
            ],
            'service_providers' => [
                'total' => ServiceProvider::count(),
                'available' => ServiceProvider::where('is_available', true)
                    ->whereHas('user', fn ($q) => $q->where('is_active', true))
                    ->count(),
            ],
            'issues' => [
                'total' => Issue::count(),
                'open' => Issue::active()->count(),
            ],
        ];
    }

    /**
     * Get issues created over time for charts.
     */
    private function getIssuesOverTime(Carbon $dateFrom, Carbon $dateTo): array
    {
        $days = $dateFrom->diffInDays($dateTo);

        // Group by day if range is <= 60 days, otherwise by week or month
        if ($days <= 60) {
            $format = '%Y-%m-%d';
            $groupBy = 'day';
        } elseif ($days <= 365) {
            $format = '%Y-%U'; // Year-Week
            $groupBy = 'week';
        } else {
            $format = '%Y-%m';
            $groupBy = 'month';
        }

        $created = Issue::whereBetween('created_at', [$dateFrom, $dateTo])
            ->selectRaw("DATE_FORMAT(created_at, '{$format}') as period, COUNT(*) as count")
            ->groupBy('period')
            ->orderBy('period')
            ->pluck('count', 'period')
            ->toArray();

        $completed = Issue::where('status', IssueStatus::COMPLETED)
            ->whereBetween('updated_at', [$dateFrom, $dateTo])
            ->selectRaw("DATE_FORMAT(updated_at, '{$format}') as period, COUNT(*) as count")
            ->groupBy('period')
            ->orderBy('period')
            ->pluck('count', 'period')
            ->toArray();

        // Merge periods
        $periods = array_unique(array_merge(array_keys($created), array_keys($completed)));
        sort($periods);

        return [
            'group_by' => $groupBy,
            'data' => array_map(fn ($period) => [
                'period' => $period,
                'created' => $created[$period] ?? 0,
                'completed' => $completed[$period] ?? 0,
            ], $periods),
        ];
    }

    /**
     * Get top categories by issue count.
     */
    private function getTopCategories(int $limit = 5): array
    {
        return DB::table('issue_categories')
            ->join('categories', 'issue_categories.category_id', '=', 'categories.id')
            ->select(
                'categories.id',
                'categories.name_en',
                'categories.name_ar',
                'categories.icon',
                DB::raw('COUNT(*) as issues_count')
            )
            ->groupBy('categories.id', 'categories.name_en', 'categories.name_ar', 'categories.icon')
            ->orderByDesc('issues_count')
            ->limit($limit)
            ->get()
            ->map(fn ($cat) => [
                'id' => $cat->id,
                'name_en' => $cat->name_en,
                'name_ar' => $cat->name_ar,
                'icon' => $cat->icon,
                'issues_count' => $cat->issues_count,
            ])
            ->toArray();
    }

    /**
     * Get service provider performance metrics.
     */
    private function getServiceProviderPerformance(Carbon $dateFrom, Carbon $dateTo, int $limit = 5): array
    {
        return ServiceProvider::with('user:id,name')
            ->withCount([
                'assignments as total_assignments' => fn ($q) =>
                    $q->whereBetween('created_at', [$dateFrom, $dateTo]),
                'assignments as completed_assignments' => fn ($q) =>
                    $q->where('status', 'completed')
                        ->whereBetween('completed_at', [$dateFrom, $dateTo]),
            ])
            ->having('total_assignments', '>', 0)
            ->orderByDesc('completed_assignments')
            ->limit($limit)
            ->get()
            ->map(fn ($sp) => [
                'id' => $sp->id,
                'name' => $sp->user?->name,
                'total_assignments' => $sp->total_assignments,
                'completed_assignments' => $sp->completed_assignments,
                'completion_rate' => $sp->total_assignments > 0
                    ? round(($sp->completed_assignments / $sp->total_assignments) * 100, 1)
                    : 0,
            ])
            ->toArray();
    }
}
