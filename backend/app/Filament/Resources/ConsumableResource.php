<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ConsumableResource\Pages;
use App\Models\Category;
use App\Models\Consumable;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ConsumableResource extends Resource
{
    protected static ?string $model = Consumable::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-cube';

    protected static ?int $navigationSort = 2;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.master_data');
    }

    public static function getModelLabel(): string
    {
        return __('consumables.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('consumables.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->columns(1)
            ->components([
                Section::make(__('consumables.sections.basic_info'))
                    ->schema([
                        Forms\Components\Select::make('category_id')
                            ->label(__('consumables.fields.category'))
                            ->relationship('category', 'name_en')
                            ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                            ->searchable()
                            ->preload()
                            ->required()
                            ->createOptionForm([
                                Forms\Components\TextInput::make('name_en')
                                    ->label(__('categories.fields.name_en'))
                                    ->required()
                                    ->maxLength(255),

                                Forms\Components\TextInput::make('name_ar')
                                    ->label(__('categories.fields.name_ar'))
                                    ->required()
                                    ->maxLength(255),

                                Forms\Components\Toggle::make('is_active')
                                    ->label(__('categories.fields.is_active'))
                                    ->default(true),
                            ]),

                        Forms\Components\TextInput::make('name_en')
                            ->label(__('consumables.fields.name_en'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('name_ar')
                            ->label(__('consumables.fields.name_ar'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\Toggle::make('is_active')
                            ->label(__('consumables.fields.is_active'))
                            ->default(true)
                            ->inline(false),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('category.name_en')
                    ->label(__('consumables.fields.category'))
                    ->formatStateUsing(fn ($record) => $record->category?->name)
                    ->badge()
                    ->color('info')
                    ->sortable()
                    ->searchable(),

                Tables\Columns\TextColumn::make('name_en')
                    ->label(__('consumables.fields.name_en'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('name_ar')
                    ->label(__('consumables.fields.name_ar'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('consumables.fields.is_active'))
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('danger')
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('category_id')
                    ->label(__('consumables.filters.category'))
                    ->relationship('category', 'name_en')
                    ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                    ->searchable()
                    ->preload()
                    ->multiple(),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('consumables.filters.active')),
            ])
            ->actions([
                EditAction::make()
                    ->visible(fn ($record) => auth()->user()->can('update', $record))
                    ->slideOver()
                    ->modalWidth('lg'),

                Action::make('toggle_active')
                    ->authorize('toggleActive')
                    ->icon(fn (Consumable $record) => $record->is_active
                        ? 'heroicon-o-x-circle'
                        : 'heroicon-o-check-circle')
                    ->color(fn (Consumable $record) => $record->is_active ? 'danger' : 'success')
                    ->iconButton()
                    ->tooltip(fn (Consumable $record) => $record->is_active
                        ? __('consumables.actions.deactivate')
                        : __('consumables.actions.activate'))
                    ->requiresConfirmation()
                    ->action(fn (Consumable $record) => $record->update(['is_active' => ! $record->is_active])),

                DeleteAction::make()
                    ->visible(fn ($record) => auth()->user()->can('delete', $record)),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),

                    BulkAction::make('activate')
                        ->label(__('consumables.actions.activate'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(function ($records): void {
                            if (! auth()->user()->can('Update:Consumable')) {
                                Notification::make()->danger()->title(__('filament-actions::delete.multiple.messages.unauthorized'))->send();

                                return;
                            }
                            $records->each(fn (Consumable $record) => $record->update(['is_active' => true]));
                        }),

                    BulkAction::make('deactivate')
                        ->label(__('consumables.actions.deactivate'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->action(function ($records): void {
                            if (! auth()->user()->can('Update:Consumable')) {
                                Notification::make()->danger()->title(__('filament-actions::delete.multiple.messages.unauthorized'))->send();

                                return;
                            }
                            $records->each(fn (Consumable $record) => $record->update(['is_active' => false]));
                        }),

                    BulkAction::make('change_category')
                        ->label(__('consumables.actions.change_category'))
                        ->icon('heroicon-o-arrow-path')
                        ->color('warning')
                        ->form([
                            Forms\Components\Select::make('category_id')
                                ->label(__('consumables.fields.category'))
                                ->relationship('category', 'name_en')
                                ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                                ->searchable()
                                ->preload()
                                ->required(),
                        ])
                        ->action(function ($records, array $data): void {
                            if (! auth()->user()->can('Update:Consumable')) {
                                Notification::make()->danger()->title(__('filament-actions::delete.multiple.messages.unauthorized'))->send();

                                return;
                            }
                            $records->each(fn (Consumable $record) => $record->update(['category_id' => $data['category_id']]));
                        }),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListConsumables::route('/'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with(['category']);
    }
}
