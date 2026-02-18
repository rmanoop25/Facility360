@php
    $days = [
        0 => __('days.sunday'),
        1 => __('days.monday'),
        2 => __('days.tuesday'),
        3 => __('days.wednesday'),
        4 => __('days.thursday'),
        5 => __('days.friday'),
        6 => __('days.saturday'),
    ];

    // Group time slots by day
    $slotsByDay = collect($timeSlots ?? [])->groupBy('day_of_week');
@endphp

<style>
    .schedule-container {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
    }
    .schedule-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 1rem;
        border: 1px solid #e5e7eb;
        border-radius: 0.625rem;
        background-color: #ffffff;
        transition: all 0.2s ease;
    }
    .schedule-row:hover {
        box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
    }
    .schedule-day {
        flex-shrink: 0;
        width: 100px;
        font-weight: 600;
        color: #1f2937;
        font-size: 0.95rem;
    }
    .schedule-slots {
        flex: 1;
        padding: 0 1.5rem;
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
        min-height: 2rem;
        align-items: center;
    }
    .schedule-badge-active {
        display: inline-flex;
        align-items: center;
        padding: 0.5rem 0.875rem;
        border-radius: 0.375rem;
        font-size: 0.8125rem;
        font-weight: 600;
        background-color: #dbeafe;
        color: #1e40af;
        border: 1px solid #93c5fd;
        white-space: nowrap;
    }
    .schedule-badge-inactive {
        display: inline-flex;
        align-items: center;
        padding: 0.5rem 0.875rem;
        border-radius: 0.375rem;
        font-size: 0.8125rem;
        font-weight: 600;
        background-color: #f3f4f6;
        color: #6b7280;
        border: 1px solid #d1d5db;
        text-decoration: line-through;
        white-space: nowrap;
    }
    .schedule-empty {
        font-size: 0.875rem;
        color: #9ca3af;
        font-style: italic;
    }
    .schedule-indicator {
        flex-shrink: 0;
        width: 3rem;
        text-align: center;
        display: flex;
        justify-content: center;
    }
    .schedule-icon-success {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 1.75rem;
        height: 1.75rem;
        border-radius: 50%;
        background-color: #dcfce7;
        border: 2px solid #86efac;
    }
    .schedule-icon-danger {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 1.75rem;
        height: 1.75rem;
        border-radius: 50%;
        background-color: #fee2e2;
        border: 2px solid #fca5a5;
    }
    .schedule-icon-empty {
        color: #d1d5db;
        font-size: 0.875rem;
    }

    /* Dark mode styles */
    @media (prefers-color-scheme: dark) {
        .schedule-row {
            border-color: #374151;
            background-color: #1f2937;
        }
        .schedule-row:hover {
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.3);
        }
        .schedule-day {
            color: #f3f4f6;
        }
        .schedule-badge-active {
            background-color: rgba(30, 64, 175, 0.15);
            color: #93c5fd;
            border-color: rgba(59, 130, 246, 0.4);
        }
        .schedule-badge-inactive {
            background-color: #374151;
            color: #9ca3af;
            border-color: #4b5563;
        }
        .schedule-empty {
            color: #6b7280;
        }
        .schedule-icon-success {
            background-color: rgba(34, 197, 94, 0.15);
            border-color: rgba(74, 222, 128, 0.4);
        }
        .schedule-icon-danger {
            background-color: rgba(239, 68, 68, 0.15);
            border-color: rgba(252, 165, 165, 0.4);
        }
        .schedule-icon-empty {
            color: #4b5563;
        }
    }
</style>

<div class="schedule-container">
    @foreach($days as $dayNum => $dayName)
        @php
            $daySlots = $slotsByDay->get($dayNum, collect());
            $hasSlots = $daySlots->isNotEmpty();
        @endphp
        <div class="schedule-row">
            {{-- Day name --}}
            <div class="schedule-day">
                <span>{{ $dayName }}</span>
            </div>

            {{-- Time slots --}}
            <div class="schedule-slots">
                @if($hasSlots)
                    @foreach($daySlots as $slot)
                        @php
                            $isActive = $slot['is_active'] ?? true;
                            $startTime = $slot['start_time'] ?? '00:00';
                            $endTime = $slot['end_time'] ?? '00:00';
                        @endphp
                        <span class="{{ $isActive ? 'schedule-badge-active' : 'schedule-badge-inactive' }}">
                            {{ $startTime }} - {{ $endTime }}
                        </span>
                    @endforeach
                @else
                    <span class="schedule-empty">{{ __('time_slots.status.not_configured') }}</span>
                @endif
            </div>

            {{-- Active indicator --}}
            <div class="schedule-indicator">
                @if($hasSlots)
                    @php
                        $anyActive = $daySlots->contains(fn($slot) => ($slot['is_active'] ?? true) === true);
                    @endphp
                    @if($anyActive)
                        <span class="schedule-icon-success">
                            <svg style="width: 1rem; height: 1rem; color: #16a34a;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                        </span>
                    @else
                        <span class="schedule-icon-danger">
                            <svg style="width: 1rem; height: 1rem; color: #dc2626;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                        </span>
                    @endif
                @else
                    <span class="schedule-icon-empty">—</span>
                @endif
            </div>
        </div>
    @endforeach
</div>
