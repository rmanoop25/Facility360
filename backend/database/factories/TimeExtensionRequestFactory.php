<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\ExtensionStatus;
use App\Models\IssueAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\TimeExtensionRequest>
 */
class TimeExtensionRequestFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $reasons = [
            'Additional work discovered during inspection',
            'Need more time to ensure quality',
            'Unexpected complexity in the repair',
            'Waiting for additional parts',
            'Multiple issues found that need attention',
            'Complex problem requiring extra troubleshooting',
        ];

        return [
            'assignment_id' => IssueAssignment::factory(),
            'requested_by' => User::factory(),
            'requested_minutes' => fake()->randomElement([15, 30, 45, 60, 90, 120]),
            'reason' => fake()->randomElement($reasons),
            'status' => ExtensionStatus::PENDING,
            'responded_by' => null,
            'admin_notes' => null,
            'requested_at' => now(),
            'responded_at' => null,
        ];
    }

    /**
     * Indicate that the extension request is pending.
     */
    public function pending(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => ExtensionStatus::PENDING,
            'responded_by' => null,
            'admin_notes' => null,
            'responded_at' => null,
        ]);
    }

    /**
     * Indicate that the extension request is approved.
     */
    public function approved(?int $respondedBy = null, ?string $notes = null): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => ExtensionStatus::APPROVED,
            'responded_by' => $respondedBy ?? User::factory(),
            'admin_notes' => $notes ?? 'Approved due to valid reason',
            'responded_at' => now(),
        ]);
    }

    /**
     * Indicate that the extension request is rejected.
     */
    public function rejected(?int $respondedBy = null, ?string $notes = null): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => ExtensionStatus::REJECTED,
            'responded_by' => $respondedBy ?? User::factory(),
            'admin_notes' => $notes ?? 'Cannot approve additional time for this task',
            'responded_at' => now(),
        ]);
    }
}
