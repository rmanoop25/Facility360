<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\IssueStatus;
use App\Http\Controllers\Api\V1\ApiController;
use App\Models\Issue;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class DashboardController extends ApiController
{
    /**
     * Get dashboard statistics.
     */
    public function stats(): JsonResponse
    {
        $today = Carbon::today();
        $thisMonth = Carbon::now()->startOfMonth();

        // Issue statistics
        $issueStats = Issue::selectRaw('
            COUNT(*) as total,
            SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as pending,
            SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as assigned,
            SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as in_progress,
            SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as finished,
            SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as completed,
            SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as cancelled,
            SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) as today_created,
            SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) as month_created
        ', [
            IssueStatus::PENDING->value,
            IssueStatus::ASSIGNED->value,
            IssueStatus::IN_PROGRESS->value,
            IssueStatus::FINISHED->value,
            IssueStatus::COMPLETED->value,
            IssueStatus::CANCELLED->value,
            $today,
            $thisMonth,
        ])->first();

        // User statistics
        $tenantCount = Tenant::count();
        $activeTenantCount = Tenant::whereHas('user', fn ($q) => $q->where('is_active', true))->count();

        $providerCount = ServiceProvider::count();
        $activeProviderCount = ServiceProvider::whereHas('user', fn ($q) => $q->where('is_active', true))->count();

        // Issues awaiting approval
        $awaitingApproval = Issue::where('status', IssueStatus::FINISHED)->count();

        // Issues by priority this month
        $issuesByPriority = Issue::where('created_at', '>=', $thisMonth)
            ->selectRaw('priority, COUNT(*) as count')
            ->groupBy('priority')
            ->pluck('count', 'priority')
            ->toArray();

        // Recent issues
        $recentIssues = Issue::with([
            'tenant.user:id,name',
            'categories:id,name_en,name_ar',
        ])
            ->latest()
            ->limit(5)
            ->get()
            ->map(fn ($issue) => [
                'id' => $issue->id,
                'title' => $issue->title,
                'status' => $issue->status->value,
                'status_label' => $issue->status->label(),
                'priority' => $issue->priority->value,
                'tenant_name' => $issue->tenant?->user?->name ?? 'N/A',
                'created_at' => $issue->created_at->format('Y-m-d\TH:i:s\Z'),
            ])
            ->values()
            ->toArray();

        return $this->success([
            'issues' => [
                'total' => $issueStats->total ?? 0,
                'pending' => $issueStats->pending ?? 0,
                'assigned' => $issueStats->assigned ?? 0,
                'in_progress' => $issueStats->in_progress ?? 0,
                'finished' => $issueStats->finished ?? 0,
                'completed' => $issueStats->completed ?? 0,
                'cancelled' => $issueStats->cancelled ?? 0,
                'today_created' => $issueStats->today_created ?? 0,
                'month_created' => $issueStats->month_created ?? 0,
                'awaiting_approval' => $awaitingApproval,
            ],
            'issues_by_priority' => $issuesByPriority,
            'tenants' => [
                'total' => $tenantCount,
                'active' => $activeTenantCount,
            ],
            'service_providers' => [
                'total' => $providerCount,
                'active' => $activeProviderCount,
            ],
            'recent_issues' => $recentIssues,
        ], __('api.dashboard.stats_success'));
    }
}
