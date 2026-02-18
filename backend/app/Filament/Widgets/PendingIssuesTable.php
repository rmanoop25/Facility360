<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Filament\Resources\IssueResource;
use App\Models\Issue;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class PendingIssuesTable extends BaseWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    public static function canView(): bool
    {
        return auth()->check();
    }

    protected static ?string $heading = null;

    public function getHeading(): ?string
    {
        return __('dashboard.widgets.pending_issues');
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(
                Issue::query()
                    ->where('status', IssueStatus::PENDING)
                    ->with(['tenant.user', 'categories'])
                    ->orderBy('priority', 'desc')
                    ->orderBy('created_at', 'asc')
            )
            ->columns([
                TextColumn::make('id')
                    ->label(__('issues.fields.id'))
                    ->sortable()
                    ->searchable(),

                TextColumn::make('title')
                    ->label(__('issues.fields.title'))
                    ->limit(40)
                    ->tooltip(fn (Issue $record): string => $record->title)
                    ->searchable(),

                TextColumn::make('tenant.user.name')
                    ->label(__('issues.fields.tenant'))
                    ->searchable(),

                TextColumn::make('categories.name_en')
                    ->label(__('issues.fields.categories'))
                    ->badge()
                    ->color('info')
                    ->formatStateUsing(fn ($state, Issue $record) => $record->categories->pluck('name')->implode(', '))
                    ->limit(30),

                TextColumn::make('priority')
                    ->label(__('issues.fields.priority'))
                    ->badge()
                    ->formatStateUsing(fn (IssuePriority $state): string => $state->label())
                    ->color(fn (IssuePriority $state): string => $state->color()),

                TextColumn::make('created_at')
                    ->label(__('issues.fields.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->since(),
            ])
            ->recordUrl(fn (Issue $record): string => IssueResource::getUrl('view', ['record' => $record]))
            ->emptyStateHeading(__('dashboard.widgets.no_pending_issues'))
            ->emptyStateDescription(__('dashboard.widgets.no_pending_issues_description'))
            ->emptyStateIcon('heroicon-o-check-circle')
            ->paginated([5, 10, 25])
            ->defaultPaginationPageOption(5);
    }
}
