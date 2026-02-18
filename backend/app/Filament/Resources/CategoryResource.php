<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Filament\Resources\CategoryResource\Pages;
use App\Models\Category;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\RestoreAction;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class CategoryResource extends Resource
{
    protected static ?string $model = Category::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-tag';

    protected static ?int $navigationSort = 1;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.master_data');
    }

    public static function getModelLabel(): string
    {
        return __('categories.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('categories.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->columns(1)
            ->components([
                Section::make(__('categories.sections.basic_info'))
                    ->schema([
                        // Parent category selector
                        Forms\Components\Select::make('parent_id')
                            ->label(__('categories.fields.parent'))
                            ->relationship('parent', 'name_en')
                            ->searchable()
                            ->preload()
                            ->nullable()
                            ->placeholder(__('categories.fields.no_parent'))
                            ->helperText(__('categories.fields.parent_help'))
                            ->options(function (?Category $record): array {
                                $query = Category::query()->active()->orderByHierarchy();

                                if ($record) {
                                    // Exclude self and all descendants
                                    $excludeIds = collect([$record->id]);
                                    $excludeIds = $excludeIds->merge($record->getDescendantIds());
                                    $query->whereNotIn('id', $excludeIds);
                                }

                                return $query->get()->mapWithKeys(fn (Category $cat) => [
                                    $cat->id => str_repeat('— ', $cat->depth).$cat->name_en,
                                ])->toArray();
                            }),

                        // Current depth display (read-only)
                        Forms\Components\Placeholder::make('depth_display')
                            ->label(__('categories.fields.depth'))
                            ->content(fn (?Category $record): string => $record
                                ? __('categories.depth_level', ['level' => $record->depth])
                                : __('categories.depth_level', ['level' => 0])
                            )
                            ->visible(fn (?Category $record): bool => $record !== null),

                        // Full path display (read-only)
                        Forms\Components\Placeholder::make('path_display')
                            ->label(__('categories.fields.full_path'))
                            ->content(fn (?Category $record): string => $record?->full_path_name_en ?? '')
                            ->visible(fn (?Category $record): bool => $record !== null && $record->depth > 0),

                        Forms\Components\TextInput::make('name_en')
                            ->label(__('categories.fields.name_en'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('name_ar')
                            ->label(__('categories.fields.name_ar'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\Select::make('icon')
                            ->label(__('categories.fields.icon'))
                            ->options(fn () => collect(self::getIconOptions())
                                ->mapWithKeys(fn ($label, $value) => [$value => self::getIconOptionHtml($value)])
                                ->toArray())
                            ->searchable()
                            ->preload()
                            ->allowHtml()
                            ->extraAttributes(['class' => 'icon-grid-select'])
                            ->getOptionLabelUsing(fn (string $value): string => self::getIconOptionHtml($value))
                            ->getSearchResultsUsing(function (string $search): array {
                                return collect(self::getIconOptions())
                                    ->filter(fn ($label, $value) => str_contains(strtolower($label), strtolower($search)))
                                    ->mapWithKeys(fn ($label, $value) => [$value => self::getIconOptionHtml($value)])
                                    ->toArray();
                            }),

                        Forms\Components\Toggle::make('is_active')
                            ->label(__('categories.fields.is_active'))
                            ->default(true)
                            ->inline(false)
                            ->helperText(__('categories.fields.is_active_help')),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('path', 'asc') // Sort by hierarchy
            ->columns([
                Tables\Columns\TextColumn::make('icon')
                    ->label(__('categories.fields.icon'))
                    ->icon(fn ($state) => $state ?: 'heroicon-o-tag')
                    ->iconColor('primary')
                    ->formatStateUsing(fn () => '')
                    ->width(50),

                // Hierarchical name display with indentation
                Tables\Columns\TextColumn::make('name_en')
                    ->label(__('categories.fields.name_en'))
                    ->searchable()
                    ->sortable()
                    ->formatStateUsing(fn (Category $record): string => str_repeat('— ', $record->depth).$record->name_en)
                    ->description(fn (Category $record): ?string => $record->depth > 0 ? $record->parent?->name_en : null),

                Tables\Columns\TextColumn::make('name_ar')
                    ->label(__('categories.fields.name_ar'))
                    ->searchable()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),

                // Depth badge
                Tables\Columns\TextColumn::make('depth')
                    ->label(__('categories.fields.depth'))
                    ->badge()
                    ->color(fn (int $state): string => match (true) {
                        $state === 0 => 'primary',
                        $state === 1 => 'info',
                        $state === 2 => 'warning',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (int $state): string => __('categories.level', ['level' => $state]))
                    ->sortable(),

                // Children count
                Tables\Columns\TextColumn::make('children_count')
                    ->label(__('categories.fields.children_count'))
                    ->counts('children')
                    ->sortable()
                    ->badge()
                    ->color('success')
                    ->placeholder('-'),

                Tables\Columns\TextColumn::make('consumables_count')
                    ->label(__('categories.fields.consumables_count'))
                    ->counts('consumables')
                    ->sortable()
                    ->badge()
                    ->color('primary')
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('service_providers_count')
                    ->label(__('categories.fields.service_providers_count'))
                    ->counts('serviceProviders')
                    ->sortable()
                    ->badge()
                    ->color('info')
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('categories.fields.is_active'))
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
                // Root categories only
                Tables\Filters\TernaryFilter::make('roots_only')
                    ->label(__('categories.filters.roots_only'))
                    ->queries(
                        true: fn (Builder $query) => $query->roots(),
                        false: fn (Builder $query) => $query->whereNotNull('parent_id'),
                        blank: fn (Builder $query) => $query,
                    ),

                // Filter by depth
                Tables\Filters\SelectFilter::make('depth')
                    ->label(__('categories.filters.depth'))
                    ->options([
                        '0' => __('categories.depth_options.root'),
                        '1' => __('categories.depth_options.level_1'),
                        '2' => __('categories.depth_options.level_2'),
                        '3' => __('categories.depth_options.level_3_plus'),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        if (blank($data['value'])) {
                            return $query;
                        }

                        $depth = (int) $data['value'];
                        if ($depth === 3) {
                            return $query->where('depth', '>=', 3);
                        }

                        return $query->where('depth', $depth);
                    }),

                // Filter by parent
                Tables\Filters\SelectFilter::make('parent_id')
                    ->label(__('categories.filters.parent'))
                    ->relationship('parent', 'name_en')
                    ->searchable()
                    ->preload(),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('categories.filters.active')),

                Tables\Filters\Filter::make('has_children')
                    ->label(__('categories.filters.has_children'))
                    ->query(fn (Builder $query) => $query->has('children')),

                Tables\Filters\Filter::make('has_consumables')
                    ->label(__('categories.filters.has_consumables'))
                    ->query(fn (Builder $query) => $query->has('consumables')),

                Tables\Filters\Filter::make('has_service_providers')
                    ->label(__('categories.filters.has_service_providers'))
                    ->query(fn (Builder $query) => $query->has('serviceProviders')),

                Tables\Filters\TrashedFilter::make(),
            ])
            ->actions([
                // View children action
                Action::make('view_children')
                    ->icon('heroicon-o-folder-open')
                    ->iconButton()
                    ->tooltip(__('categories.actions.view_children'))
                    ->url(fn (Category $record): string => static::getUrl('index', ['tableFilters[parent_id][value]' => $record->id]))
                    ->visible(fn (Category $record): bool => $record->has_children),

                EditAction::make()
                    ->visible(fn ($record) => auth()->user()->can('update', $record))
                    ->slideOver()
                    ->modalWidth('lg'),

                Action::make('toggle_active')
                    ->authorize('toggleActive')
                    ->icon(fn (Category $record) => $record->is_active
                        ? 'heroicon-o-x-circle'
                        : 'heroicon-o-check-circle')
                    ->color(fn (Category $record) => $record->is_active ? 'danger' : 'success')
                    ->iconButton()
                    ->tooltip(fn (Category $record) => $record->is_active
                        ? __('categories.actions.deactivate')
                        : __('categories.actions.activate'))
                    ->requiresConfirmation()
                    ->modalDescription(fn (Category $record) => $record->is_active && $record->has_children
                        ? __('categories.deactivate_warning_with_children', ['count' => $record->children_count])
                        : null)
                    ->action(fn (Category $record) => $record->update(['is_active' => ! $record->is_active])),

                // Archive action (soft delete)
                Action::make('archive')
                    ->authorize('archive')
                    ->icon('heroicon-o-archive-box')
                    ->color('warning')
                    ->iconButton()
                    ->tooltip(__('categories.actions.archive'))
                    ->requiresConfirmation()
                    ->modalHeading(__('categories.archive_heading'))
                    ->modalDescription(fn (Category $record): string => $record->has_children
                        ? __('categories.archive_warning_with_children', ['count' => Category::where('path', 'like', $record->path.'/%')->count()])
                        : __('categories.archive_warning'))
                    ->action(function (Category $record): void {
                        $record->archive();
                        Notification::make()
                            ->success()
                            ->title(__('categories.archived_successfully'))
                            ->send();
                    })
                    ->visible(fn (Category $record): bool => ! $record->trashed()),

                // Restore action
                RestoreAction::make()
                    ->visible(fn ($record) => auth()->user()->can('restore', $record))
                    ->iconButton(),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),

                    BulkAction::make('activate')
                        ->label(__('categories.actions.activate'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(function (Collection $records): void {
                            if (! auth()->user()->can('Update:Category')) {
                                Notification::make()->danger()->title(__('filament-actions::delete.multiple.messages.unauthorized'))->send();

                                return;
                            }
                            $records->each(fn (Category $record) => $record->update(['is_active' => true]));
                        }),

                    BulkAction::make('deactivate')
                        ->label(__('categories.actions.deactivate'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->modalDescription(__('categories.bulk_deactivate_warning'))
                        ->action(function (Collection $records): void {
                            if (! auth()->user()->can('Update:Category')) {
                                Notification::make()->danger()->title(__('filament-actions::delete.multiple.messages.unauthorized'))->send();

                                return;
                            }
                            $records->each(fn (Category $record) => $record->update(['is_active' => false]));
                        }),

                    BulkAction::make('archive')
                        ->label(__('categories.actions.archive'))
                        ->icon('heroicon-o-archive-box')
                        ->color('warning')
                        ->requiresConfirmation()
                        ->modalDescription(__('categories.bulk_archive_warning'))
                        ->action(function (Collection $records): void {
                            if (! auth()->user()->can('Delete:Category')) {
                                Notification::make()->danger()->title(__('filament-actions::delete.multiple.messages.unauthorized'))->send();

                                return;
                            }
                            $records->each(fn (Category $record) => $record->archive());
                        }),
                ]),
            ]);
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
            'index' => Pages\ListCategories::route('/'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->withoutGlobalScopes([
                SoftDeletingScope::class,
            ]);
    }

    protected static function getIconOptions(): array
    {
        return [
            'heroicon-o-wrench' => 'Wrench',
            'heroicon-o-wrench-screwdriver' => 'Wrench & Screwdriver',
            'heroicon-o-cog-6-tooth' => 'Settings/Cog',
            'heroicon-o-bolt' => 'Electricity/Bolt',
            'heroicon-o-fire' => 'Fire/Gas',
            'heroicon-o-beaker' => 'Plumbing/Beaker',
            'heroicon-o-home' => 'Home',
            'heroicon-o-building-office' => 'Building',
            'heroicon-o-paint-brush' => 'Painting',
            'heroicon-o-key' => 'Key/Locksmith',
            'heroicon-o-shield-check' => 'Security',
            'heroicon-o-truck' => 'Transport/Delivery',
            'heroicon-o-cube' => 'General/Box',
            'heroicon-o-scissors' => 'Scissors',
            'heroicon-o-sparkles' => 'Cleaning',
            'heroicon-o-sun' => 'AC/Cooling',
            'heroicon-o-wifi' => 'Internet/Network',
            'heroicon-o-tv' => 'TV/Electronics',
            'heroicon-o-phone' => 'Phone/Communication',
            'heroicon-o-light-bulb' => 'Lighting',
            'heroicon-o-window' => 'Window',
            'heroicon-o-arrow-path' => 'Maintenance/Repair',
            'heroicon-o-clipboard-document-list' => 'Checklist',
            'heroicon-o-calendar' => 'Scheduling',
            'heroicon-o-clock' => 'Time/Clock',
            'heroicon-o-exclamation-triangle' => 'Warning/Emergency',
            'heroicon-o-check-circle' => 'Verified/Done',
            'heroicon-o-tag' => 'Tag/Label',
        ];
    }

    protected static function getIconOptionHtml(string $value): string
    {
        $icons = self::getIconOptions();
        $label = $icons[$value] ?? $value;

        $svg = svg($value, 'inline-block')->toHtml();
        // Add inline styles to ensure consistent sizing in both dropdown and selected state
        $svg = str_replace('<svg', '<svg style="width: 1.25rem; height: 1.25rem; flex-shrink: 0;"', $svg);

        return "<span class=\"flex items-center gap-2\" style=\"display: inline-flex; align-items: center; gap: 0.5rem;\">{$svg}<span>{$label}</span></span>";
    }
}
