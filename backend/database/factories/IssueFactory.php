<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Models\Issue;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Issue>
 */
class IssueFactory extends Factory
{
    protected $model = Issue::class;

    public function definition(): array
    {
        return [
            'tenant_id' => Tenant::factory(),
            'title' => fake()->sentence(4),
            'description' => fake()->paragraph(3),
            'status' => IssueStatus::PENDING,
            'priority' => fake()->randomElement(IssuePriority::cases()),
            'latitude' => fake()->optional(0.7)->latitude(),
            'longitude' => fake()->optional(0.7)->longitude(),
            'proof_required' => true,
            'cancelled_reason' => null,
            'cancelled_by' => null,
            'cancelled_at' => null,
        ];
    }

    public function pending(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::PENDING,
        ]);
    }

    public function assigned(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::ASSIGNED,
        ]);
    }

    public function inProgress(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::IN_PROGRESS,
        ]);
    }

    public function onHold(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::ON_HOLD,
        ]);
    }

    public function finished(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::FINISHED,
        ]);
    }

    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::COMPLETED,
        ]);
    }

    public function cancelled(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => IssueStatus::CANCELLED,
            'cancelled_reason' => fake()->sentence(),
            'cancelled_at' => now(),
        ]);
    }

    public function highPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => IssuePriority::HIGH,
        ]);
    }

    public function mediumPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => IssuePriority::MEDIUM,
        ]);
    }

    public function lowPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => IssuePriority::LOW,
        ]);
    }

    public function withLocation(float $latitude = null, float $longitude = null): static
    {
        return $this->state(fn (array $attributes) => [
            'latitude' => $latitude ?? fake()->latitude(),
            'longitude' => $longitude ?? fake()->longitude(),
        ]);
    }

    public function withoutLocation(): static
    {
        return $this->state(fn (array $attributes) => [
            'latitude' => null,
            'longitude' => null,
        ]);
    }
}
