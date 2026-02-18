<?php

declare(strict_types=1);

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\WorkType>
 */
class WorkTypeFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $workTypes = [
            ['name_en' => 'Bulb Replacement', 'name_ar' => 'استبدال المصباح', 'duration' => 30],
            ['name_en' => 'Light Fixture Installation', 'name_ar' => 'تركيب وحدة إضاءة', 'duration' => 60],
            ['name_en' => 'Minor Pipe Repair', 'name_ar' => 'إصلاح الأنابيب الصغيرة', 'duration' => 45],
            ['name_en' => 'Faucet Replacement', 'name_ar' => 'استبدال الصنبور', 'duration' => 60],
            ['name_en' => 'Door Lock Repair', 'name_ar' => 'إصلاح قفل الباب', 'duration' => 45],
            ['name_en' => 'Window Repair', 'name_ar' => 'إصلاح النافذة', 'duration' => 90],
            ['name_en' => 'AC Filter Replacement', 'name_ar' => 'استبدال فلتر المكيف', 'duration' => 30],
            ['name_en' => 'AC Cleaning', 'name_ar' => 'تنظيف المكيف', 'duration' => 120],
            ['name_en' => 'Paint Touch-up', 'name_ar' => 'طلاء تصحيحي', 'duration' => 90],
            ['name_en' => 'Wall Repair', 'name_ar' => 'إصلاح الجدار', 'duration' => 120],
        ];

        $type = fake()->randomElement($workTypes);

        return [
            'name_en' => $type['name_en'],
            'name_ar' => $type['name_ar'],
            'description_en' => fake()->optional()->sentence(),
            'description_ar' => fake()->optional()->sentence(),
            'duration_minutes' => $type['duration'],
            'is_active' => fake()->boolean(90), // 90% active
        ];
    }

    /**
     * Indicate that the work type is active.
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => true,
        ]);
    }

    /**
     * Indicate that the work type is inactive.
     */
    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => false,
        ]);
    }

    /**
     * Set a specific duration.
     */
    public function duration(int $minutes): static
    {
        return $this->state(fn (array $attributes) => [
            'duration_minutes' => $minutes,
        ]);
    }
}
