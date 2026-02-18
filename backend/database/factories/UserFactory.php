<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
            'profile_photo' => $this->getRandomProfilePhoto(),
        ];
    }

    /**
     * Get a random profile photo (default - uses tenant photos)
     */
    private function getRandomProfilePhoto(): string
    {
        $photos = [
            'profiles/tenants/tenant-1.jpg',
            'profiles/tenants/tenant-2.jpg',
            'profiles/tenants/tenant-3.jpg',
        ];

        return $photos[array_rand($photos)];
    }

    /**
     * State for service provider users
     */
    public function serviceProvider(): static
    {
        return $this->state(fn (array $attributes) => [
            'profile_photo' => $this->getServiceProviderPhoto(),
        ]);
    }

    /**
     * Get a random service provider photo
     */
    private function getServiceProviderPhoto(): string
    {
        $photos = [
            'profiles/service-providers/sp-1.jpg',
            'profiles/service-providers/sp-2.png',
            'profiles/service-providers/sp-3.png',
            'profiles/service-providers/sp-4.png',
        ];

        return $photos[array_rand($photos)];
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
