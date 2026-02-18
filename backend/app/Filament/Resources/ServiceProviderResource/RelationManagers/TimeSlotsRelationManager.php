<?php

namespace App\Filament\Resources\ServiceProviderResource\RelationManagers;

use App\Filament\Resources\ServiceProviderResource;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;

class TimeSlotsRelationManager extends RelationManager
{
    protected static string $relationship = 'timeSlots';

    public static function getTitle($ownerRecord, string $pageClass): string
    {
        return __('time_slots.plural');
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Forms\Components\Select::make('day_of_week')
                    ->label(__('time_slots.fields.day_of_week'))
                    ->options(ServiceProviderResource::getDayOptions())
                    ->required()
                    ->native(false),

                Forms\Components\TimePicker::make('start_time')
                    ->label(__('time_slots.fields.start_time'))
                    ->required()
                    ->seconds(false),

                Forms\Components\TimePicker::make('end_time')
                    ->label(__('time_slots.fields.end_time'))
                    ->required()
                    ->seconds(false)
                    ->after('start_time'),

                Forms\Components\Toggle::make('is_active')
                    ->label(__('time_slots.fields.is_active'))
                    ->default(true)
                    ->inline(false),
            ])
            ->columns(2);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('display_name')
            ->columns([
                Tables\Columns\TextColumn::make('day_of_week')
                    ->label(__('time_slots.fields.day_of_week'))
                    ->formatStateUsing(fn (int $state): string => match ($state) {
                        0 => __('days.sunday'),
                        1 => __('days.monday'),
                        2 => __('days.tuesday'),
                        3 => __('days.wednesday'),
                        4 => __('days.thursday'),
                        5 => __('days.friday'),
                        6 => __('days.saturday'),
                        default => '',
                    })
                    ->badge()
                    ->color(fn (int $state): string => match ($state) {
                        5, 6 => 'warning', // Friday, Saturday - weekend in some regions
                        default => 'primary',
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('start_time')
                    ->label(__('time_slots.fields.start_time'))
                    ->time('H:i')
                    ->sortable(),

                Tables\Columns\TextColumn::make('end_time')
                    ->label(__('time_slots.fields.end_time'))
                    ->time('H:i')
                    ->sortable(),

                Tables\Columns\TextColumn::make('formatted_time_range')
                    ->label(__('time_slots.fields.time_range'))
                    ->badge()
                    ->color('info'),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('time_slots.fields.is_active'))
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('danger'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('day_of_week')
                    ->label(__('time_slots.filters.day'))
                    ->options([
                        0 => __('days.sunday'),
                        1 => __('days.monday'),
                        2 => __('days.tuesday'),
                        3 => __('days.wednesday'),
                        4 => __('days.thursday'),
                        5 => __('days.friday'),
                        6 => __('days.saturday'),
                    ]),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('time_slots.filters.active')),
            ])
            ->headerActions([
                CreateAction::make(),
            ])
            ->actions([
                EditAction::make(),

                Action::make('toggle_active')
                    ->icon(fn ($record) => $record->is_active
                        ? 'heroicon-o-x-circle'
                        : 'heroicon-o-check-circle')
                    ->color(fn ($record) => $record->is_active ? 'danger' : 'success')
                    ->iconButton()
                    ->tooltip(fn ($record) => $record->is_active
                        ? __('time_slots.actions.deactivate')
                        : __('time_slots.actions.activate'))
                    ->requiresConfirmation()
                    ->action(fn ($record) => $record->update(['is_active' => ! $record->is_active])),

                DeleteAction::make(),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),

                    BulkAction::make('activate')
                        ->label(__('time_slots.actions.activate'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->action(fn ($records) => $records->each(fn ($record) => $record->update(['is_active' => true]))),

                    BulkAction::make('deactivate')
                        ->label(__('time_slots.actions.deactivate'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->action(fn ($records) => $records->each(fn ($record) => $record->update(['is_active' => false]))),
                ]),
            ])
            ->defaultSort('day_of_week');
    }
}
