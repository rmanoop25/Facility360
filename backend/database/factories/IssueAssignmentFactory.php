<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\AssignmentStatus;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\ServiceProvider;
use App\Models\TimeSlot;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<IssueAssignment>
 */
class IssueAssignmentFactory extends Factory
{
    protected $model = IssueAssignment::class;

    public function definition(): array
    {
        return [
            'issue_id' => Issue::factory(),
            'service_provider_id' => ServiceProvider::factory(),
            'category_id' => Category::factory(),
            'time_slot_id' => null,
            'scheduled_date' => fake()->dateTimeBetween('now', '+7 days'),
            'status' => AssignmentStatus::ASSIGNED,
            'proof_required' => true,
            'started_at' => null,
            'held_at' => null,
            'resumed_at' => null,
            'finished_at' => null,
            'completed_at' => null,
            'notes' => null,
        ];
    }

    public function assigned(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => AssignmentStatus::ASSIGNED,
        ]);
    }

    public function inProgress(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => AssignmentStatus::IN_PROGRESS,
            'started_at' => now(),
        ]);
    }

    public function onHold(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => AssignmentStatus::ON_HOLD,
            'started_at' => now()->subHour(),
            'held_at' => now(),
        ]);
    }

    public function finished(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => AssignmentStatus::FINISHED,
            'started_at' => now()->subHours(2),
            'finished_at' => now(),
        ]);
    }

    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => AssignmentStatus::COMPLETED,
            'started_at' => now()->subHours(3),
            'finished_at' => now()->subHour(),
            'completed_at' => now(),
        ]);
    }
}
