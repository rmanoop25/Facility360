<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\AssignmentStatus;
use App\Models\IssueAssignment;
use App\Models\TimeSlot;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class TimeSlotAvailabilityService
{
    /**
     * Check if a time range overlaps with existing assignments.
     *
     * @param  int  $serviceProviderId  Service provider ID
     * @param  Carbon  $scheduledDate  Date of the assignment
     * @param  string  $startTime  Start time in "HH:MM:SS" format
     * @param  string  $endTime  End time in "HH:MM:SS" format
     * @param  int|null  $excludeAssignmentId  Optional assignment ID to exclude (for updates)
     * @return bool True if there's an overlap, false otherwise
     */
    public function hasOverlap(
        int $serviceProviderId,
        Carbon $scheduledDate,
        string $startTime,
        string $endTime,
        ?int $excludeAssignmentId = null
    ): bool {
        $query = IssueAssignment::where('service_provider_id', $serviceProviderId)
            ->where('scheduled_date', $scheduledDate->toDateString())
            ->where('status', '!=', AssignmentStatus::COMPLETED->value)
            ->whereNotNull('assigned_start_time')
            ->whereNotNull('assigned_end_time');

        if ($excludeAssignmentId) {
            $query->where('id', '!=', $excludeAssignmentId);
        }

        // SQL overlap condition: (new_start < existing_end) AND (new_end > existing_start)
        $query->where(function ($q) use ($startTime, $endTime) {
            $q->where('assigned_start_time', '<', $endTime)
                ->where('assigned_end_time', '>', $startTime);
        });

        return $query->exists();
    }

    /**
     * Get all existing assignments for a service provider on a specific date and slot.
     *
     * @param  int  $serviceProviderId  Service provider ID
     * @param  Carbon  $scheduledDate  Date to check
     * @param  int  $timeSlotId  Time slot ID
     * @return Collection<int, IssueAssignment>
     */
    public function getExistingAssignments(
        int $serviceProviderId,
        Carbon $scheduledDate,
        int $timeSlotId,
        ?int $excludeAssignmentId = null
    ): Collection {
        $query = IssueAssignment::where('service_provider_id', $serviceProviderId)
            ->where('scheduled_date', $scheduledDate->toDateString())
            ->where('status', '!=', AssignmentStatus::COMPLETED->value)
            ->whereNotNull('assigned_start_time')
            ->whereNotNull('assigned_end_time')
            // Use the new time_slot_ids JSON column (multi-slot support)
            ->whereJsonContains('time_slot_ids', $timeSlotId)
            ->orderBy('assigned_start_time');

        if ($excludeAssignmentId) {
            $query->where('id', '!=', $excludeAssignmentId);
        }

        return $query->get();
    }

    /**
     * Calculate the next available time slot that can fit the requested duration.
     *
     * @param  TimeSlot  $timeSlot  The time slot to check
     * @param  Carbon  $scheduledDate  Date to check
     * @param  int  $durationMinutes  Required duration in minutes
     * @return array{start: string, end: string}|null Start and end time in "HH:MM:SS" format, or null if no gap available
     */
    public function calculateNextAvailableTime(
        TimeSlot $timeSlot,
        Carbon $scheduledDate,
        int $durationMinutes,
        ?int $excludeAssignmentId = null
    ): ?array {
        $slotStart = Carbon::parse($timeSlot->start_time);
        $slotEnd = Carbon::parse($timeSlot->end_time);

        // Get all existing assignments sorted by start time (excluding the specified one if editing)
        $assignments = $this->getExistingAssignments(
            $timeSlot->service_provider_id,
            $scheduledDate,
            $timeSlot->id,
            $excludeAssignmentId
        );

        // Start searching from the beginning of the slot
        $searchStart = $slotStart->copy();

        // Check each gap between assignments
        foreach ($assignments as $assignment) {
            $assignedStart = Carbon::parse($assignment->assigned_start_time);
            $assignedEnd = Carbon::parse($assignment->assigned_end_time);

            // Calculate if there's a gap before this assignment
            $gapEnd = $searchStart->copy()->addMinutes($durationMinutes);

            if ($gapEnd->lte($assignedStart)) {
                // Found a gap that fits!
                return [
                    'start' => $searchStart->format('H:i:s'),
                    'end' => $gapEnd->format('H:i:s'),
                ];
            }

            // Move search start to after this assignment
            $searchStart = $assignedEnd->copy();
        }

        // Check if there's space at the end of the slot
        $finalEnd = $searchStart->copy()->addMinutes($durationMinutes);
        if ($finalEnd->lte($slotEnd)) {
            return [
                'start' => $searchStart->format('H:i:s'),
                'end' => $finalEnd->format('H:i:s'),
            ];
        }

        return null; // No available gap
    }

    /**
     * Get capacity information for a time slot on a specific date.
     *
     * @param  TimeSlot  $timeSlot  The time slot to check
     * @param  Carbon  $scheduledDate  Date to check
     * @return array{
     *     total_minutes: int,
     *     booked_minutes: int,
     *     available_minutes: int,
     *     has_capacity: bool,
     *     gaps: array
     * }
     */
    public function getSlotCapacity(TimeSlot $timeSlot, Carbon $scheduledDate, ?int $excludeAssignmentId = null): array
    {
        $slotStart = Carbon::parse($timeSlot->start_time);
        $slotEnd = Carbon::parse($timeSlot->end_time);
        $totalMinutes = $slotStart->diffInMinutes($slotEnd);

        // Get all existing assignments (excluding the specified one if editing)
        $assignments = $this->getExistingAssignments(
            $timeSlot->service_provider_id,
            $scheduledDate,
            $timeSlot->id,
            $excludeAssignmentId
        );

        // Calculate booked minutes
        $bookedMinutes = 0;
        foreach ($assignments as $assignment) {
            $assignedStart = Carbon::parse($assignment->assigned_start_time);
            $assignedEnd = Carbon::parse($assignment->assigned_end_time);
            $bookedMinutes += $assignedStart->diffInMinutes($assignedEnd);
        }

        $availableMinutes = $totalMinutes - $bookedMinutes;

        // Find all available gaps
        $gaps = $this->findAvailableGaps($timeSlot, $scheduledDate, $excludeAssignmentId);

        return [
            'total_minutes' => $totalMinutes,
            'booked_minutes' => $bookedMinutes,
            'available_minutes' => $availableMinutes,
            'has_capacity' => $availableMinutes > 0,
            'gaps' => $gaps,
        ];
    }

    /**
     * Find all available time gaps within a time slot.
     *
     * @param  TimeSlot  $timeSlot  The time slot to check
     * @param  Carbon  $scheduledDate  Date to check
     * @return array<int, array{start: string, end: string, duration_minutes: int}>
     */
    public function findAvailableGaps(TimeSlot $timeSlot, Carbon $scheduledDate, ?int $excludeAssignmentId = null): array
    {
        $slotStart = Carbon::parse($timeSlot->start_time);
        $slotEnd = Carbon::parse($timeSlot->end_time);

        // Get all existing assignments (excluding the specified one if editing)
        $assignments = $this->getExistingAssignments(
            $timeSlot->service_provider_id,
            $scheduledDate,
            $timeSlot->id,
            $excludeAssignmentId
        );

        $gaps = [];
        $currentStart = $slotStart->copy();

        // Find gaps between assignments
        foreach ($assignments as $assignment) {
            $assignedStart = Carbon::parse($assignment->assigned_start_time);
            $assignedEnd = Carbon::parse($assignment->assigned_end_time);

            // Check if there's a gap before this assignment
            if ($currentStart->lt($assignedStart)) {
                $gaps[] = [
                    'start' => $currentStart->format('H:i:s'),
                    'end' => $assignedStart->format('H:i:s'),
                    'duration_minutes' => $currentStart->diffInMinutes($assignedStart),
                ];
            }

            // Move current start to after this assignment
            $currentStart = $assignedEnd->copy();
        }

        // Check if there's a gap at the end
        if ($currentStart->lt($slotEnd)) {
            $gaps[] = [
                'start' => $currentStart->format('H:i:s'),
                'end' => $slotEnd->format('H:i:s'),
                'duration_minutes' => $currentStart->diffInMinutes($slotEnd),
            ];
        }

        return $gaps;
    }

    /**
     * Check if time ranges across multiple slots overlap with existing assignments.
     *
     * @param  int  $serviceProviderId  Service provider ID
     * @param  Carbon  $scheduledDate  Date to check
     * @param  array<int>  $timeSlotIds  Array of time slot IDs being assigned
     * @param  int|null  $excludeAssignmentId  Optional assignment ID to exclude (for updates)
     * @return bool True if there's an overlap, false otherwise
     */
    public function hasMultiSlotOverlap(
        int $serviceProviderId,
        Carbon $scheduledDate,
        array $timeSlotIds,
        ?int $excludeAssignmentId = null
    ): bool {
        // Get all assignments for this SP on this date
        $query = IssueAssignment::where('service_provider_id', $serviceProviderId)
            ->where('scheduled_date', $scheduledDate->toDateString())
            ->where('status', '!=', AssignmentStatus::COMPLETED->value);

        if ($excludeAssignmentId) {
            $query->where('id', '!=', $excludeAssignmentId);
        }

        $existingAssignments = $query->get();

        // Get time ranges for new assignment slots
        $newSlots = TimeSlot::whereIn('id', $timeSlotIds)->get();

        foreach ($existingAssignments as $existing) {
            $existingSlots = $existing->timeSlots();

            // Check if any new slot overlaps with any existing slot
            foreach ($newSlots as $newSlot) {
                $newStart = Carbon::parse($newSlot->start_time);
                $newEnd = Carbon::parse($newSlot->end_time);

                foreach ($existingSlots as $existingSlot) {
                    // Skip if slots are on different days of the week
                    if ($newSlot->day_of_week !== $existingSlot->day_of_week) {
                        continue;
                    }

                    $existingStart = Carbon::parse($existingSlot->start_time);
                    $existingEnd = Carbon::parse($existingSlot->end_time);

                    // Overlap condition: (new_start < existing_end) AND (new_end > existing_start)
                    if ($newStart->lt($existingEnd) && $newEnd->gt($existingStart)) {
                        return true; // Overlap detected
                    }
                }
            }
        }

        return false;
    }

    /**
     * Get capacity information for multiple slots on a specific date.
     *
     * @param  array<TimeSlot>  $timeSlots  Array of time slots
     * @param  int  $serviceProviderId  Service provider ID
     * @param  Carbon  $scheduledDate  Date to check
     * @return array{
     *     total_minutes: int,
     *     booked_minutes: int,
     *     available_minutes: int,
     *     has_capacity: bool,
     *     gaps: array,
     *     slot_count: int
     * }
     */
    public function getMultiSlotCapacity(
        array $timeSlots,
        int $serviceProviderId,
        Carbon $scheduledDate
    ): array {
        $totalMinutes = 0;
        $bookedMinutes = 0;
        $gaps = [];

        foreach ($timeSlots as $slot) {
            $capacity = $this->getSlotCapacity($slot, $scheduledDate);
            $totalMinutes += $capacity['total_minutes'];
            $bookedMinutes += $capacity['booked_minutes'];
            $gaps = array_merge($gaps, $capacity['gaps']);
        }

        return [
            'total_minutes' => $totalMinutes,
            'booked_minutes' => $bookedMinutes,
            'available_minutes' => $totalMinutes - $bookedMinutes,
            'has_capacity' => ($totalMinutes - $bookedMinutes) > 0,
            'gaps' => $gaps,
            'slot_count' => count($timeSlots),
        ];
    }
}
