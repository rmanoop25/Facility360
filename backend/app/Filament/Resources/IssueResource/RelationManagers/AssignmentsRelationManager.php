<?php

namespace App\Filament\Resources\IssueResource\RelationManagers;

use App\Enums\AssignmentStatus;
use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use App\Models\WorkType;
use Carbon\Carbon;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms;
use Filament\Forms\Components\ViewField;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;

class AssignmentsRelationManager extends RelationManager
{
    protected static string $relationship = 'assignments';

    public static function getTitle($ownerRecord, string $pageClass): string
    {
        return __('assignments.plural');
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->columns(1)
            ->components([
                Forms\Components\Select::make('category_id')
                    ->label(__('assignments.fields.category'))
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
                            $endTime = Carbon::parse($startTime)->addMinutes($minutes);
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
                            $endTime = Carbon::parse($startTime)->addMinutes($currentMinutes);
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
                                $slots = TimeSlot::whereIn('id', $timeSlotIds)->get();
                                $totalMinutes = $slots->sum(function ($slot) {
                                    return Carbon::parse($slot->start_time)
                                        ->diffInMinutes(Carbon::parse($slot->end_time));
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
                    ->label(__('assignments.fields.service_provider'))
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
                    ->viewData(function (Get $get, $record) {
                        $spId = $get('service_provider_id');
                        $scheduledDate = $get('scheduled_date');
                        $allocatedDuration = $get('allocated_duration_minutes');

                        return [
                            'serviceProvider' => $spId ? ServiceProvider::with('timeSlots')->find($spId) : null,
                            'selectedDate' => $scheduledDate ? Carbon::parse($scheduledDate) : null,
                            'allocatedDuration' => $allocatedDuration,
                            'excludeAssignmentId' => $record?->id, // Exclude current assignment when editing
                        ];
                    })
                    ->visible(fn (Get $get) => filled($get('service_provider_id'))),

                Forms\Components\DatePicker::make('scheduled_date')
                    ->label(__('assignments.fields.scheduled_date'))
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
                    ->label(__('assignments.fields.time_slots'))
                    ->options(function (Get $get, $record) {
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
                                ->filter(fn ($slot) => $slot->isAvailableOn($targetDate, $record?->id)); // Only available, exclude current assignment

                            foreach ($slots as $slot) {
                                $label = $slot->display_name;

                                // Get capacity info
                                $capacity = $availabilityService->getSlotCapacity($slot, $targetDate, $record?->id);

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
                    ->afterStateUpdated(function ($state, Set $set, Get $get, $record) {
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

                            if ($availabilityService->hasMultiSlotOverlap($spId, $date, $state, $record?->id)) {
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
                            ->dehydrated(false),

                        Forms\Components\TimePicker::make('assigned_start_time')
                            ->label(__('assignments.fields.assigned_start_time'))
                            ->seconds(false)
                            ->dehydrated(true)
                            ->visible(fn (Get $get) => $get('use_manual_time_override'))
                            ->live(onBlur: true)
                            ->afterStateUpdated(function (Get $get, Set $set, $state) {
                                if (! $state) {
                                    $set('assigned_end_time', null);

                                    return;
                                }

                                $duration = $get('allocated_duration_minutes');
                                if ($duration) {
                                    $endTime = Carbon::parse($state)->addMinutes($duration);
                                    $set('assigned_end_time', $endTime->format('H:i'));
                                }
                            })
                            ->rules([
                                fn (Get $get, $record): \Closure => function (string $attribute, $value, \Closure $fail) use ($get, $record) {
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
                                    $slotStart = Carbon::parse($earliestStart);
                                    $slotEnd = Carbon::parse($latestEnd);
                                    $manualStart = Carbon::parse($value.':00');
                                    $manualEnd = Carbon::parse($get('assigned_end_time').':00');

                                    // Check if time is within combined slot bounds
                                    if ($manualStart->lt($slotStart) || $manualEnd->gt($slotEnd)) {
                                        $fail(__('issues.assigned_time_outside_slots', [
                                            'start' => substr($earliestStart, 0, 5),
                                            'end' => substr($latestEnd, 0, 5),
                                        ]));

                                        return;
                                    }

                                    // Check for overlaps (exclude current record when editing)
                                    $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
                                    $scheduledDateCarbon = Carbon::parse($scheduledDate);

                                    if ($availabilityService->hasMultiSlotOverlap(
                                        $serviceProviderId,
                                        $scheduledDateCarbon,
                                        $timeSlotIds,
                                        $record?->id
                                    )) {
                                        $fail(__('issues.time_slots_overlap_with_existing_assignment'));
                                    }
                                },
                            ]),

                        Forms\Components\TimePicker::make('assigned_end_time')
                            ->label(__('assignments.fields.assigned_end_time'))
                            ->seconds(false)
                            ->disabled()
                            ->dehydrated()
                            ->helperText('Auto-calculated from start time + duration')
                            ->visible(fn (Get $get) => $get('use_manual_time_override'))
                            ->live(onBlur: true)
                            ->rules([
                                fn (Get $get, $record): \Closure => function (string $attribute, $value, \Closure $fail) use ($get, $record) {
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
                                    $slotStart = Carbon::parse($earliestStart);
                                    $slotEnd = Carbon::parse($latestEnd);
                                    $manualStart = Carbon::parse($get('assigned_start_time').':00');
                                    $manualEnd = Carbon::parse($value.':00');

                                    // Check if time is within combined slot bounds
                                    if ($manualStart->lt($slotStart) || $manualEnd->gt($slotEnd)) {
                                        $fail(__('issues.assigned_time_outside_slots', [
                                            'start' => substr($earliestStart, 0, 5),
                                            'end' => substr($latestEnd, 0, 5),
                                        ]));

                                        return;
                                    }

                                    // Check for overlaps (exclude current record when editing)
                                    $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
                                    $scheduledDateCarbon = Carbon::parse($scheduledDate);

                                    if ($availabilityService->hasMultiSlotOverlap(
                                        $serviceProviderId,
                                        $scheduledDateCarbon,
                                        $timeSlotIds,
                                        $record?->id
                                    )) {
                                        $fail(__('issues.time_slots_overlap_with_existing_assignment'));
                                    }
                                },
                            ])
                            ->helperText('Auto-filled from start time + duration'),
                    ])
                    ->columns(2)
                    ->visible(fn (Get $get) => filled($get('time_slot_ids')))
                    ->description('Specify exact time range within the selected slots, or leave empty to auto-calculate'),

                Forms\Components\Textarea::make('notes')
                    ->label(__('assignments.fields.notes'))
                    ->rows(3)
                    ->columnSpanFull(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('id')
            ->columns([
                Tables\Columns\TextColumn::make('serviceProvider.user.name')
                    ->label(__('assignments.fields.service_provider'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('category.name_en')
                    ->label(__('assignments.fields.category'))
                    ->formatStateUsing(fn ($record) => $record->category?->name)
                    ->badge()
                    ->color('info'),

                Tables\Columns\TextColumn::make('time_slots')
                    ->label(__('assignments.fields.time_slots'))
                    ->formatStateUsing(function ($record) {
                        if (empty($record->time_slot_ids)) {
                            return '-';
                        }

                        $slots = TimeSlot::whereIn('id', $record->time_slot_ids)
                            ->orderBy('start_time')
                            ->get();

                        return $slots->map(fn ($slot) => $slot->display_name)->join(', ');
                    })
                    ->badge()
                    ->color('primary')
                    ->searchable(false),

                Tables\Columns\TextColumn::make('scheduled_date')
                    ->label(__('assignments.fields.scheduled_date'))
                    ->date()
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->label(__('assignments.fields.status'))
                    ->badge()
                    ->formatStateUsing(fn (AssignmentStatus $state): string => $state->label())
                    ->color(fn (AssignmentStatus $state): string => $state->color())
                    ->icon(fn (AssignmentStatus $state): string => $state->icon()),

                Tables\Columns\TextColumn::make('started_at')
                    ->label(__('assignments.fields.started_at'))
                    ->dateTime()
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('finished_at')
                    ->label(__('assignments.fields.finished_at'))
                    ->dateTime()
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label(__('assignments.filters.status'))
                    ->options(AssignmentStatus::options()),
            ])
            ->headerActions([
                CreateAction::make()
                    ->slideOver()
                    ->modalWidth('xl')
                    ->mutateFormDataUsing(function (array $data): array {
                        // Get duration from work type if not custom
                        $allocatedDuration = $data['allocated_duration_minutes'] ?? null;
                        if (! $allocatedDuration && isset($data['work_type_id'])) {
                            $workType = WorkType::find($data['work_type_id']);
                            $allocatedDuration = $workType?->duration_minutes;
                        }

                        // Get time slots
                        $timeSlotIds = $data['time_slot_ids'];
                        $timeSlots = TimeSlot::whereIn('id', $timeSlotIds)->orderBy('start_time')->get();

                        // Calculate time range if not manually provided
                        if (empty($data['assigned_start_time']) || empty($data['assigned_end_time'])) {
                            // Auto-calculate: use the full combined range of all selected slots
                            $earliestStart = $timeSlots->min('start_time');
                            $latestEnd = $timeSlots->max('end_time');
                            $data['assigned_start_time'] = $earliestStart;
                            $data['assigned_end_time'] = $latestEnd;
                        } else {
                            // Ensure seconds format
                            $data['assigned_start_time'] = $data['assigned_start_time'].':00';
                            $data['assigned_end_time'] = $data['assigned_end_time'].':00';
                        }

                        $data['allocated_duration_minutes'] = $allocatedDuration;
                        $data['time_slot_id'] = $timeSlotIds[0] ?? null; // Backward compat
                        $data['status'] = AssignmentStatus::ASSIGNED->value;
                        $data['proof_required'] = $this->ownerRecord->proof_required;

                        return $data;
                    }),
            ])
            ->actions([
                ViewAction::make()
                    ->slideOver()
                    ->modalWidth('lg')
                    ->infolist(fn (Schema $schema) => $schema->components([
                        Section::make(__('assignments.sections.details'))
                            ->schema([
                                \Filament\Infolists\Components\TextEntry::make('serviceProvider.user.name')
                                    ->label(__('assignments.fields.service_provider')),

                                \Filament\Infolists\Components\TextEntry::make('category.name')
                                    ->label(__('assignments.fields.category')),

                                \Filament\Infolists\Components\TextEntry::make('time_slots')
                                    ->label(__('assignments.fields.time_slots'))
                                    ->formatStateUsing(function ($record) {
                                        if (empty($record->time_slot_ids)) {
                                            return '-';
                                        }

                                        $slots = TimeSlot::whereIn('id', $record->time_slot_ids)
                                            ->orderBy('start_time')
                                            ->get();

                                        return $slots->map(fn ($slot) => $slot->display_name)->join(' • ');
                                    })
                                    ->badge()
                                    ->color('primary'),

                                \Filament\Infolists\Components\TextEntry::make('assigned_time_range')
                                    ->label(__('assignments.fields.assigned_time'))
                                    ->getStateUsing(function ($record) {
                                        if ($record->assigned_start_time && $record->assigned_end_time) {
                                            return substr($record->assigned_start_time, 0, 5)
                                                .' - '
                                                .substr($record->assigned_end_time, 0, 5);
                                        }

                                        return __('assignments.auto_calculated');
                                    })
                                    ->badge()
                                    ->color('info'),

                                \Filament\Infolists\Components\TextEntry::make('total_duration')
                                    ->label(__('assignments.fields.total_duration'))
                                    ->getStateUsing(function ($record) {
                                        $totalMinutes = $record->getTotalDurationMinutes();
                                        $hours = floor($totalMinutes / 60);
                                        $minutes = $totalMinutes % 60;

                                        if ($hours > 0 && $minutes > 0) {
                                            return "{$hours}h {$minutes}m";
                                        } elseif ($hours > 0) {
                                            return "{$hours}h";
                                        } else {
                                            return "{$minutes}m";
                                        }
                                    })
                                    ->badge()
                                    ->color('success'),

                                \Filament\Infolists\Components\TextEntry::make('scheduled_date')
                                    ->label(__('assignments.fields.scheduled_date'))
                                    ->date(),

                                \Filament\Infolists\Components\TextEntry::make('status')
                                    ->label(__('assignments.fields.status'))
                                    ->badge()
                                    ->formatStateUsing(fn (AssignmentStatus $state): string => $state->label())
                                    ->color(fn (AssignmentStatus $state): string => $state->color()),

                                \Filament\Infolists\Components\TextEntry::make('notes')
                                    ->label(__('assignments.fields.notes'))
                                    ->columnSpanFull(),
                            ])
                            ->columns(2),

                        Section::make(__('assignments.sections.timestamps'))
                            ->schema([
                                \Filament\Infolists\Components\TextEntry::make('started_at')
                                    ->label(__('assignments.fields.started_at'))
                                    ->dateTime(),

                                \Filament\Infolists\Components\TextEntry::make('held_at')
                                    ->label(__('assignments.fields.held_at'))
                                    ->dateTime(),

                                \Filament\Infolists\Components\TextEntry::make('resumed_at')
                                    ->label(__('assignments.fields.resumed_at'))
                                    ->dateTime(),

                                \Filament\Infolists\Components\TextEntry::make('finished_at')
                                    ->label(__('assignments.fields.finished_at'))
                                    ->dateTime(),

                                \Filament\Infolists\Components\TextEntry::make('completed_at')
                                    ->label(__('assignments.fields.completed_at'))
                                    ->dateTime(),
                            ])
                            ->columns(3),

                        Section::make(__('assignments.sections.proofs'))
                            ->schema([
                                \Filament\Infolists\Components\RepeatableEntry::make('proofs')
                                    ->schema([
                                        \Filament\Infolists\Components\TextEntry::make('type')
                                            ->label(__('proofs.fields.type')),

                                        \Filament\Infolists\Components\TextEntry::make('stage')
                                            ->label(__('proofs.fields.stage')),

                                        \Filament\Infolists\Components\ImageEntry::make('url')
                                            ->label(__('proofs.fields.file'))
                                            ->visible(fn ($record) => $record->isPhoto()),

                                        \Filament\Infolists\Components\TextEntry::make('url')
                                            ->label(__('proofs.fields.file'))
                                            ->url(fn ($record) => $record->url)
                                            ->openUrlInNewTab()
                                            ->visible(fn ($record) => ! $record->isPhoto()),
                                    ])
                                    ->columns(3),
                            ])
                            ->visible(fn ($record) => $record->proofs->isNotEmpty()),

                        Section::make(__('assignments.sections.consumables'))
                            ->schema([
                                \Filament\Infolists\Components\RepeatableEntry::make('consumables')
                                    ->schema([
                                        \Filament\Infolists\Components\TextEntry::make('name')
                                            ->label(__('consumables.fields.name')),

                                        \Filament\Infolists\Components\TextEntry::make('quantity')
                                            ->label(__('assignments.fields.quantity')),
                                    ])
                                    ->columns(2),
                            ])
                            ->visible(fn ($record) => $record->consumables->isNotEmpty()),
                    ])),

                EditAction::make()
                    ->slideOver()
                    ->modalWidth('xl')
                    ->mutateFormDataUsing(function (array $data): array {
                        // Prepare time_slot_ids array from CheckboxList
                        if (isset($data['time_slots']) && is_array($data['time_slots'])) {
                            $data['time_slot_ids'] = $data['time_slots'];
                            unset($data['time_slots']);
                        }

                        // Calculate assigned time range if manual override provided
                        if (! empty($data['assigned_start_time']) && ! empty($data['assigned_end_time'])) {
                            // Keep manual times as-is
                        } else {
                            // Calculate from selected slots
                            $slotIds = $data['time_slot_ids'] ?? [];
                            if (! empty($slotIds)) {
                                $slots = \App\Models\TimeSlot::whereIn('id', $slotIds)->get();
                                if ($slots->isNotEmpty()) {
                                    $startTimes = $slots->map(fn ($s) => \Carbon\Carbon::parse($s->start_time));
                                    $endTimes = $slots->map(fn ($s) => \Carbon\Carbon::parse($s->end_time));
                                    $data['assigned_start_time'] = $startTimes->min()->format('H:i');
                                    $data['assigned_end_time'] = $endTimes->max()->format('H:i');
                                }
                            }
                        }

                        // Calculate scheduled_end_date if multi-slot
                        if (! empty($data['time_slot_ids']) && count($data['time_slot_ids']) > 1) {
                            $slots = \App\Models\TimeSlot::whereIn('id', $data['time_slot_ids'])->get();
                            $maxDayOfWeek = $slots->max('day_of_week');
                            $scheduledDate = \Carbon\Carbon::parse($data['scheduled_date']);

                            // Find end date based on last slot's day of week
                            $data['scheduled_end_date'] = $scheduledDate->copy()
                                ->addDays($maxDayOfWeek - $scheduledDate->dayOfWeek)
                                ->toDateString();
                        }

                        return $data;
                    }),
                DeleteAction::make(),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    /**
     * Auto-select consecutive time slots to meet the required duration
     */
    protected static function autoSelectSlotsForDuration(Get $get, Set $set): void
    {
        $duration = $get('allocated_duration_minutes');
        $spId = $get('service_provider_id');
        $scheduledDate = $get('scheduled_date');

        if (! $duration || ! $spId || ! $scheduledDate) {
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
                    // Get actual available capacity
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
}
