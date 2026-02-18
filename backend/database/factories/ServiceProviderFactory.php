<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ServiceProvider>
 */
class ServiceProviderFactory extends Factory
{
    protected $model = ServiceProvider::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory()->serviceProvider(),
            'category_id' => Category::factory(),
            'latitude' => fake()->latitude(),
            'longitude' => fake()->longitude(),
            'is_available' => true,
        ];
    }

    public function unavailable(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_available' => false,
        ]);
    }
}
