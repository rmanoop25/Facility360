<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<TimeSlot>
 */
class TimeSlotFactory extends Factory
{
    protected $model = TimeSlot::class;

    public function definition(): array
    {
        $startHour = fake()->numberBetween(8, 16);

        return [
            'service_provider_id' => ServiceProvider::factory(),
            'day_of_week' => fake()->numberBetween(0, 6),
            'start_time' => sprintf('%02d:00:00', $startHour),
            'end_time' => sprintf('%02d:00:00', $startHour + 1),
            'is_active' => true,
        ];
    }

    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => false,
        ]);
    }

    public function forDay(int $dayOfWeek): static
    {
        return $this->state(fn (array $attributes) => [
            'day_of_week' => $dayOfWeek,
        ]);
    }

    public function morning(): static
    {
        return $this->state(fn (array $attributes) => [
            'start_time' => '09:00:00',
            'end_time' => '12:00:00',
        ]);
    }

    public function afternoon(): static
    {
        return $this->state(fn (array $attributes) => [
            'start_time' => '14:00:00',
            'end_time' => '17:00:00',
        ]);
    }
}
