<?php

namespace App\Filament\Resources\IssueResource\Pages;

use App\Actions\Issue\ApproveIssueAction;
use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Filament\Resources\IssueResource;
use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use App\Models\WorkType;
use Carbon\Carbon;
use Filament\Actions;
use Filament\Forms;
use Filament\Forms\Components\ViewField;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ViewRecord;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;

class ViewIssue extends ViewRecord
{
    protected static string $resource = IssueResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('assign')
                ->label(__('issues.actions.assign'))
                ->icon('heroicon-o-user-plus')
                ->color('primary')
                ->authorize('assign', $this->record)
                ->visible(fn () => $this->record->canBeAssigned())
                ->slideOver()
                ->modalWidth('xl')
                ->form([
                    Forms\Components\Select::make('category_id')
                        ->label(__('issues.fields.category'))
                        ->options(fn () => \Illuminate\Support\Facades\Cache::remember(
                            'categories_active_list',
                            now()->addHour(),
                            fn () => Category::active()->pluck('name_en', 'id')
                        ))
                        ->getOptionLabelUsing(fn ($value) => Category::find($value)?->name)
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

                                // Auto-select slots after work type selection
                                static::autoSelectSlotsForDuration($get, $set);
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
                                    $slots = TimeSlot::whereIn('id', $timeSlotIds)->get();
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
                ->action(function (array $data): void {
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
                    $this->record->assignments()->create([
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
                        'proof_required' => $this->record->proof_required,
                    ]);

                    $this->record->update(['status' => IssueStatus::ASSIGNED]);
                    $this->refreshFormData(['status']);

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

            Actions\Action::make('approve')
                ->label(__('issues.actions.approve'))
                ->icon('heroicon-o-check-badge')
                ->color('success')
                ->authorize('approve', $this->record)
                ->visible(fn () => $this->record->canBeApproved())
                ->requiresConfirmation()
                ->modalHeading(__('issues.actions.approve'))
                ->modalDescription(function (): string {
                    $pendingCount = $this->record->getPendingApprovalCount();
                    $totalCount = $this->record->getTotalAssignmentCount();

                    if ($pendingCount === $totalCount) {
                        return __('issues.actions.approve_confirmation');
                    }

                    return __('issues.actions.approve_confirmation_partial', [
                        'pending' => $pendingCount,
                        'total' => $totalCount,
                    ]);
                })
                ->action(function (): void {
                    // Get all finished assignments and approve them
                    $finishedAssignments = $this->record->assignments()
                        ->where('status', AssignmentStatus::FINISHED)
                        ->get();

                    $approveAction = app(ApproveIssueAction::class);

                    foreach ($finishedAssignments as $assignment) {
                        $approveAction->execute($assignment, auth()->id());
                    }

                    $this->refreshFormData(['status']);
                }),

            Actions\Action::make('cancel')
                ->label(__('issues.actions.cancel'))
                ->icon('heroicon-o-x-circle')
                ->color('danger')
                ->authorize('cancel', $this->record)
                ->visible(fn () => $this->record->canBeCancelled())
                ->requiresConfirmation()
                ->modalHeading(__('issues.actions.cancel'))
                ->modalDescription(__('issues.actions.cancel_confirmation'))
                ->form([
                    Forms\Components\Textarea::make('cancelled_reason')
                        ->label(__('issues.fields.cancelled_reason'))
                        ->required()
                        ->rows(3),
                ])
                ->action(function (array $data): void {
                    $this->record->update([
                        'status' => IssueStatus::CANCELLED,
                        'cancelled_reason' => $data['cancelled_reason'],
                        'cancelled_by' => auth()->id(),
                        'cancelled_at' => now(),
                    ]);

                    $this->refreshFormData(['status']);
                }),

            Actions\EditAction::make()
                ->visible(fn () => auth()->user()->can('update', $this->record)),
        ];
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

        $serviceProvider = ServiceProvider::find($spId);
        if (! $serviceProvider) {
            return;
        }

        $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
        $currentDate = Carbon::parse($scheduledDate);

        $selectedSlots = []; // Array of {slot_id, date, start_time, end_time, minutes}
        $accumulatedMinutes = 0;
        $maxDays = 90; // Maximum 90 days (3 months)
        $daysProcessed = 0;
        $lastDateWithSlots = $currentDate->copy();

        while ($accumulatedMinutes < $duration && $daysProcessed < $maxDays) {
            $dayOfWeek = $currentDate->dayOfWeek;

            // Get all active slots for this day of week
            $allSlots = TimeSlot::where('service_provider_id', $spId)
                ->where('day_of_week', $dayOfWeek)
                ->where('is_active', true)
                ->orderBy('start_time')
                ->get();

            if ($allSlots->isNotEmpty()) {
                $lastDateWithSlots = $currentDate->copy();

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
            $lastDate = $lastDateWithSlots->format('Y-m-d');

            Notification::make()
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
    }
}
