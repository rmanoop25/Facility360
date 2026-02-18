<?php



namespace App\Filament\Resources\IssueResource\Pages;

use App\Enums\IssueStatus;
use App\Filament\Resources\IssueResource;
use Filament\Actions;
use Filament\Schemas\Components\Tabs\Tab;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Database\Eloquent\Builder;

class ListIssues extends ListRecords
{
    protected static string $resource = IssueResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    public function getTabs(): array
    {
        return [
            'all' => Tab::make(__('issues.tabs.all'))
                ->icon('heroicon-o-clipboard-document-list'),

            'pending' => Tab::make(__('issues.tabs.pending'))
                ->icon('heroicon-o-clock')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', IssueStatus::PENDING))
                ->badge(fn () => static::getResource()::getModel()::where('status', IssueStatus::PENDING)->count())
                ->badgeColor('warning'),

            'assigned' => Tab::make(__('issues.tabs.assigned'))
                ->icon('heroicon-o-user-plus')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', IssueStatus::ASSIGNED))
                ->badge(fn () => static::getResource()::getModel()::where('status', IssueStatus::ASSIGNED)->count())
                ->badgeColor('info'),

            'in_progress' => Tab::make(__('issues.tabs.in_progress'))
                ->icon('heroicon-o-wrench-screwdriver')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', IssueStatus::IN_PROGRESS))
                ->badge(fn () => static::getResource()::getModel()::where('status', IssueStatus::IN_PROGRESS)->count())
                ->badgeColor('primary'),

            'finished' => Tab::make(__('issues.tabs.finished'))
                ->icon('heroicon-o-check-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', IssueStatus::FINISHED))
                ->badge(fn () => static::getResource()::getModel()::where('status', IssueStatus::FINISHED)->count())
                ->badgeColor('success'),

            'completed' => Tab::make(__('issues.tabs.completed'))
                ->icon('heroicon-o-check-badge')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', IssueStatus::COMPLETED))
                ->badge(fn () => static::getResource()::getModel()::where('status', IssueStatus::COMPLETED)->count())
                ->badgeColor('success'),

            'cancelled' => Tab::make(__('issues.tabs.cancelled'))
                ->icon('heroicon-o-x-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', IssueStatus::CANCELLED))
                ->badge(fn () => static::getResource()::getModel()::where('status', IssueStatus::CANCELLED)->count())
                ->badgeColor('danger'),
        ];
    }
}
