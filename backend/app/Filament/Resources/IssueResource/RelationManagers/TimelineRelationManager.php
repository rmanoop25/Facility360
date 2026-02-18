<?php

namespace App\Filament\Resources\IssueResource\RelationManagers;

use App\Enums\TimelineAction;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

class TimelineRelationManager extends RelationManager
{
    protected static string $relationship = 'timeline';

    public static function getTitle($ownerRecord, string $pageClass): string
    {
        return __('timeline.plural');
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('id')
            ->columns([
                Tables\Columns\TextColumn::make('action')
                    ->label(__('timeline.fields.action'))
                    ->badge()
                    ->formatStateUsing(fn (TimelineAction $state): string => $state->label())
                    ->color(fn (TimelineAction $state): string => $state->color())
                    ->icon(fn (TimelineAction $state): string => $state->icon()),

                Tables\Columns\TextColumn::make('performedByUser.name')
                    ->label(__('timeline.fields.performed_by'))
                    ->default(__('timeline.system')),

                Tables\Columns\TextColumn::make('notes')
                    ->label(__('timeline.fields.notes'))
                    ->limit(50)
                    ->tooltip(fn ($record) => $record->notes),

                Tables\Columns\TextColumn::make('assignment.serviceProvider.user.name')
                    ->label(__('timeline.fields.service_provider'))
                    ->url(fn ($record) => $record->assignment?->serviceProvider
                            ? \App\Filament\Resources\ServiceProviderResource::getUrl('view', ['record' => $record->assignment->serviceProvider->id])
                            : null
                    )
                    ->color(fn ($record) => $record->assignment?->serviceProvider ? 'primary' : null)
                    ->icon(fn ($record) => $record->assignment?->serviceProvider ? 'heroicon-o-arrow-top-right-on-square' : null)
                    ->placeholder('—')
                    ->toggleable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('action')
                    ->label(__('timeline.filters.action'))
                    ->options(
                        collect(TimelineAction::cases())
                            ->mapWithKeys(fn (TimelineAction $action) => [$action->value => $action->label()])
                            ->toArray()
                    ),
            ])
            ->actions([
                //
            ])
            ->bulkActions([
                //
            ])
            ->defaultSort('created_at', 'asc')
            ->paginated(false);
    }

    public function isReadOnly(): bool
    {
        return true;
    }
}
