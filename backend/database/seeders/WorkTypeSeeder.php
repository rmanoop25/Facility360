<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Category;
use App\Models\WorkType;
use Illuminate\Database\Seeder;

class WorkTypeSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $workTypes = [
            // Electrical Work Types
            [
                'name_en' => 'Bulb Replacement',
                'name_ar' => 'استبدال المصباح',
                'description_en' => 'Replace faulty or burnt-out light bulbs',
                'description_ar' => 'استبدال المصابيح المعطلة أو المحترقة',
                'duration_minutes' => 30,
                'categories' => ['Electrical'],
            ],
            [
                'name_en' => 'Light Fixture Installation',
                'name_ar' => 'تركيب وحدة إضاءة',
                'description_en' => 'Install new light fixtures',
                'description_ar' => 'تركيب وحدات إضاءة جديدة',
                'duration_minutes' => 60,
                'categories' => ['Electrical'],
            ],
            [
                'name_en' => 'Socket Repair',
                'name_ar' => 'إصلاح المقبس',
                'description_en' => 'Repair or replace electrical sockets',
                'description_ar' => 'إصلاح أو استبدال المقابس الكهربائية',
                'duration_minutes' => 45,
                'categories' => ['Electrical'],
            ],
            [
                'name_en' => 'Switch Replacement',
                'name_ar' => 'استبدال المفتاح',
                'description_en' => 'Replace faulty electrical switches',
                'description_ar' => 'استبدال المفاتيح الكهربائية المعطلة',
                'duration_minutes' => 30,
                'categories' => ['Electrical'],
            ],

            // Plumbing Work Types
            [
                'name_en' => 'Faucet Replacement',
                'name_ar' => 'استبدال الصنبور',
                'description_en' => 'Replace damaged or leaking faucets',
                'description_ar' => 'استبدال الصنابير التالفة أو المسربة',
                'duration_minutes' => 60,
                'categories' => ['Plumbing'],
            ],
            [
                'name_en' => 'Pipe Leak Repair',
                'name_ar' => 'إصلاح تسرب الأنابيب',
                'description_en' => 'Repair minor pipe leaks',
                'description_ar' => 'إصلاح تسربات الأنابيب الصغيرة',
                'duration_minutes' => 90,
                'categories' => ['Plumbing'],
            ],
            [
                'name_en' => 'Drain Unclogging',
                'name_ar' => 'فتح الصرف المسدود',
                'description_en' => 'Clear clogged drains',
                'description_ar' => 'تنظيف المصارف المسدودة',
                'duration_minutes' => 60,
                'categories' => ['Plumbing'],
            ],
            [
                'name_en' => 'Toilet Repair',
                'name_ar' => 'إصلاح المرحاض',
                'description_en' => 'Fix toilet flushing or tank issues',
                'description_ar' => 'إصلاح مشاكل سيفون أو خزان المرحاض',
                'duration_minutes' => 75,
                'categories' => ['Plumbing'],
            ],

            // HVAC Work Types
            [
                'name_en' => 'AC Filter Replacement',
                'name_ar' => 'استبدال فلتر المكيف',
                'description_en' => 'Replace air conditioner filters',
                'description_ar' => 'استبدال فلاتر مكيف الهواء',
                'duration_minutes' => 30,
                'categories' => ['HVAC'],
            ],
            [
                'name_en' => 'AC Cleaning',
                'name_ar' => 'تنظيف المكيف',
                'description_en' => 'Deep cleaning of air conditioning units',
                'description_ar' => 'تنظيف عميق لوحدات تكييف الهواء',
                'duration_minutes' => 120,
                'categories' => ['HVAC'],
            ],
            [
                'name_en' => 'AC Gas Refill',
                'name_ar' => 'تعبئة غاز المكيف',
                'description_en' => 'Refill refrigerant gas in AC units',
                'description_ar' => 'تعبئة غاز التبريد في وحدات المكيف',
                'duration_minutes' => 90,
                'categories' => ['HVAC'],
            ],
            [
                'name_en' => 'Thermostat Adjustment',
                'name_ar' => 'ضبط منظم الحرارة',
                'description_en' => 'Calibrate and adjust thermostats',
                'description_ar' => 'معايرة وضبط منظمات الحرارة',
                'duration_minutes' => 45,
                'categories' => ['HVAC'],
            ],

            // Carpentry Work Types
            [
                'name_en' => 'Door Lock Repair',
                'name_ar' => 'إصلاح قفل الباب',
                'description_en' => 'Repair or replace door locks',
                'description_ar' => 'إصلاح أو استبدال أقفال الأبواب',
                'duration_minutes' => 45,
                'categories' => ['Carpentry'],
            ],
            [
                'name_en' => 'Door Adjustment',
                'name_ar' => 'ضبط الباب',
                'description_en' => 'Adjust door hinges and alignment',
                'description_ar' => 'ضبط مفصلات ومحاذاة الباب',
                'duration_minutes' => 60,
                'categories' => ['Carpentry'],
            ],
            [
                'name_en' => 'Window Repair',
                'name_ar' => 'إصلاح النافذة',
                'description_en' => 'Repair window frames and mechanisms',
                'description_ar' => 'إصلاح إطارات وآليات النوافذ',
                'duration_minutes' => 90,
                'categories' => ['Carpentry'],
            ],
            [
                'name_en' => 'Cabinet Repair',
                'name_ar' => 'إصلاح الخزانة',
                'description_en' => 'Fix cabinet doors and hinges',
                'description_ar' => 'إصلاح أبواب ومفصلات الخزائن',
                'duration_minutes' => 60,
                'categories' => ['Carpentry'],
            ],

            // Painting Work Types
            [
                'name_en' => 'Wall Paint Touch-up',
                'name_ar' => 'طلاء تصحيحي للجدار',
                'description_en' => 'Touch-up paint on walls',
                'description_ar' => 'طلاء تصحيحي على الجدران',
                'duration_minutes' => 90,
                'categories' => ['Painting'],
            ],
            [
                'name_en' => 'Full Room Painting',
                'name_ar' => 'طلاء غرفة كاملة',
                'description_en' => 'Paint entire room including walls and ceiling',
                'description_ar' => 'طلاء غرفة كاملة بما في ذلك الجدران والسقف',
                'duration_minutes' => 240,
                'categories' => ['Painting'],
            ],
            [
                'name_en' => 'Door Painting',
                'name_ar' => 'طلاء الباب',
                'description_en' => 'Paint door surfaces',
                'description_ar' => 'طلاء أسطح الأبواب',
                'duration_minutes' => 120,
                'categories' => ['Painting'],
            ],

            // General Maintenance Work Types
            [
                'name_en' => 'Wall Crack Repair',
                'name_ar' => 'إصلاح شقوق الجدار',
                'description_en' => 'Fill and repair wall cracks',
                'description_ar' => 'ملء وإصلاح شقوق الجدار',
                'duration_minutes' => 120,
                'categories' => ['General Maintenance'],
            ],
            [
                'name_en' => 'Floor Tile Replacement',
                'name_ar' => 'استبدال بلاط الأرضية',
                'description_en' => 'Replace broken or damaged floor tiles',
                'description_ar' => 'استبدال بلاط الأرضية المكسور أو التالف',
                'duration_minutes' => 180,
                'categories' => ['General Maintenance'],
            ],
            [
                'name_en' => 'Ceiling Repair',
                'name_ar' => 'إصلاح السقف',
                'description_en' => 'Repair ceiling damage or leaks',
                'description_ar' => 'إصلاح تلف أو تسريبات السقف',
                'duration_minutes' => 150,
                'categories' => ['General Maintenance'],
            ],
        ];

        foreach ($workTypes as $workTypeData) {
            $categoryNames = $workTypeData['categories'];
            unset($workTypeData['categories']);

            // Create work type
            $workType = WorkType::create(array_merge($workTypeData, ['is_active' => true]));

            // Attach to categories
            $categories = Category::whereIn('name_en', $categoryNames)->get();
            if ($categories->isNotEmpty()) {
                $workType->categories()->attach($categories->pluck('id'));
            }
        }

        $this->command->info('Work types seeded successfully!');
    }
}
