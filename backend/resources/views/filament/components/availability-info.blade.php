@php
    use Carbon\Carbon;

    $activeSlots = $serviceProvider->timeSlots->where('is_active', true);
    $dayGroups = $activeSlots->groupBy('day_of_week');
    $days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
@endphp

<div class="space-y-4 text-sm">
    {{-- Working Hours Summary --}}
    <div>
        <h4 class="font-semibold text-gray-700 dark:text-gray-300 mb-2 text-xs uppercase tracking-wide">
            {{ __('issues.availability.working_hours') }}
        </h4>
        @if($activeSlots->isEmpty())
            <p class="text-gray-500 italic text-sm">{{ __('issues.availability.no_slots') }}</p>
        @else
            <div class="flex flex-wrap gap-1.5">
                @foreach($dayGroups as $dayOfWeek => $slots)
                    <span class="inline-flex items-center px-2.5 py-1 rounded-md text-xs font-medium bg-primary-50 text-primary-700 dark:bg-primary-900/50 dark:text-primary-300 ring-1 ring-primary-200 dark:ring-primary-800">
                        {{ __('days.' . $days[$dayOfWeek]) }}:
                        @foreach($slots as $slot)
                            {{ $slot->formatted_time_range }}@if(!$loop->last), @endif
                        @endforeach
                    </span>
                @endforeach
            </div>
        @endif
    </div>

    {{-- Selected Date Availability with Capacity Info --}}
    @if($selectedDate)
        @php
            $dayOfWeek = $selectedDate->dayOfWeek;
            $daySlots = $activeSlots->where('day_of_week', $dayOfWeek);
            $availabilityService = app(\App\Services\TimeSlotAvailabilityService::class);
        @endphp

        <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
            <h4 class="font-semibold text-gray-700 dark:text-gray-300 mb-3 text-xs uppercase tracking-wide">
                {{ __('issues.availability.on_date', ['date' => $selectedDate->translatedFormat('l, M d')]) }}
            </h4>

            @if($daySlots->isEmpty())
                <div class="flex items-center gap-2 text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 px-3 py-2 rounded-lg">
                    <svg class="flex-shrink-0" width="16" height="16" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
                    </svg>
                    <span class="text-sm">{{ __('issues.availability.no_working_hours_on_day') }}</span>
                </div>
            @else
                <div class="space-y-3">
                    @foreach($daySlots as $slot)
                        @php
                            // Exclude current assignment when editing to show correct available capacity
                            $excludeId = $excludeAssignmentId ?? null;
                            $capacity = $availabilityService->getSlotCapacity($slot, $selectedDate, $excludeId);
                            $utilizationPercent = $capacity['total_minutes'] > 0
                                ? round(($capacity['booked_minutes'] / $capacity['total_minutes']) * 100)
                                : 0;
                            $hasCapacity = $capacity['available_minutes'] > 0;
                            $nextAvailable = null;

                            if ($allocatedDuration && $hasCapacity && $capacity['available_minutes'] >= $allocatedDuration) {
                                $nextAvailable = $availabilityService->calculateNextAvailableTime(
                                    $slot,
                                    $selectedDate,
                                    $allocatedDuration,
                                    $excludeId
                                );
                            }
                        @endphp

                        <div class="p-3 rounded-lg border {{ $hasCapacity ? 'border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/20' : 'border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-900/20' }}">
                            {{-- Slot time range header --}}
                            <div class="flex items-center justify-between mb-2">
                                <span class="font-semibold text-sm {{ $hasCapacity ? 'text-green-700 dark:text-green-400' : 'text-red-700 dark:text-red-400' }}">
                                    {{ $slot->formatted_time_range }}
                                </span>
                                <span class="text-xs font-medium px-2 py-0.5 rounded {{ $hasCapacity ? 'bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100' : 'bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100' }}">
                                    {{ $utilizationPercent }}% {{ __('issues.availability.utilized') }}
                                </span>
                            </div>

                            {{-- Progress bar --}}
                            <div class="flex items-center gap-2 mb-2">
                                <div class="flex-1 bg-gray-200 rounded-full h-2 dark:bg-gray-700">
                                    <div class="bg-primary-600 h-2 rounded-full transition-all" style="width: {{ $utilizationPercent }}%"></div>
                                </div>
                            </div>

                            {{-- Capacity breakdown --}}
                            <div class="flex flex-wrap gap-3 text-xs {{ $hasCapacity ? 'text-green-700 dark:text-green-400' : 'text-red-700 dark:text-red-400' }}">
                                <span class="flex items-center gap-1">
                                    <svg class="w-3.5 h-3.5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                                    </svg>
                                    {{ $capacity['available_minutes'] }} min {{ __('issues.availability.available') }}
                                </span>
                                <span class="flex items-center gap-1">
                                    <svg class="w-3.5 h-3.5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                                    </svg>
                                    {{ $capacity['booked_minutes'] }} min {{ __('issues.availability.booked') }}
                                </span>
                                <span class="flex items-center gap-1">
                                    <svg class="w-3.5 h-3.5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                                    </svg>
                                    {{ $capacity['total_minutes'] }} min {{ __('issues.availability.total') }}
                                </span>
                            </div>

                            {{-- Next available time suggestion --}}
                            @if($nextAvailable)
                                <div class="mt-2 pt-2 border-t border-green-200 dark:border-green-800">
                                    <div class="flex items-center gap-1.5 text-xs text-green-700 dark:text-green-400 font-medium">
                                        <svg class="w-3.5 h-3.5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
                                        </svg>
                                        {{ __('issues.availability.next_available') }}:
                                        {{ substr($nextAvailable['start'], 0, 5) }} - {{ substr($nextAvailable['end'], 0, 5) }}
                                    </div>
                                </div>
                            @elseif(!$hasCapacity)
                                <div class="mt-2 pt-2 border-t border-red-200 dark:border-red-800">
                                    <div class="flex items-center gap-1.5 text-xs text-red-700 dark:text-red-400 font-medium">
                                        <svg class="w-3.5 h-3.5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="m9.75 9.75 4.5 4.5m0-4.5-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                                        </svg>
                                        {{ __('issues.availability.fully_booked') }}
                                    </div>
                                </div>
                            @endif
                        </div>
                    @endforeach
                </div>
            @endif
        </div>
    @endif
</div>
