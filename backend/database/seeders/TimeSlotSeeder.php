<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use Illuminate\Database\Seeder;

class TimeSlotSeeder extends Seeder
{
    public function run(): void
    {
        $serviceProviders = ServiceProvider::with('user')->get();

        if ($serviceProviders->isEmpty()) {
            $this->command->warn('No service providers found. Run AdminUserSeeder first.');
            return;
        }

        $createdSlots = 0;

        foreach ($serviceProviders as $serviceProvider) {
            // Skip unavailable or inactive service providers
            if (!$serviceProvider->is_available || !$serviceProvider->user?->is_active) {
                continue;
            }

            $slots = $this->getTimeSlotsForProvider($serviceProvider);

            foreach ($slots as $slot) {
                TimeSlot::firstOrCreate(
                    [
                        'service_provider_id' => $serviceProvider->id,
                        'day_of_week' => $slot['day_of_week'],
                        'start_time' => $slot['start_time'],
                        'end_time' => $slot['end_time'],
                    ],
                    [
                        'service_provider_id' => $serviceProvider->id,
                        'day_of_week' => $slot['day_of_week'],
                        'start_time' => $slot['start_time'],
                        'end_time' => $slot['end_time'],
                        'is_active' => $slot['is_active'],
                    ]
                );
                $createdSlots++;
            }
        }

        $this->command->info("Time slots created: {$createdSlots}");
        $this->displayTimeSlotsTable($serviceProviders);
    }

    private function getTimeSlotsForProvider(ServiceProvider $serviceProvider): array
    {
        $email = $serviceProvider->user?->email ?? '';

        // Define different working patterns based on provider type
        return match (true) {
            // Plumber - works Sunday to Thursday, morning and afternoon shifts
            str_contains($email, 'plumber') => $this->getStandardWorkingHours(),

            // Electrician - works Saturday to Wednesday, morning shift only
            str_contains($email, 'electrician') => $this->getMorningOnlyHours(),

            // HVAC - works Sunday to Thursday, full day with break
            str_contains($email, 'hvac') => $this->getFullDayHours(),

            // Cleaner - works every day except Friday
            str_contains($email, 'cleaner') => $this->getCleanerHours(),

            // Carpenter - works Sunday to Thursday, morning and afternoon
            str_contains($email, 'carpenter') => $this->getStandardWorkingHours(),

            // General maintenance - works Sunday to Wednesday, afternoon shift
            str_contains($email, 'general') => $this->getAfternoonOnlyHours(),

            // Multi-skilled - works Sunday to Thursday, flexible hours
            str_contains($email, 'multi.skilled') => $this->getFlexibleHours(),

            // Pest control - works Saturday, Sunday, Monday, Tuesday only
            str_contains($email, 'pest') => $this->getPestControlHours(),

            // Landscape - works early morning Saturday to Wednesday
            str_contains($email, 'landscape') => $this->getLandscapeHours(),

            // Security - works 24/7 shifts (different pattern)
            str_contains($email, 'security') => $this->getSecurityHours(),

            // Default - standard working hours
            default => $this->getStandardWorkingHours(),
        };
    }

    private function getStandardWorkingHours(): array
    {
        $slots = [];
        // Sunday (0) to Thursday (4)
        for ($day = 0; $day <= 4; $day++) {
            // Morning shift: 08:00 - 12:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '08:00:00',
                'end_time' => '12:00:00',
                'is_active' => true,
            ];
            // Afternoon shift: 14:00 - 18:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '14:00:00',
                'end_time' => '18:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getMorningOnlyHours(): array
    {
        $slots = [];
        // Saturday (6), Sunday (0) to Wednesday (3)
        $days = [6, 0, 1, 2, 3];
        foreach ($days as $day) {
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '07:00:00',
                'end_time' => '13:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getAfternoonOnlyHours(): array
    {
        $slots = [];
        // Sunday (0) to Wednesday (3)
        for ($day = 0; $day <= 3; $day++) {
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '13:00:00',
                'end_time' => '20:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getFullDayHours(): array
    {
        $slots = [];
        // Sunday (0) to Thursday (4)
        for ($day = 0; $day <= 4; $day++) {
            // Morning: 07:00 - 11:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '07:00:00',
                'end_time' => '11:00:00',
                'is_active' => true,
            ];
            // Midday: 12:00 - 15:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '12:00:00',
                'end_time' => '15:00:00',
                'is_active' => true,
            ];
            // Evening: 16:00 - 19:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '16:00:00',
                'end_time' => '19:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getCleanerHours(): array
    {
        $slots = [];
        // Every day except Friday (5)
        for ($day = 0; $day <= 6; $day++) {
            if ($day === 5) {
                continue; // Skip Friday
            }
            // Morning: 06:00 - 10:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '06:00:00',
                'end_time' => '10:00:00',
                'is_active' => true,
            ];
            // Afternoon: 15:00 - 19:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '15:00:00',
                'end_time' => '19:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getFlexibleHours(): array
    {
        $slots = [];
        // Sunday (0) to Thursday (4)
        for ($day = 0; $day <= 4; $day++) {
            // Early morning: 06:00 - 09:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '06:00:00',
                'end_time' => '09:00:00',
                'is_active' => true,
            ];
            // Late morning: 10:00 - 13:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '10:00:00',
                'end_time' => '13:00:00',
                'is_active' => true,
            ];
            // Afternoon: 14:00 - 17:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '14:00:00',
                'end_time' => '17:00:00',
                'is_active' => true,
            ];
            // Evening: 18:00 - 21:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '18:00:00',
                'end_time' => '21:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getPestControlHours(): array
    {
        $slots = [];
        // Saturday (6), Sunday (0), Monday (1), Tuesday (2)
        $days = [6, 0, 1, 2];
        foreach ($days as $day) {
            // Morning: 08:00 - 12:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '08:00:00',
                'end_time' => '12:00:00',
                'is_active' => true,
            ];
            // Afternoon: 14:00 - 17:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '14:00:00',
                'end_time' => '17:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function getLandscapeHours(): array
    {
        $slots = [];
        // Saturday (6), Sunday (0) to Wednesday (3)
        $days = [6, 0, 1, 2, 3];
        foreach ($days as $day) {
            // Early morning: 05:00 - 09:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '05:00:00',
                'end_time' => '09:00:00',
                'is_active' => true,
            ];
            // Late morning: 10:00 - 12:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '10:00:00',
                'end_time' => '12:00:00',
                'is_active' => true,
            ];
        }
        // Add one inactive slot for testing
        $slots[] = [
            'day_of_week' => 4, // Thursday
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'is_active' => false,
        ];
        return $slots;
    }

    private function getSecurityHours(): array
    {
        $slots = [];
        // Every day
        for ($day = 0; $day <= 6; $day++) {
            // Morning shift: 06:00 - 14:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '06:00:00',
                'end_time' => '14:00:00',
                'is_active' => true,
            ];
            // Evening shift: 14:00 - 22:00
            $slots[] = [
                'day_of_week' => $day,
                'start_time' => '14:00:00',
                'end_time' => '22:00:00',
                'is_active' => true,
            ];
        }
        return $slots;
    }

    private function displayTimeSlotsTable($serviceProviders): void
    {
        $data = [];
        $dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        foreach ($serviceProviders as $sp) {
            $slots = $sp->timeSlots()->where('is_active', true)->get();
            if ($slots->isEmpty()) {
                continue;
            }

            $days = $slots->groupBy('day_of_week')
                ->map(fn ($daySlots) => $daySlots->count())
                ->toArray();

            $daysStr = collect($dayNames)
                ->mapWithKeys(fn ($name, $index) => [$name => $days[$index] ?? 0])
                ->filter(fn ($count) => $count > 0)
                ->map(fn ($count, $name) => "{$name}({$count})")
                ->join(', ');

            $data[] = [
                $sp->user?->name ?? 'Unknown',
                $slots->count(),
                $daysStr,
            ];
        }

        if (!empty($data)) {
            $this->command->table(
                ['Service Provider', 'Total Slots', 'Days (slots)'],
                $data
            );
        }
    }
}
