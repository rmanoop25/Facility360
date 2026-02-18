<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Filament\Resources\WorkTypeResource\Pages;
use App\Models\WorkType;
use BackedEnum;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;

class WorkTypeResource extends Resource
{
    protected static ?string $model = WorkType::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-clock';

    protected static ?int $navigationSort = 5;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.settings');
    }

    public static function getModelLabel(): string
    {
        return __('work_types.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('work_types.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->columns(1)
            ->components([
                Section::make(__('work_types.sections.basic_info'))
                    ->schema([
                        Forms\Components\TextInput::make('name_en')
                            ->label(__('work_types.fields.name_en'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('name_ar')
                            ->label(__('work_types.fields.name_ar'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('duration_minutes')
                            ->label(__('work_types.fields.duration_minutes'))
                            ->required()
                            ->numeric()
                            ->minValue(15)
                            ->maxValue(480)
                            ->suffix(__('work_types.minutes'))
                            ->helperText(__('work_types.duration_helper')),

                        Forms\Components\Select::make('categories')
                            ->label(__('work_types.fields.categories'))
                            ->multiple()
                            ->required()
                            ->relationship('categories', 'name_en')
                            ->preload()
                            ->searchable(),

                        Forms\Components\Toggle::make('is_active')
                            ->label(__('work_types.fields.is_active'))
                            ->default(true)
                            ->inline(false),
                    ]),

                Section::make(__('work_types.sections.description'))
                    ->schema([
                        Forms\Components\Textarea::make('description_en')
                            ->label(__('work_types.fields.description_en'))
                            ->rows(3)
                            ->maxLength(2000),

                        Forms\Components\Textarea::make('description_ar')
                            ->label(__('work_types.fields.description_ar'))
                            ->rows(3)
                            ->maxLength(2000),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label(__('work_types.fields.id'))
                    ->sortable(),

                Tables\Columns\TextColumn::make('name_en')
                    ->label(__('work_types.fields.name_en'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('name_ar')
                    ->label(__('work_types.fields.name_ar'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('formatted_duration')
                    ->label(__('work_types.fields.duration'))
                    ->sortable(query: fn ($query, $direction) => $query->orderBy('duration_minutes', $direction)
                    ),

                Tables\Columns\TextColumn::make('categories.name_en')
                    ->label(__('work_types.fields.categories'))
                    ->badge()
                    ->separator(','),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('work_types.fields.is_active'))
                    ->boolean()
                    ->sortable(),

                Tables\Columns\TextColumn::make('assignments_count')
                    ->label(__('work_types.fields.usage_count'))
                    ->counts('assignments')
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('categories')
                    ->label(__('work_types.filters.category'))
                    ->relationship('categories', 'name_en')
                    ->multiple()
                    ->preload(),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('work_types.filters.active')),
            ])
            ->actions([
                ViewAction::make()
                    ->slideOver()
                    ->modalWidth('lg'),
                EditAction::make()
                    ->slideOver()
                    ->modalWidth('lg'),
                DeleteAction::make(),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('name_en', 'asc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListWorkTypes::route('/'),
        ];
    }
}
