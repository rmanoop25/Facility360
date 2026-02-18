<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\IssueTimeline;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class RecentActivityWidget extends BaseWidget
{
    protected static ?int $sort = 3;

    protected int|string|array $columnSpan = 'full';

    public static function canView(): bool
    {
        return auth()->check();
    }

    protected static ?string $heading = null;

    public function getHeading(): ?string
    {
        return __('dashboard.widgets.recent_activity');
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(
                IssueTimeline::query()
                    ->with(['issue', 'performedBy', 'assignment.serviceProvider.user'])
                    ->orderBy('created_at', 'desc')
                    ->limit(50)
            )
            ->columns([
                Tables\Columns\TextColumn::make('issue.id')
                    ->label(__('issues.fields.id'))
                    ->sortable()
                    ->searchable(),

                Tables\Columns\TextColumn::make('issue.title')
                    ->label(__('issues.fields.title'))
                    ->limit(30)
                    ->tooltip(fn (IssueTimeline $record): string => $record->issue?->title ?? '')
                    ->url(fn (IssueTimeline $record): ?string => $record->issue
                        ? route('filament.admin.resources.issues.view', ['record' => $record->issue])
                        : null),

                Tables\Columns\TextColumn::make('action')
                    ->label(__('timeline.fields.action'))
                    ->badge()
                    ->formatStateUsing(fn ($state) => $state?->label() ?? $state)
                    ->color(fn ($state) => match($state?->value ?? $state) {
                        'created' => 'warning',
                        'assigned' => 'info',
                        'started' => 'primary',
                        'held' => 'gray',
                        'resumed' => 'primary',
                        'finished' => 'success',
                        'approved' => 'success',
                        'cancelled' => 'danger',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('performedBy.name')
                    ->label(__('timeline.fields.performed_by'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('notes')
                    ->label(__('timeline.fields.notes'))
                    ->limit(40)
                    ->placeholder('-')
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->since(),
            ])
            ->emptyStateHeading(__('dashboard.widgets.no_recent_activity'))
            ->emptyStateDescription(__('dashboard.widgets.no_recent_activity_description'))
            ->emptyStateIcon('heroicon-o-clock')
            ->paginated([10, 25, 50])
            ->defaultPaginationPageOption(10);
    }
}
