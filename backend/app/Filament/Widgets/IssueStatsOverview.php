<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Enums\IssueStatus;
use App\Models\Issue;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class IssueStatsOverview extends BaseWidget
{
    protected static ?int $sort = 1;

    public static function canView(): bool
    {
        return auth()->check();
    }

    protected function getStats(): array
    {
        return [
            Stat::make(__('dashboard.stats.pending_issues'), Issue::where('status', IssueStatus::PENDING)->count())
                ->description(__('dashboard.stats.pending_description'))
                ->descriptionIcon('heroicon-m-clock')
                ->color('warning')
                ->chart($this->getChartData(IssueStatus::PENDING)),

            Stat::make(__('dashboard.stats.in_progress'), Issue::where('status', IssueStatus::IN_PROGRESS)->count())
                ->description(__('dashboard.stats.in_progress_description'))
                ->descriptionIcon('heroicon-m-wrench-screwdriver')
                ->color('primary')
                ->chart($this->getChartData(IssueStatus::IN_PROGRESS)),

            Stat::make(__('dashboard.stats.awaiting_approval'), Issue::where('status', IssueStatus::FINISHED)->count())
                ->description(__('dashboard.stats.awaiting_approval_description'))
                ->descriptionIcon('heroicon-m-check-circle')
                ->color('success')
                ->chart($this->getChartData(IssueStatus::FINISHED)),

            Stat::make(__('dashboard.stats.completed_today'), $this->getCompletedTodayCount())
                ->description(__('dashboard.stats.completed_today_description'))
                ->descriptionIcon('heroicon-m-check-badge')
                ->color('success'),
        ];
    }

    protected function getChartData(IssueStatus $status): array
    {
        // Get issues count for the last 7 days
        return Issue::where('status', $status)
            ->where('created_at', '>=', now()->subDays(7))
            ->selectRaw('DATE(created_at) as date, COUNT(*) as count')
            ->groupBy('date')
            ->orderBy('date')
            ->pluck('count')
            ->toArray();
    }

    protected function getCompletedTodayCount(): int
    {
        return Issue::where('status', IssueStatus::COMPLETED)
            ->whereDate('updated_at', today())
            ->count();
    }
}
