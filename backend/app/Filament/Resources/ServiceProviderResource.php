<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ServiceProviderResource\Pages;
use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\User;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\ViewField;
use Filament\Infolists;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Actions;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Hash;

class ServiceProviderResource extends Resource
{
    protected static ?string $model = ServiceProvider::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-wrench-screwdriver';

    protected static ?int $navigationSort = 2;

    // Day options constant to eliminate duplication
    public const DAY_OPTIONS = [
        0 => 'days.sunday',
        1 => 'days.monday',
        2 => 'days.tuesday',
        3 => 'days.wednesday',
        4 => 'days.thursday',
        5 => 'days.friday',
        6 => 'days.saturday',
    ];

    // Helper method that returns localized day names
    public static function getDayOptions(): array
    {
        return collect(self::DAY_OPTIONS)
            ->mapWithKeys(fn ($key, $value) => [$value => __($key)])
            ->toArray();
    }

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.users');
    }

    public static function getModelLabel(): string
    {
        return __('service_providers.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('service_providers.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('service_providers.sections.personal_info'))
                    ->schema([
                        Grid::make(3)
                            ->schema([
                                Forms\Components\FileUpload::make('profile_photo')
                                    ->label(__('service_providers.fields.profile_photo'))
                                    ->image()
                                    ->avatar()
                                    ->directory('profile-photos')
                                    ->maxSize(2048)
                                    ->imageResizeMode('cover')
                                    ->imageCropAspectRatio('1:1')
                                    ->imageResizeTargetWidth('200')
                                    ->imageResizeTargetHeight('200')
                                    ->columnSpan(1),

                                Grid::make(2)
                                    ->schema([
                                        Forms\Components\TextInput::make('user.name')
                                            ->label(__('service_providers.fields.name'))
                                            ->required()
                                            ->maxLength(255),

                                        Forms\Components\TextInput::make('user.email')
                                            ->label(__('service_providers.fields.email'))
                                            ->email()
                                            ->required()
                                            ->unique(
                                                table: User::class,
                                                column: 'email',
                                                ignorable: fn ($record) => $record?->user
                                            )
                                            ->maxLength(255),

                                        Forms\Components\TextInput::make('user.password')
                                            ->label(__('service_providers.fields.password'))
                                            ->password()
                                            ->revealable()
                                            ->required(fn (string $operation): bool => $operation === 'create')
                                            ->dehydrated(fn (?string $state): bool => filled($state))
                                            ->minLength(8)
                                            ->maxLength(255)
                                            ->visibleOn('create'),

                                        Forms\Components\TextInput::make('user.phone')
                                            ->label(__('service_providers.fields.phone'))
                                            ->tel()
                                            ->maxLength(20),
                                    ])
                                    ->columnSpan(2),
                            ]),
                    ]),

                Section::make(__('service_providers.sections.work_info'))
                    ->schema([
                        Forms\Components\Select::make('categories')
                            ->label(__('service_providers.fields.categories'))
                            ->relationship('categories', 'name_en')
                            ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                            ->multiple()
                            ->searchable()
                            ->preload()
                            ->required()
                            ->minItems(1),

                        Forms\Components\Toggle::make('is_available')
                            ->label(__('service_providers.fields.is_available'))
                            ->default(true)
                            ->inline(false),
                    ])
                    ->columns(2),

                Section::make(__('service_providers.sections.time_slots'))
                    ->description(__('service_providers.sections.time_slots_description'))
                    ->schema([
                        // Quick Setup Section
                        Section::make(__('time_slots.sections.quick_setup'))
                            ->description(__('time_slots.sections.quick_setup_description'))
                            ->schema([
                                CheckboxList::make('quick_setup.selected_days')
                                    ->label(__('time_slots.fields.select_days'))
                                    ->options(self::getDayOptions())
                                    ->columns(4)
                                    ->bulkToggleable()
                                    ->hintActions([
                                        Action::make('weekdays')
                                            ->label(__('time_slots.presets.weekdays'))
                                            ->link()
                                            ->size('sm')
                                            ->action(fn (Set $set) => $set('quick_setup.selected_days', [1, 2, 3, 4, 5])),
                                        Action::make('weekend')
                                            ->label(__('time_slots.presets.weekend'))
                                            ->link()
                                            ->size('sm')
                                            ->action(fn (Set $set) => $set('quick_setup.selected_days', [0, 6])),
                                        Action::make('all_week')
                                            ->label(__('time_slots.presets.all_week'))
                                            ->link()
                                            ->size('sm')
                                            ->action(fn (Set $set) => $set('quick_setup.selected_days', [0, 1, 2, 3, 4, 5, 6])),
                                    ]),

                                Grid::make(4)->schema([
                                    Forms\Components\Toggle::make('quick_setup.is_full_day')
                                        ->label(__('time_slots.fields.is_full_day'))
                                        ->live()
                                        ->afterStateUpdated(function (bool $state, Set $set) {
                                            if ($state) {
                                                $set('quick_setup.start_time', '00:00');
                                                $set('quick_setup.end_time', '23:59');
                                            }
                                        })
                                        ->columnSpan(1),

                                    Forms\Components\TimePicker::make('quick_setup.start_time')
                                        ->label(__('time_slots.fields.start_time'))
                                        ->seconds(false)
                                        ->default('09:00')
                                        ->disabled(fn (Get $get) => $get('quick_setup.is_full_day'))
                                        ->columnSpan(1),

                                    Forms\Components\TimePicker::make('quick_setup.end_time')
                                        ->label(__('time_slots.fields.end_time'))
                                        ->seconds(false)
                                        ->default('17:00')
                                        ->after('quick_setup.start_time')
                                        ->disabled(fn (Get $get) => $get('quick_setup.is_full_day'))
                                        ->columnSpan(1),
                                ]),

                                Actions::make([
                                    Action::make('apply_to_days')
                                        ->label(__('time_slots.actions.apply_to_selected'))
                                        ->icon('heroicon-o-check')
                                        ->color('primary')
                                        ->action(function (Get $get, Set $set) {
                                            $selectedDays = $get('quick_setup.selected_days') ?? [];
                                            $startTime = $get('quick_setup.start_time');
                                            $endTime = $get('quick_setup.end_time');
                                            $isFullDay = $get('quick_setup.is_full_day') ?? false;

                                            if (empty($selectedDays)) {
                                                Notification::make()
                                                    ->warning()
                                                    ->title(__('time_slots.messages.no_days_selected'))
                                                    ->send();

                                                return;
                                            }

                                            if (! $isFullDay && (empty($startTime) || empty($endTime))) {
                                                Notification::make()
                                                    ->warning()
                                                    ->title(__('time_slots.messages.select_time_first'))
                                                    ->send();

                                                return;
                                            }

                                            $currentSlots = $get('timeSlots') ?? [];
                                            $currentSlots = is_array($currentSlots) ? $currentSlots : [];

                                            foreach ($selectedDays as $day) {
                                                $existingIndex = null;
                                                foreach ($currentSlots as $index => $slot) {
                                                    if (isset($slot['day_of_week']) && $slot['day_of_week'] == $day) {
                                                        $existingIndex = $index;
                                                        break;
                                                    }
                                                }

                                                $slotData = [
                                                    'day_of_week' => (int) $day,
                                                    'start_time' => $isFullDay ? '00:00' : $startTime,
                                                    'end_time' => $isFullDay ? '23:59' : $endTime,
                                                    'is_active' => true,
                                                    'is_full_day' => $isFullDay,
                                                ];

                                                if ($existingIndex !== null) {
                                                    $currentSlots[$existingIndex] = array_merge(
                                                        $currentSlots[$existingIndex],
                                                        $slotData
                                                    );
                                                } else {
                                                    $currentSlots[] = $slotData;
                                                }
                                            }

                                            // Sort by day of week
                                            usort($currentSlots, fn ($a, $b) => ($a['day_of_week'] ?? 0) <=> ($b['day_of_week'] ?? 0));

                                            $set('timeSlots', array_values($currentSlots));

                                            Notification::make()
                                                ->success()
                                                ->title(__('time_slots.messages.applied_successfully'))
                                                ->send();
                                        }),

                                    Action::make('clear_all')
                                        ->label(__('time_slots.actions.clear_all'))
                                        ->icon('heroicon-o-trash')
                                        ->color('danger')
                                        ->requiresConfirmation()
                                        ->action(function (Set $set) {
                                            $set('timeSlots', []);
                                            $set('quick_setup.selected_days', []);

                                            Notification::make()
                                                ->success()
                                                ->title(__('time_slots.messages.cleared_successfully'))
                                                ->send();
                                        }),
                                ]),
                            ])
                            ->collapsible()
                            ->collapsed(fn (string $operation): bool => $operation === 'edit'),

                        // Weekly Schedule Preview
                        Section::make(__('time_slots.sections.weekly_schedule'))
                            ->description(__('time_slots.sections.weekly_schedule_description'))
                            ->schema([
                                ViewField::make('time_slots_preview')
                                    ->view('filament.components.time-slots-schedule')
                                    ->viewData(fn (Get $get) => [
                                        'timeSlots' => $get('timeSlots') ?? [],
                                    ])
                                    ->columnSpanFull(),

                                // Keep the repeater for individual adjustments
                                Repeater::make('timeSlots')
                                    ->schema([
                                        Forms\Components\Select::make('day_of_week')
                                            ->label(__('time_slots.fields.day_of_week'))
                                            ->options(self::getDayOptions())
                                            ->required()
                                            ->native(false)
                                            ->columnSpan(2),

                                        Forms\Components\Toggle::make('is_full_day')
                                            ->label(__('time_slots.fields.is_full_day'))
                                            ->live()
                                            ->afterStateUpdated(function (bool $state, Set $set) {
                                                if ($state) {
                                                    $set('start_time', '00:00');
                                                    $set('end_time', '23:59');
                                                }
                                            })
                                            ->columnSpan(2),

                                        Forms\Components\TimePicker::make('start_time')
                                            ->label(__('time_slots.fields.start_time'))
                                            ->required()
                                            ->seconds(false)
                                            ->default('09:00')
                                            ->disabled(fn (Get $get) => $get('is_full_day'))
                                            ->dehydrated()
                                            ->columnSpan(2),

                                        Forms\Components\TimePicker::make('end_time')
                                            ->label(__('time_slots.fields.end_time'))
                                            ->required()
                                            ->seconds(false)
                                            ->default('17:00')
                                            ->after('start_time')
                                            ->disabled(fn (Get $get) => $get('is_full_day'))
                                            ->dehydrated()
                                            ->columnSpan(2),

                                        Forms\Components\Toggle::make('is_active')
                                            ->label(__('time_slots.fields.is_active'))
                                            ->default(true)
                                            ->inline(false)
                                            ->columnSpan(1),
                                    ])
                                    ->columns(8)
                                    ->itemLabel(fn (array $state): ?string => isset($state['day_of_week'])
                                            ? sprintf(
                                                '%s: %s - %s%s',
                                                __('days.'.['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'][$state['day_of_week']]),
                                                $state['start_time'] ?? '00:00',
                                                $state['end_time'] ?? '00:00',
                                                ! ($state['is_active'] ?? true) ? ' ('.__('time_slots.status.inactive').')' : ''
                                            )
                                            : __('time_slots.actions.new_slot')
                                    )
                                    ->addActionLabel(__('time_slots.actions.add_slot'))
                                    ->reorderable(true)
                                    ->live(),
                            ])
                            ->collapsible(),
                    ])
                    ->columnSpanFull()
                    ->collapsible()
                    ->collapsed(fn (string $operation): bool => $operation === 'edit'),

                Section::make(__('service_providers.sections.status'))
                    ->schema([
                        Forms\Components\Toggle::make('user.is_active')
                            ->label(__('service_providers.fields.is_active'))
                            ->default(true)
                            ->inline(false),
                    ])
                    ->columnSpanFull(),
            ]);
    }

    public static function infolist(Schema $infolist): Schema
    {
        return $infolist
            ->components([
                Section::make(__('service_providers.sections.personal_info'))
                    ->schema([
                        Infolists\Components\TextEntry::make('user.name')
                            ->label(__('service_providers.fields.name')),

                        Infolists\Components\TextEntry::make('user.email')
                            ->label(__('service_providers.fields.email'))
                            ->copyable(),

                        Infolists\Components\TextEntry::make('user.phone')
                            ->label(__('service_providers.fields.phone'))
                            ->default('-'),

                        Infolists\Components\IconEntry::make('user.is_active')
                            ->label(__('service_providers.fields.is_active'))
                            ->boolean(),
                    ])
                    ->columns(2),

                Section::make(__('service_providers.sections.work_info'))
                    ->schema([
                        Infolists\Components\TextEntry::make('categories')
                            ->label(__('service_providers.fields.categories'))
                            ->formatStateUsing(fn (ServiceProvider $record): string => $record->categories->pluck('name')->join(', ') ?: '-')
                            ->badge()
                            ->color('info')
                            ->columnSpanFull(),

                        Infolists\Components\IconEntry::make('is_available')
                            ->label(__('service_providers.fields.is_available'))
                            ->boolean(),

                        Infolists\Components\TextEntry::make('assignments_count')
                            ->label(__('service_providers.fields.assignments_count'))
                            ->state(fn (ServiceProvider $record): int => $record->assignments()->count())
                            ->badge()
                            ->color('primary'),
                    ])
                    ->columns(2),

                Section::make(__('service_providers.sections.time_slots'))
                    ->schema([
                        Infolists\Components\ViewEntry::make('timeSlots')
                            ->label('')
                            ->view('filament.components.time-slots-schedule', fn (ServiceProvider $record) => [
                                'timeSlots' => $record->timeSlots->toArray(),
                            ])
                            ->columnSpanFull(),
                    ])
                    ->collapsible(),

                Section::make(__('service_providers.sections.location'))
                    ->schema([
                        Infolists\Components\TextEntry::make('latitude')
                            ->label(__('service_providers.fields.latitude'))
                            ->default('-'),

                        Infolists\Components\TextEntry::make('longitude')
                            ->label(__('service_providers.fields.longitude'))
                            ->default('-'),
                    ])
                    ->columns(2)
                    ->collapsed(),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('user.name')
                    ->label(__('service_providers.fields.name'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.email')
                    ->label(__('service_providers.fields.email'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->copyMessage(__('common.copied')),

                Tables\Columns\TextColumn::make('user.phone')
                    ->label(__('service_providers.fields.phone'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('categories.name_en')
                    ->label(__('service_providers.fields.categories'))
                    ->formatStateUsing(fn ($record) => $record->categories->pluck('name')->implode(', ')
                    )
                    ->badge()
                    ->separator(',')
                    ->limitList(2)
                    ->sortable(),

                Tables\Columns\IconColumn::make('is_available')
                    ->label(__('service_providers.fields.is_available'))
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('danger')
                    ->sortable(),

                Tables\Columns\TextColumn::make('assignments_count')
                    ->label(__('service_providers.fields.assignments_count'))
                    ->counts('assignments')
                    ->sortable()
                    ->badge()
                    ->color('primary'),

                Tables\Columns\IconColumn::make('user.is_active')
                    ->label(__('service_providers.fields.is_active'))
                    ->boolean()
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('categories')
                    ->label(__('service_providers.filters.category'))
                    ->relationship('categories', 'name_en')
                    ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                    ->multiple()
                    ->searchable()
                    ->preload(),

                Tables\Filters\TernaryFilter::make('is_available')
                    ->label(__('service_providers.filters.available')),

                Tables\Filters\TernaryFilter::make('user.is_active')
                    ->label(__('service_providers.filters.active'))
                    ->queries(
                        true: fn (Builder $query) => $query->whereHas('user', fn ($q) => $q->where('is_active', true)),
                        false: fn (Builder $query) => $query->whereHas('user', fn ($q) => $q->where('is_active', false)),
                    ),
            ])
            ->actions([
                ViewAction::make()
                    ->visible(fn ($record) => auth()->user()->can('view', $record)),
                EditAction::make()
                    ->visible(fn ($record) => auth()->user()->can('update', $record)),

                Action::make('reset_password')
                    ->authorize('resetPassword')
                    ->icon('heroicon-o-key')
                    ->color('warning')
                    ->iconButton()
                    ->tooltip(__('service_providers.actions.reset_password'))
                    ->requiresConfirmation()
                    ->modalHeading(__('service_providers.actions.reset_password'))
                    ->modalDescription(__('service_providers.actions.reset_password_confirmation'))
                    ->form([
                        Forms\Components\TextInput::make('new_password')
                            ->label(__('service_providers.fields.new_password'))
                            ->password()
                            ->revealable()
                            ->required()
                            ->minLength(8)
                            ->confirmed(),

                        Forms\Components\TextInput::make('new_password_confirmation')
                            ->label(__('service_providers.fields.confirm_password'))
                            ->password()
                            ->revealable()
                            ->required(),
                    ])
                    ->action(function (ServiceProvider $record, array $data): void {
                        $record->user->update([
                            'password' => Hash::make($data['new_password']),
                        ]);
                    }),

                Action::make('toggle_availability')
                    ->authorize('toggleAvailability')
                    ->icon(fn (ServiceProvider $record) => $record->is_available
                        ? 'heroicon-o-x-circle'
                        : 'heroicon-o-check-circle')
                    ->color(fn (ServiceProvider $record) => $record->is_available ? 'danger' : 'success')
                    ->iconButton()
                    ->tooltip(fn (ServiceProvider $record) => $record->is_available
                        ? __('service_providers.actions.mark_unavailable')
                        : __('service_providers.actions.mark_available'))
                    ->requiresConfirmation()
                    ->action(fn (ServiceProvider $record) => $record->update([
                        'is_available' => ! $record->is_available,
                    ])),

                DeleteAction::make()
                    ->visible(fn ($record) => auth()->user()->can('delete', $record))
                    ->modalDescription(function (ServiceProvider $record): string {
                        $assignmentsCount = $record->assignments()->count();
                        if ($assignmentsCount > 0) {
                            return __('service_providers.actions.delete_with_assignments', ['count' => $assignmentsCount]);
                        }

                        return __('filament-actions::delete.single.modal.description');
                    }),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make()
                        ->modalDescription(__('service_providers.actions.bulk_delete_warning')),

                    BulkAction::make('mark_available')
                        ->label(__('service_providers.actions.mark_available'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(function ($records): void {
                            if (! auth()->user()->can('Update:ServiceProvider')) {
                                Notification::make()
                                    ->danger()
                                    ->title(__('filament-actions::delete.multiple.messages.unauthorized'))
                                    ->send();

                                return;
                            }

                            $records->each(fn (ServiceProvider $record) => $record->update(['is_available' => true]));
                        }),

                    BulkAction::make('mark_unavailable')
                        ->label(__('service_providers.actions.mark_unavailable'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->action(function ($records): void {
                            if (! auth()->user()->can('Update:ServiceProvider')) {
                                Notification::make()
                                    ->danger()
                                    ->title(__('filament-actions::delete.multiple.messages.unauthorized'))
                                    ->send();

                                return;
                            }

                            $records->each(fn (ServiceProvider $record) => $record->update(['is_available' => false]));
                        }),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListServiceProviders::route('/'),
            'create' => Pages\CreateServiceProvider::route('/create'),
            'view' => Pages\ViewServiceProvider::route('/{record}'),
            'edit' => Pages\EditServiceProvider::route('/{record}/edit'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with(['user', 'categories']);
    }
}
