<?php

namespace App\Filament\Resources;

use App\Actions\Issue\ApproveIssueAction;
use App\Enums\AssignmentStatus;
use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Filament\Resources\IssueResource\Pages;
use App\Filament\Resources\IssueResource\RelationManagers;
use App\Models\Category;
use App\Models\Issue;
use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use App\Models\WorkType;
use BackedEnum;
use Carbon\Carbon;
use Cheesegrits\FilamentGoogleMaps\Fields\Geocomplete;
use Cheesegrits\FilamentGoogleMaps\Fields\Map;
use Cheesegrits\FilamentGoogleMaps\Infolists\MapEntry;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms;
use Filament\Forms\Components\ViewField;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class IssueResource extends Resource
{
    protected static ?string $model = Issue::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-clipboard-document-list';

    protected static ?int $navigationSort = 1;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.issues');
    }

    public static function getModelLabel(): string
    {
        return __('issues.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('issues.plural');
    }

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::where('status', IssueStatus::PENDING)->count() ?: null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('issues.sections.basic_info'))
                    ->schema([
                        Forms\Components\TextInput::make('title')
                            ->label(__('issues.fields.title'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\Textarea::make('description')
                            ->label(__('issues.fields.description'))
                            ->rows(4)
                            ->maxLength(2000),

                        Forms\Components\Select::make('tenant_id')
                            ->label(__('issues.fields.tenant'))
                            ->relationship('tenant', 'id')
                            ->getOptionLabelFromRecordUsing(fn ($record) => $record->user->name.' - '.$record->full_address)
                            ->searchable()
                            ->preload()
                            ->required(),

                        Forms\Components\Select::make('categories')
                            ->label(__('issues.fields.categories'))
                            ->relationship('categories', 'name_en')
                            ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                            ->multiple()
                            ->searchable()
                            ->preload(),
                    ])
                    ->columns(2),

                Section::make(__('issues.sections.priority_status'))
                    ->schema([
                        Forms\Components\Select::make('priority')
                            ->label(__('issues.fields.priority'))
                            ->options(IssuePriority::options())
                            ->default(IssuePriority::MEDIUM->value)
                            ->required()
                            ->native(false),

                        Forms\Components\Select::make('status')
                            ->label(__('issues.fields.status'))
                            ->options(IssueStatus::options())
                            ->default(IssueStatus::PENDING->value)
                            ->required()
                            ->native(false)
                            ->visibleOn('edit'),

                        Forms\Components\Toggle::make('proof_required')
                            ->label(__('issues.fields.proof_required'))
                            ->default(true)
                            ->inline(false),
                    ])
                    ->columns(3),

                Section::make(__('issues.sections.location'))
                    ->schema([
                        Geocomplete::make('address')
                            ->label(__('issues.fields.address'))
                            ->placeholder(__('issues.search_location'))
                            ->countries(['SA', 'AE'])
                            ->columnSpanFull(),

                        Map::make('location')
                            ->label(__('issues.fields.location_picker'))
                            ->defaultZoom(12)
                            ->defaultLocation([25.2048, 55.2708])
                            ->autocomplete('address')
                            ->autocompleteReverse(true)
                            ->reverseGeocode([
                                'address' => '%n %S, %L, %A1, %C',
                            ])
                            ->draggable()
                            ->clickable()
                            // ->geolocate()  // Temporarily disabled
                            // ->geolocateLabel(__('issues.use_my_location'))
                            ->height('400px')
                            ->columnSpanFull(),
                    ])
                    ->collapsed(),

                Section::make(__('issues.sections.media'))
                    ->schema([
                        // Read-only media preview on view + edit
                        ViewField::make('media_preview')
                            ->view('filament.components.media-preview')
                            ->viewData(fn ($record) => [
                                'media' => $record?->media ?? [],
                            ])
                            ->label('')
                            ->columnSpanFull()
                            ->visibleOn(['view', 'edit']),

                        // Upload new media on create + edit
                        Forms\Components\FileUpload::make('media_uploads')
                            ->label(__('issues.fields.media_uploads'))
                            ->multiple()
                            ->disk('public')
                            ->directory('issue-media-temp')
                            ->visibility('public')
                            ->maxFiles(10)
                            ->acceptedFileTypes(['image/jpeg', 'image/png', 'video/mp4', 'audio/mpeg', 'application/pdf'])
                            ->maxSize(102400)
                            ->dehydrated(false)
                            ->columnSpanFull()
                            ->visibleOn(['create', 'edit']),
                    ])
                    ->collapsed(fn ($context) => $context !== 'create'),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label(__('issues.fields.id'))
                    ->sortable()
                    ->searchable()
                    ->prefix('#'),

                Tables\Columns\TextColumn::make('title')
                    ->label(__('issues.fields.title'))
                    ->searchable()
                    ->sortable()
                    ->limit(40)
                    ->tooltip(fn ($record) => $record->title),

                Tables\Columns\TextColumn::make('tenant.user.name')
                    ->label(__('issues.fields.tenant'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->label(__('issues.fields.status'))
                    ->badge()
                    ->formatStateUsing(fn (IssueStatus $state): string => $state->label())
                    ->color(fn (IssueStatus $state): string => $state->color())
                    ->icon(fn (IssueStatus $state): string => $state->icon())
                    ->sortable(),

                Tables\Columns\TextColumn::make('priority')
                    ->label(__('issues.fields.priority'))
                    ->badge()
                    ->formatStateUsing(fn (IssuePriority $state): string => $state->label())
                    ->color(fn (IssuePriority $state): string => $state->color())
                    ->icon(fn (IssuePriority $state): string => $state->icon())
                    ->sortable(),

                Tables\Columns\TextColumn::make('categories.name_en')
                    ->label(__('issues.fields.categories'))
                    ->badge()
                    ->color('info')
                    ->separator(',')
                    ->limitList(2)
                    ->expandableLimitedList(),

                Tables\Columns\TextColumn::make('assignments.serviceProvider.user.name')
                    ->label(__('issues.fields.assigned_to'))
                    ->default(__('issues.not_assigned'))
                    ->color(fn ($state) => $state === __('issues.not_assigned') ? 'gray' : 'success')
                    ->badge(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label(__('issues.filters.status'))
                    ->options(IssueStatus::options())
                    ->multiple(),

                Tables\Filters\SelectFilter::make('priority')
                    ->label(__('issues.filters.priority'))
                    ->options(IssuePriority::options())
                    ->multiple(),

                Tables\Filters\SelectFilter::make('categories')
                    ->label(__('issues.filters.category'))
                    ->relationship('categories', 'name_en')
                    ->getOptionLabelFromRecordUsing(fn (Category $record) => $record->name)
                    ->searchable()
                    ->preload()
                    ->multiple(),

                Tables\Filters\Filter::make('created_at')
                    ->label(__('issues.filters.date_range'))
                    ->form([
                        Forms\Components\DatePicker::make('from')
                            ->label(__('issues.filters.from')),
                        Forms\Components\DatePicker::make('until')
                            ->label(__('issues.filters.until')),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        return $query
                            ->when(
                                $data['from'],
                                fn (Builder $query, $date): Builder => $query->whereDate('created_at', '>=', $date),
                            )
                            ->when(
                                $data['until'],
                                fn (Builder $query, $date): Builder => $query->whereDate('created_at', '<=', $date),
                            );
                    })
                    ->indicateUsing(function (array $data): array {
                        $indicators = [];

                        if ($data['from'] ?? null) {
                            $indicators['from'] = __('issues.filters.from').': '.$data['from'];
                        }

                        if ($data['until'] ?? null) {
                            $indicators['until'] = __('issues.filters.until').': '.$data['until'];
                        }

                        return $indicators;
                    }),

                Tables\Filters\TernaryFilter::make('has_assignment')
                    ->label(__('issues.filters.has_assignment'))
                    ->queries(
                        true: fn (Builder $query) => $query->has('assignments'),
                        false: fn (Builder $query) => $query->doesntHave('assignments'),
                    ),
            ])
            ->actions([
                ViewAction::make(),

                Action::make('assign')
                    ->label(__('issues.actions.assign'))
                    ->icon('heroicon-o-user-plus')
                    ->color('primary')
                    ->authorize('assign')
                    ->visible(fn (Issue $record) => $record->canBeAssigned())
                    ->slideOver()
                    ->modalWidth('2xl')
                    ->form([
                        Forms\Components\Select::make('category_id')
                            ->label(__('issues.fields.category'))
                            ->options(fn () => \Illuminate\Support\Facades\Cache::remember(
                                'categories_active_list',
                                now()->addHour(),
                                fn () => Category::active()->pluck('name_en', 'id')
                            ))
                            ->searchable()
                            ->required()
                            ->live(onBlur: true)
                            ->afterStateUpdated(function (Set $set) {
                                $set('work_type_id', null);
                                $set('service_provider_id', null);
                                $set('time_slot_ids', []);
                            }),

                        Forms\Components\Select::make('work_type_id')
                            ->label(__('issues.fields.work_type'))
                            ->options(function (Get $get) {
                                $categoryId = $get('category_id');
                                if (! $categoryId) {
                                    return [];
                                }

                                return \Illuminate\Support\Facades\Cache::remember(
                                    "work_types_category_{$categoryId}",
                                    now()->addMinutes(30),
                                    fn () => WorkType::active()
                                        ->forCategory($categoryId)
                                        ->get()
                                        ->mapWithKeys(fn ($wt) => [
                                            $wt->id => "{$wt->name_en} ({$wt->formatted_duration})",
                                        ])
                                );
                            })
                            ->searchable()
                            ->live(onBlur: true)
                            ->afterStateUpdated(function (Get $get, Set $set, $state) {
                                if ($state) {
                                    $workType = WorkType::find($state);
                                    $minutes = $workType?->duration_minutes;
                                    $set('allocated_duration_minutes', $minutes);

                                    // Update display value based on current unit
                                    $unit = $get('duration_unit') ?? 'minutes';
                                    if ($unit === 'hours' && $minutes) {
                                        $set('duration_display_value', round($minutes / 60, 1));
                                    } else {
                                        $set('duration_display_value', $minutes);
                                    }

                                    $set('is_custom_duration', false);
                                }
                            })
                            ->helperText(__('issues.work_type_helper')),

                        Forms\Components\TextInput::make('duration_display_value')
                            ->label(__('issues.fields.allocated_duration'))
                            ->numeric()
                            ->minValue(1)
                            ->live(onBlur: true)
                            ->afterStateUpdated(function (Get $get, Set $set, $state) {
                                if (! $state) {
                                    return;
                                }

                                // Convert to minutes based on current unit
                                $unit = $get('duration_unit') ?? 'minutes';
                                $minutes = $unit === 'hours' ? ((float) $state * 60) : (int) $state;

                                // Ensure minimum duration
                                if ($minutes < 15) {
                                    $minutes = 15;
                                }

                                $set('allocated_duration_minutes', (int) $minutes);

                                // Auto-select slots after duration changes
                                static::autoSelectSlotsForDuration($get, $set);

                                // Recalculate end time if manual start time is set
                                $startTime = $get('assigned_start_time');
                                if ($startTime) {
                                    $endTime = \Carbon\Carbon::parse($startTime)->addMinutes($minutes);
                                    $set('assigned_end_time', $endTime->format('H:i'));
                                }
                            })
                            ->suffix(fn (Get $get) => $get('duration_unit') === 'hours' ? __('issues.fields.hours_short') : __('issues.fields.minutes_short'))
                            ->helperText(__('issues.duration_override_helper'))
                            ->dehydrated(false)
                            ->disabled(fn (Get $get) => ! $get('is_custom_duration'))
                            ->visible(fn () => auth()->user()->can('override_work_type_duration')),

                        Forms\Components\ToggleButtons::make('duration_unit')
                            ->label(__('issues.fields.duration_unit'))
                            ->options([
                                'minutes' => __('issues.fields.minutes_short'),
                                'hours' => __('issues.fields.hours_short'),
                            ])
                            ->default('minutes')
                            ->inline()
                            ->live()
                            ->afterStateUpdated(function (Get $get, Set $set, $state) {
                                $currentMinutes = $get('allocated_duration_minutes');
                                if (! $currentMinutes) {
                                    return;
                                }

                                // Update display value when unit changes
                                if ($state === 'hours') {
                                    $set('duration_display_value', round($currentMinutes / 60, 1));
                                } else {
                                    $set('duration_display_value', $currentMinutes);
                                }

                                // Recalculate end time if manual start time is set
                                $startTime = $get('assigned_start_time');
                                if ($startTime) {
                                    $endTime = \Carbon\Carbon::parse($startTime)->addMinutes($currentMinutes);
                                    $set('assigned_end_time', $endTime->format('H:i'));
                                }
                            })
                            ->dehydrated(false)
                            ->disabled(fn (Get $get) => ! $get('is_custom_duration'))
                            ->visible(fn () => auth()->user()->can('override_work_type_duration')),

                        Forms\Components\Hidden::make('allocated_duration_minutes')
                            ->default(60)
                            ->required(),

                        Forms\Components\Checkbox::make('is_custom_duration')
                            ->label(__('issues.fields.use_custom_duration'))
                            ->live()
                            ->afterStateUpdated(function (Set $set, Get $get, $state) {
                                if ($state) {
                                    // Checked: clear work type
                                    $set('work_type_id', null);
                                } else {
                                    // Unchecked: recalculate duration from selected slots
                                    $timeSlotIds = $get('time_slot_ids');
                                    if (! empty($timeSlotIds)) {
                                        $slots = \App\Models\TimeSlot::whereIn('id', $timeSlotIds)->get();
                                        $totalMinutes = $slots->sum(function ($slot) {
                                            return \Carbon\Carbon::parse($slot->start_time)
                                                ->diffInMinutes(\Carbon\Carbon::parse($slot->end_time));
                                        });

                                        $set('allocated_duration_minutes', (int) $totalMinutes);

                                        // Update display value based on current unit
                                        $unit = $get('duration_unit') ?? 'minutes';
                                        if ($unit === 'hours') {
                                            $set('duration_display_value', round($totalMinutes / 60, 1));
                                        } else {
                                            $set('duration_display_value', $totalMinutes);
                                        }
                                    }
                                }
                            })
                            ->visible(fn () => auth()->user()->can('override_work_type_duration')),

                        Forms\Components\Select::make('service_provider_id')
                            ->label(__('issues.fields.service_provider'))
                            ->options(function (Get $get) {
                                $categoryId = $get('category_id');
                                if (! $categoryId) {
                                    return [];
                                }

                                return \Illuminate\Support\Facades\Cache::remember(
                                    "service_providers_category_{$categoryId}",
                                    now()->addMinutes(15),
                                    fn () => ServiceProvider::available()
                                        ->forCategoryWithAncestors($categoryId)
                                        ->with('user')
                                        ->get()
                                        ->pluck('user.name', 'id')
                                );
                            })
                            ->searchable()
                            ->required()
                            ->live(onBlur: true)
                            ->afterStateUpdated(function (Set $set, Get $get) {
                                $set('time_slot_ids', []);
                                // Re-run auto-selection if duration exists
                                $duration = $get('allocated_duration_minutes');
                                if ($duration) {
                                    static::autoSelectSlotsForDuration($get, $set);
                                }
                            }),

                        ViewField::make('availability_info')
                            ->label(__('issues.fields.availability_info'))
                            ->view('filament.components.availability-info')
                            ->viewData(function (Get $get) {
                                $spId = $get('service_provider_id');
                                $scheduledDate = $get('scheduled_date');
                                $allocatedDuration = $get('allocated_duration_minutes');

                                return [
                                    'serviceProvider' => $spId ? ServiceProvider::with('timeSlots')->find($spId) : null,
                                    'selectedDate' => $scheduledDate ? Carbon::parse($scheduledDate) : null,
                                    'allocatedDuration' => $allocatedDuration,
                                ];
                            })
                            ->visible(fn (Get $get) => filled($get('service_provider_id'))),

                        Forms\Components\DatePicker::make('scheduled_date')
                            ->label(__('issues.fields.scheduled_date'))
                            ->required()
                            ->minDate(now())
                            ->live(onBlur: true)
                            ->afterStateUpdated(function (Set $set, Get $get) {
                                $set('time_slot_ids', []);
                                // Re-run auto-selection if duration exists
                                $duration = $get('allocated_duration_minutes');
                                if ($duration) {
                                    static::autoSelectSlotsForDuration($get, $set);
                                }
                            }),

                        Forms\Components\CheckboxList::make('time_slot_ids')
                            ->label(__('issues.fields.time_slots'))
                            ->options(function (Get $get) {
                                $spId = $get('service_provider_id');
                                $scheduledDate = $get('scheduled_date');
                                $selectedSlotIds = $get('time_slot_ids') ?? [];

                                if (! $spId || ! $scheduledDate) {
                                    return [];
                                }

                                $date = Carbon::parse($scheduledDate);

                                // If slots are selected, get their days to show all relevant slots
                                $daysToShow = collect([$date->dayOfWeek]);

                                if (! empty($selectedSlotIds)) {
                                    $selectedSlots = TimeSlot::whereIn('id', $selectedSlotIds)->get();
                                    $selectedDays = $selectedSlots->pluck('day_of_week')->unique();
                                    $daysToShow = $daysToShow->merge($selectedDays)->unique();
                                }

                                // Build options with day labels and capacity info for multi-day scenarios
                                $options = [];
                                $currentDate = $date->copy();
                                $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);

                                foreach ($daysToShow->sort() as $dayOfWeek) {
                                    // Find the next occurrence of this day of week from scheduled date
                                    $targetDate = $currentDate->copy();
                                    while ($targetDate->dayOfWeek !== $dayOfWeek) {
                                        $targetDate->addDay();
                                    }

                                    $slots = TimeSlot::where('service_provider_id', $spId)
                                        ->where('day_of_week', $dayOfWeek)
                                        ->active()
                                        ->orderBy('start_time')
                                        ->get()
                                        ->filter(fn ($slot) => $slot->isAvailableOn($targetDate)); // Only available

                                    foreach ($slots as $slot) {
                                        $label = $slot->display_name;

                                        // Get capacity info
                                        $capacity = $availabilityService->getSlotCapacity($slot, $targetDate);

                                        // Add capacity indicator if slot is partially occupied
                                        if ($capacity['available_minutes'] < $capacity['total_minutes']) {
                                            $available = $capacity['available_minutes'];
                                            $total = $capacity['total_minutes'];
                                            $label .= " ({$available}/{$total} min)";
                                        }

                                        // Add day prefix for multi-day scenarios
                                        if ($daysToShow->count() > 1) {
                                            $dayName = $targetDate->translatedFormat('D'); // Short day name (Mon, Tue, etc.)
                                            $label = "{$dayName}: {$label}";
                                        }

                                        $options[$slot->id] = $label;
                                    }
                                }

                                return $options;
                            })
                            ->required()
                            ->columns(2)
                            ->helperText(function (Get $get) {
                                $scheduledDate = $get('scheduled_date');
                                $selectedSlotIds = $get('time_slot_ids') ?? [];

                                if (! $scheduledDate) {
                                    return __('issues.availability.select_date_first');
                                }

                                $date = Carbon::parse($scheduledDate);

                                // Check if multi-day
                                if (! empty($selectedSlotIds)) {
                                    $selectedSlots = TimeSlot::whereIn('id', $selectedSlotIds)->get();
                                    $uniqueDays = $selectedSlots->pluck('day_of_week')->unique();

                                    if ($uniqueDays->count() > 1) {
                                        $totalMinutes = $selectedSlots->sum(function ($slot) {
                                            return Carbon::parse($slot->start_time)
                                                ->diffInMinutes(Carbon::parse($slot->end_time));
                                        });

                                        $hours = floor($totalMinutes / 60);
                                        $minutes = $totalMinutes % 60;
                                        $durationText = $hours > 0 ? "{$hours}h {$minutes}m" : "{$minutes}m";

                                        return __('issues.validation.multi_day_assignment').": {$uniqueDays->count()} days, {$durationText} total. ".
                                            __('issues.fields.time_slots_helper');
                                    }
                                }

                                return __('issues.availability.slots_for_day', ['day' => $date->translatedFormat('l')]).'. '.
                                    __('issues.fields.time_slots_helper');
                            })
                            ->live(debounce: 300)
                            ->afterStateUpdated(function ($state, Set $set, Get $get) {
                                if (empty($state)) {
                                    return;
                                }

                                $spId = $get('service_provider_id');
                                $scheduledDate = $get('scheduled_date');

                                // Calculate total slot duration
                                $slots = TimeSlot::whereIn('id', $state)->get();
                                $totalSlotMinutes = $slots->sum(function ($slot) {
                                    return Carbon::parse($slot->start_time)
                                        ->diffInMinutes(Carbon::parse($slot->end_time));
                                });

                                // VALIDATION 1: Check against allocated duration
                                $allocatedDuration = $get('allocated_duration_minutes');
                                if ($allocatedDuration && $totalSlotMinutes < $allocatedDuration) {
                                    \Filament\Notifications\Notification::make()
                                        ->danger()
                                        ->title(__('issues.validation.insufficient_slot_capacity'))
                                        ->body(__('issues.validation.slots_cannot_accommodate_duration', [
                                            'slot_minutes' => $totalSlotMinutes,
                                            'required_minutes' => $allocatedDuration,
                                        ]))
                                        ->persistent()
                                        ->send();
                                }

                                // VALIDATION 2: Check for overlaps with existing assignments
                                if ($spId && $scheduledDate) {
                                    $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
                                    $date = Carbon::parse($scheduledDate);

                                    if ($availabilityService->hasMultiSlotOverlap($spId, $date, $state)) {
                                        \Filament\Notifications\Notification::make()
                                            ->danger()
                                            ->title(__('issues.validation.slot_overlap'))
                                            ->body(__('issues.time_slots_overlap_with_existing_assignment'))
                                            ->persistent()
                                            ->send();
                                    }
                                }

                                // Update allocated duration to match slots if not custom
                                if (! $get('is_custom_duration')) {
                                    $set('allocated_duration_minutes', (int) $totalSlotMinutes);

                                    // Update display value based on current unit
                                    $unit = $get('duration_unit') ?? 'minutes';
                                    if ($unit === 'hours') {
                                        $set('duration_display_value', round($totalSlotMinutes / 60, 1));
                                    } else {
                                        $set('duration_display_value', $totalSlotMinutes);
                                    }
                                }
                            }),

                        // Optional manual time range override
                        Section::make('Time Range Override')
                            ->description('Leave empty to auto-calculate from selected time slots')
                            ->schema([
                                Forms\Components\Checkbox::make('use_manual_time_override')
                                    ->label('Use manual time override')
                                    ->live()
                                    ->afterStateUpdated(function (Set $set, $state) {
                                        if (! $state) {
                                            $set('assigned_start_time', null);
                                            $set('assigned_end_time', null);
                                        }
                                    })
                                    ->dehydrated(false)
                                    ->visible(fn (Get $get) => auth()->user()->can('override_work_type_duration') &&
                                        filled($get('time_slot_ids'))
                                    ),

                                Forms\Components\TimePicker::make('assigned_start_time')
                                    ->label(__('issues.fields.assigned_start_time'))
                                    ->seconds(false)
                                    ->dehydrated(true)
                                    ->visible(fn (Get $get) => auth()->user()->can('override_work_type_duration') &&
                                        filled($get('time_slot_ids')) &&
                                        $get('use_manual_time_override')
                                    )
                                    ->live(onBlur: true)
                                    ->afterStateUpdated(function (Set $set, Get $get, $state) {
                                        if (! $state) {
                                            $set('assigned_end_time', null);

                                            return;
                                        }

                                        $duration = $get('allocated_duration_minutes');
                                        if ($duration) {
                                            $endTime = \Carbon\Carbon::parse($state)->addMinutes($duration);
                                            $set('assigned_end_time', $endTime->format('H:i'));
                                        }
                                    })
                                    ->rules([
                                        fn (Get $get): \Closure => function (string $attribute, $value, \Closure $fail) use ($get) {
                                            if (! $value || ! $get('assigned_end_time')) {
                                                return;
                                            }

                                            $timeSlotIds = $get('time_slot_ids');
                                            $scheduledDate = $get('scheduled_date');
                                            $serviceProviderId = $get('service_provider_id');

                                            if (empty($timeSlotIds) || ! $scheduledDate || ! $serviceProviderId) {
                                                return;
                                            }

                                            // Get earliest start and latest end across all selected slots
                                            $slots = TimeSlot::whereIn('id', $timeSlotIds)->get();
                                            $earliestStart = $slots->min('start_time');
                                            $latestEnd = $slots->max('end_time');
                                            $slotStart = \Carbon\Carbon::parse($earliestStart);
                                            $slotEnd = \Carbon\Carbon::parse($latestEnd);
                                            $manualStart = \Carbon\Carbon::parse($value.':00');
                                            $manualEnd = \Carbon\Carbon::parse($get('assigned_end_time').':00');

                                            // Check if time is within combined slot bounds
                                            if ($manualStart->lt($slotStart) || $manualEnd->gt($slotEnd)) {
                                                $fail(__('issues.assigned_time_outside_slots', [
                                                    'start' => substr($earliestStart, 0, 5),
                                                    'end' => substr($latestEnd, 0, 5),
                                                ]));

                                                return;
                                            }

                                            // Check for overlaps
                                            $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
                                            $scheduledDateCarbon = \Carbon\Carbon::parse($scheduledDate);

                                            if ($availabilityService->hasMultiSlotOverlap(
                                                $serviceProviderId,
                                                $scheduledDateCarbon,
                                                $timeSlotIds
                                            )) {
                                                $fail(__('issues.time_slots_overlap_with_existing_assignment'));
                                            }
                                        },
                                    ]),

                                Forms\Components\TimePicker::make('assigned_end_time')
                                    ->label(__('issues.fields.assigned_end_time'))
                                    ->seconds(false)
                                    ->disabled()
                                    ->dehydrated()
                                    ->helperText('Auto-calculated from start time + duration')
                                    ->visible(fn (Get $get) => auth()->user()->can('override_work_type_duration') &&
                                        filled($get('time_slot_ids')) &&
                                        $get('use_manual_time_override')
                                    )
                                    ->live(onBlur: true)
                                    ->rules([
                                        fn (Get $get): \Closure => function (string $attribute, $value, \Closure $fail) use ($get) {
                                            if (! $value || ! $get('assigned_start_time')) {
                                                return;
                                            }

                                            $timeSlotIds = $get('time_slot_ids');
                                            $scheduledDate = $get('scheduled_date');
                                            $serviceProviderId = $get('service_provider_id');

                                            if (empty($timeSlotIds) || ! $scheduledDate || ! $serviceProviderId) {
                                                return;
                                            }

                                            // Get earliest start and latest end across all selected slots
                                            $slots = TimeSlot::whereIn('id', $timeSlotIds)->get();
                                            $earliestStart = $slots->min('start_time');
                                            $latestEnd = $slots->max('end_time');
                                            $slotStart = \Carbon\Carbon::parse($earliestStart);
                                            $slotEnd = \Carbon\Carbon::parse($latestEnd);
                                            $manualStart = \Carbon\Carbon::parse($get('assigned_start_time').':00');
                                            $manualEnd = \Carbon\Carbon::parse($value.':00');

                                            // Check if time is within combined slot bounds
                                            if ($manualStart->lt($slotStart) || $manualEnd->gt($slotEnd)) {
                                                $fail(__('issues.assigned_time_outside_slots', [
                                                    'start' => substr($earliestStart, 0, 5),
                                                    'end' => substr($latestEnd, 0, 5),
                                                ]));

                                                return;
                                            }

                                            // Check for overlaps
                                            $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
                                            $scheduledDateCarbon = \Carbon\Carbon::parse($scheduledDate);

                                            if ($availabilityService->hasMultiSlotOverlap(
                                                $serviceProviderId,
                                                $scheduledDateCarbon,
                                                $timeSlotIds
                                            )) {
                                                $fail(__('issues.time_slots_overlap_with_existing_assignment'));
                                            }
                                        },
                                    ]),
                            ])
                            ->columns(2)
                            ->visible(fn (Get $get) => auth()->user()->can('override_work_type_duration') && filled($get('time_slot_ids'))),

                        Forms\Components\Placeholder::make('time_range_info')
                            ->label('Assigned Time')
                            ->content(function (Get $get) {
                                $startTime = $get('assigned_start_time');
                                $endTime = $get('assigned_end_time');

                                if ($startTime && $endTime) {
                                    return "Manual: {$startTime} - {$endTime}";
                                }

                                $timeSlotIds = $get('time_slot_ids');
                                if (! empty($timeSlotIds) && is_array($timeSlotIds)) {
                                    $count = count($timeSlotIds);
                                    $slots = TimeSlot::whereIn('id', $timeSlotIds)->orderBy('start_time')->get();

                                    if ($slots->isEmpty()) {
                                        return "Selected {$count} slot".($count > 1 ? 's' : '').' - calculating time range...';
                                    }

                                    $first = $slots->first();
                                    $last = $slots->last();

                                    if ($first && $last && $first->start_time && $last->end_time) {
                                        $start = Carbon::parse($first->start_time)->format('H:i');
                                        $end = Carbon::parse($last->end_time)->format('H:i');

                                        return "Auto: Will use combined range {$start} - {$end} ({$count} slot".($count > 1 ? 's' : '').')';
                                    }

                                    return "Selected {$count} slot".($count > 1 ? 's' : '');
                                }

                                return 'Select time slots to see assigned time';
                            })
                            ->visible(fn (Get $get) => filled($get('time_slot_ids')) || (filled($get('assigned_start_time')) && filled($get('assigned_end_time')))),

                        Forms\Components\Textarea::make('notes')
                            ->label(__('issues.fields.notes'))
                            ->rows(3),
                    ])
                    ->action(function (Issue $record, array $data): void {
                        // Determine work type and duration
                        $workTypeId = $data['work_type_id'] ?? null;
                        $allocatedDuration = $data['allocated_duration_minutes'] ?? null;
                        $isCustomDuration = $data['is_custom_duration'] ?? false;

                        // If work type selected but no duration override
                        if ($workTypeId && ! $allocatedDuration) {
                            $workType = WorkType::find($workTypeId);
                            $allocatedDuration = $workType?->duration_minutes;
                        }

                        // Get time slots and validate
                        $timeSlotIds = $data['time_slot_ids'];
                        $timeSlots = TimeSlot::whereIn('id', $timeSlotIds)->orderBy('start_time')->get();
                        $scheduledDate = Carbon::parse($data['scheduled_date']);
                        $serviceProviderId = $data['service_provider_id'];

                        // Use TimeSlotAvailabilityService for overlap checking
                        $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);

                        // Determine assigned time range
                        if (! empty($data['assigned_start_time']) && ! empty($data['assigned_end_time'])) {
                            // Manual override by admin (already validated by field rules)
                            $assignedStartTime = $data['assigned_start_time'].':00';
                            $assignedEndTime = $data['assigned_end_time'].':00';
                        } else {
                            // Auto-calculate: use the full combined range of all selected slots
                            $earliestStart = $timeSlots->min('start_time');
                            $latestEnd = $timeSlots->max('end_time');
                            $assignedStartTime = $earliestStart;
                            $assignedEndTime = $latestEnd;
                        }

                        // Check for overlaps
                        if ($availabilityService->hasMultiSlotOverlap($serviceProviderId, $scheduledDate, $timeSlotIds)) {
                            Notification::make()
                                ->danger()
                                ->title(__('issues.time_slots_overlap_with_existing_assignment'))
                                ->send();

                            return;
                        }

                        // Create assignment with time range
                        $record->assignments()->create([
                            'service_provider_id' => $serviceProviderId,
                            'category_id' => $data['category_id'],
                            'time_slot_ids' => $timeSlotIds,
                            'time_slot_id' => $timeSlotIds[0] ?? null, // Backward compat
                            'scheduled_date' => $data['scheduled_date'],
                            'assigned_start_time' => $assignedStartTime,
                            'assigned_end_time' => $assignedEndTime,
                            'work_type_id' => $workTypeId,
                            'allocated_duration_minutes' => $allocatedDuration,
                            'is_custom_duration' => $isCustomDuration,
                            'notes' => $data['notes'] ?? null,
                            'status' => 'assigned',
                            'proof_required' => $record->proof_required,
                        ]);

                        $record->update(['status' => IssueStatus::ASSIGNED]);

                        // Format notification body with date and time
                        $formattedDate = Carbon::parse($data['scheduled_date'])->format('M d, Y');
                        $formattedStart = $assignedStartTime ? substr($assignedStartTime, 0, 5) : 'N/A';
                        $formattedEnd = $assignedEndTime ? substr($assignedEndTime, 0, 5) : 'N/A';

                        Notification::make()
                            ->success()
                            ->title(__('issues.messages.assigned'))
                            ->body("Assigned: {$formattedDate} ({$formattedStart} - {$formattedEnd})")
                            ->send();
                    }),

                Action::make('approve')
                    ->label(__('issues.actions.approve'))
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->authorize('approve')
                    ->visible(fn (Issue $record) => $record->canBeApproved())
                    ->requiresConfirmation()
                    ->modalHeading(__('issues.actions.approve'))
                    ->modalDescription(function (Issue $record): string {
                        $pendingCount = $record->getPendingApprovalCount();
                        $totalCount = $record->getTotalAssignmentCount();

                        if ($pendingCount === $totalCount) {
                            return __('issues.actions.approve_confirmation');
                        }

                        return __('issues.actions.approve_confirmation_partial', [
                            'pending' => $pendingCount,
                            'total' => $totalCount,
                        ]);
                    })
                    ->action(function (Issue $record): void {
                        // Get all finished assignments and approve them
                        $finishedAssignments = $record->assignments()
                            ->where('status', AssignmentStatus::FINISHED)
                            ->get();

                        $approveAction = app(ApproveIssueAction::class);

                        foreach ($finishedAssignments as $assignment) {
                            $approveAction->execute($assignment, auth()->id());
                        }
                    }),

                Action::make('cancel')
                    ->label(__('issues.actions.cancel'))
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->authorize('cancel')
                    ->visible(fn (Issue $record) => $record->canBeCancelled())
                    ->requiresConfirmation()
                    ->modalHeading(__('issues.actions.cancel'))
                    ->modalDescription(__('issues.actions.cancel_confirmation'))
                    ->form([
                        Forms\Components\Textarea::make('cancelled_reason')
                            ->label(__('issues.fields.cancelled_reason'))
                            ->required()
                            ->rows(3),
                    ])
                    ->action(function (Issue $record, array $data): void {
                        $record->update([
                            'status' => IssueStatus::CANCELLED,
                            'cancelled_reason' => $data['cancelled_reason'],
                            'cancelled_by' => auth()->id(),
                            'cancelled_at' => now(),
                        ]);
                    }),

                EditAction::make()
                    ->visible(fn ($record) => auth()->user()->can('update', $record)),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),

                    BulkAction::make('bulk_cancel')
                        ->label(__('issues.actions.cancel'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->form([
                            Forms\Components\Textarea::make('cancelled_reason')
                                ->label(__('issues.fields.cancelled_reason'))
                                ->required()
                                ->rows(3),
                        ])
                        ->action(function ($records, array $data): void {
                            $records->each(function (Issue $record) use ($data): void {
                                if ($record->canBeCancelled()) {
                                    $record->update([
                                        'status' => IssueStatus::CANCELLED,
                                        'cancelled_reason' => $data['cancelled_reason'],
                                        'cancelled_by' => auth()->id(),
                                        'cancelled_at' => now(),
                                    ]);
                                }
                            });
                        }),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('issues.sections.basic_info'))
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('id')
                            ->label(__('issues.fields.id'))
                            ->prefix('#'),

                        \Filament\Infolists\Components\TextEntry::make('title')
                            ->label(__('issues.fields.title')),

                        \Filament\Infolists\Components\TextEntry::make('description')
                            ->label(__('issues.fields.description'))
                            ->columnSpanFull(),

                        \Filament\Infolists\Components\TextEntry::make('tenant.user.name')
                            ->label(__('issues.fields.tenant')),

                        \Filament\Infolists\Components\TextEntry::make('tenant.full_address')
                            ->label(__('issues.fields.address')),
                    ])
                    ->columns(2),

                Section::make(__('issues.sections.priority_status'))
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('status')
                            ->label(__('issues.fields.status'))
                            ->badge()
                            ->formatStateUsing(fn (IssueStatus $state): string => $state->label())
                            ->color(fn (IssueStatus $state): string => $state->color())
                            ->icon(fn (IssueStatus $state): string => $state->icon()),

                        \Filament\Infolists\Components\TextEntry::make('priority')
                            ->label(__('issues.fields.priority'))
                            ->badge()
                            ->formatStateUsing(fn (IssuePriority $state): string => $state->label())
                            ->color(fn (IssuePriority $state): string => $state->color())
                            ->icon(fn (IssuePriority $state): string => $state->icon()),

                        \Filament\Infolists\Components\TextEntry::make('categories.name_en')
                            ->label(__('issues.fields.categories'))
                            ->badge()
                            ->color('info')
                            ->separator(', '),

                        \Filament\Infolists\Components\IconEntry::make('proof_required')
                            ->label(__('issues.fields.proof_required'))
                            ->boolean(),
                    ])
                    ->columns(4),

                Section::make(__('issues.sections.location'))
                    ->schema([
                        MapEntry::make('location')
                            ->label(__('issues.fields.location_picker'))
                            ->height('300px')
                            ->defaultZoom(15)
                            ->columnSpanFull()
                            ->visible(false),

                        \Filament\Infolists\Components\TextEntry::make('address')
                            ->label(__('issues.fields.address'))
                            ->columnSpanFull()
                            ->visible(fn ($record) => filled($record->address)),

                        \Filament\Infolists\Components\TextEntry::make('directions_url')
                            ->label(__('issues.fields.directions'))
                            ->state(__('issues.fields.open_in_maps'))
                            ->url(fn ($record) => $record->getDirectionsUrl())
                            ->openUrlInNewTab()
                            ->color('primary')
                            ->icon('heroicon-o-map-pin')
                            ->visible(fn ($record) => $record->hasLocation()),
                    ])
                    ->columns(3)
                    ->collapsed(),

                Section::make(__('issues.sections.dates'))
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('created_at')
                            ->label(__('common.created_at'))
                            ->dateTime(),

                        \Filament\Infolists\Components\TextEntry::make('updated_at')
                            ->label(__('common.updated_at'))
                            ->dateTime(),

                        \Filament\Infolists\Components\TextEntry::make('cancelled_at')
                            ->label(__('issues.fields.cancelled_at'))
                            ->dateTime()
                            ->visible(fn ($record) => $record->status === IssueStatus::CANCELLED),

                        \Filament\Infolists\Components\TextEntry::make('cancelledByUser.name')
                            ->label(__('issues.fields.cancelled_by'))
                            ->visible(fn ($record) => $record->status === IssueStatus::CANCELLED),

                        \Filament\Infolists\Components\TextEntry::make('cancelled_reason')
                            ->label(__('issues.fields.cancelled_reason'))
                            ->visible(fn ($record) => $record->status === IssueStatus::CANCELLED)
                            ->columnSpanFull(),
                    ])
                    ->columns(2),

                Section::make(__('issues.sections.media'))
                    ->schema([
                        \Filament\Infolists\Components\ViewEntry::make('media')
                            ->view('filament.components.media-preview')
                            ->viewData(fn ($record) => [
                                'media' => $record->media ?? [],
                            ])
                            ->label('')
                            ->columnSpanFull(),
                    ])
                    ->visible(fn ($record) => $record->media->isNotEmpty())
                    ->collapsed(),

                Section::make(__('assignments.sections.proofs'))
                    ->schema([
                        \Filament\Infolists\Components\RepeatableEntry::make('assignments')
                            ->schema([
                                \Filament\Infolists\Components\TextEntry::make('serviceProvider.user.name')
                                    ->label(__('assignments.fields.service_provider')),

                                \Filament\Infolists\Components\ViewEntry::make('proofs')
                                    ->view('filament.components.proofs-preview')
                                    ->viewData(fn ($record) => [
                                        'proofs' => $record->proofs ?? [],
                                    ])
                                    ->label('')
                                    ->columnSpanFull(),
                            ])
                            ->columns(1),
                    ])
                    ->visible(fn ($record) => $record->assignments()->whereHas('proofs')->exists())
                    ->collapsed(),
            ]);
    }

    /**
     * Auto-select time slots with capacity-based partial booking
     * Uses available capacity within slots for exact duration matching
     * Supports multi-day selection for 24+ hour assignments
     */
    protected static function autoSelectSlotsForDuration(Get $get, Set $set): void
    {
        $duration = $get('allocated_duration_minutes');
        $spId = $get('service_provider_id');
        $scheduledDate = $get('scheduled_date');

        if (! $duration || ! $spId || ! $scheduledDate) {
            return;
        }

        $serviceProvider = \App\Models\ServiceProvider::find($spId);
        if (! $serviceProvider) {
            return;
        }

        $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
        $currentDate = \Carbon\Carbon::parse($scheduledDate);

        $selectedSlots = []; // Array of {slot_id, date, start_time, end_time, minutes}
        $accumulatedMinutes = 0;
        $maxDays = 90; // Maximum 90 days (3 months)
        $daysProcessed = 0;
        $lastDateWithSlots = $currentDate->copy();

        // Try to fill the duration across multiple days using available capacity
        while ($accumulatedMinutes < $duration && $daysProcessed < $maxDays) {
            $dayOfWeek = $currentDate->dayOfWeek;

            // Get all time slots for this day
            $allSlots = \App\Models\TimeSlot::where('service_provider_id', $spId)
                ->where('day_of_week', $dayOfWeek)
                ->where('is_active', true)
                ->orderBy('start_time')
                ->get();

            if ($allSlots->isNotEmpty()) {
                foreach ($allSlots as $slot) {
                    // KEY CHANGE: Get actual available capacity
                    $capacity = $availabilityService->getSlotCapacity($slot, $currentDate);

                    if ($capacity['available_minutes'] <= 0) {
                        continue; // Skip fully booked slots
                    }

                    $remainingNeeded = $duration - $accumulatedMinutes;

                    // How much can we take from this slot?
                    $minutesToUse = min($capacity['available_minutes'], $remainingNeeded);

                    // Find the best gap to fit these minutes
                    $nextAvailable = $availabilityService->calculateNextAvailableTime(
                        $slot,
                        $currentDate,
                        $minutesToUse
                    );

                    if ($nextAvailable) {
                        $selectedSlots[] = [
                            'slot_id' => $slot->id,
                            'date' => $currentDate->toDateString(),
                            'start_time' => $nextAvailable['start'],
                            'end_time' => $nextAvailable['end'],
                            'minutes' => $minutesToUse,
                        ];

                        $accumulatedMinutes += $minutesToUse;
                        $lastDateWithSlots = $currentDate->copy();

                        // Stop if we've accumulated enough
                        if ($accumulatedMinutes >= $duration) {
                            break 2;
                        }
                    }
                }
            }

            // Move to next day
            $currentDate->addDay();
            $daysProcessed++;
        }

        // Extract slot IDs for the CheckboxList
        $slotIds = array_unique(array_column($selectedSlots, 'slot_id'));
        $set('time_slot_ids', $slotIds);

        // Set time ranges for the assignment
        if (count($selectedSlots) === 1) {
            // Single slot: use the exact partial range (format as H:i without seconds)
            $set('assigned_start_time', substr($selectedSlots[0]['start_time'], 0, 5));
            $set('assigned_end_time', substr($selectedSlots[0]['end_time'], 0, 5));
        } elseif (count($selectedSlots) > 1) {
            // Multi-slot: use combined range (earliest start to latest end, format as H:i)
            $earliestStart = min(array_column($selectedSlots, 'start_time'));
            $latestEnd = max(array_column($selectedSlots, 'end_time'));
            $set('assigned_start_time', substr($earliestStart, 0, 5));
            $set('assigned_end_time', substr($latestEnd, 0, 5));
        }

        // Check if we fulfilled the duration
        if ($accumulatedMinutes < $duration) {
            $spanDays = $daysProcessed > 0 ? $daysProcessed : 1;
            \Filament\Notifications\Notification::make()
                ->warning()
                ->title(__('issues.validation.insufficient_capacity'))
                ->body(__('issues.validation.capacity_after_days', [
                    'available' => $accumulatedMinutes,
                    'required' => $duration,
                    'days' => $spanDays,
                ]))
                ->persistent()
                ->send();
        }

        // Show multi-day notification if applicable
        if ($lastDateWithSlots->greaterThan($currentDate->copy()->subDay())) {
            $spanDays = \Carbon\Carbon::parse($scheduledDate)->diffInDays($lastDateWithSlots) + 1;
            if ($spanDays > 1) {
                \Filament\Notifications\Notification::make()
                    ->info()
                    ->title(__('issues.validation.multi_day_assignment'))
                    ->body(__('issues.validation.spans_days', [
                        'days' => $spanDays,
                        'start' => \Carbon\Carbon::parse($scheduledDate)->format('M d'),
                        'end' => $lastDateWithSlots->format('M d, Y'),
                    ]))
                    ->persistent()
                    ->send();
            }
        }
    }

    public static function getRelations(): array
    {
        return [
            RelationManagers\AssignmentsRelationManager::class,
            RelationManagers\TimelineRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListIssues::route('/'),
            'create' => Pages\CreateIssue::route('/create'),
            'view' => Pages\ViewIssue::route('/{record}'),
            'edit' => Pages\EditIssue::route('/{record}/edit'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with([
                'tenant.user',
                'categories',
                'assignments.serviceProvider.user',
                'assignments.proofs',
                'media',
            ]);
    }
}
