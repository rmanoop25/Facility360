<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Tenant>
 */
class TenantFactory extends Factory
{
    protected $model = Tenant::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'unit_number' => fake()->bothify('??-###'),
            'building_name' => fake()->company() . ' Tower',
        ];
    }
}
