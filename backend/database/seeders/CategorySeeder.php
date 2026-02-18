<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $this->createRootCategories();
        $this->createSubcategories();

        $totalCategories = Category::count();
        $activeCount = Category::where('is_active', true)->count();
        $inactiveCount = Category::where('is_active', false)->count();

        $this->command->info("Categories seeded: {$totalCategories} total ({$activeCount} active, {$inactiveCount} inactive)");
    }

    private function createRootCategories(): void
    {
        $rootCategories = [
            ['name_en' => 'Plumbing', 'name_ar' => 'السباكة', 'icon' => 'heroicon-o-wrench', 'is_active' => true],
            ['name_en' => 'Electrical', 'name_ar' => 'الكهرباء', 'icon' => 'heroicon-o-bolt', 'is_active' => true],
            ['name_en' => 'HVAC', 'name_ar' => 'التكييف والتهوية', 'icon' => 'heroicon-o-sun', 'is_active' => true],
            ['name_en' => 'Carpentry', 'name_ar' => 'النجارة', 'icon' => 'heroicon-o-home', 'is_active' => true],
            ['name_en' => 'Painting', 'name_ar' => 'الدهان', 'icon' => 'heroicon-o-paint-brush', 'is_active' => true],
            ['name_en' => 'Cleaning', 'name_ar' => 'التنظيف', 'icon' => 'heroicon-o-sparkles', 'is_active' => true],
            ['name_en' => 'General Maintenance', 'name_ar' => 'الصيانة العامة', 'icon' => 'heroicon-o-cog', 'is_active' => true],
            ['name_en' => 'Pest Control', 'name_ar' => 'مكافحة الآفات', 'icon' => 'heroicon-o-bug-ant', 'is_active' => true],
            ['name_en' => 'Landscaping', 'name_ar' => 'تنسيق الحدائق', 'icon' => 'heroicon-o-scissors', 'is_active' => true],
            ['name_en' => 'Security', 'name_ar' => 'الأمن', 'icon' => 'heroicon-o-shield-check', 'is_active' => true],
            ['name_en' => 'Swimming Pool', 'name_ar' => 'حمام السباحة', 'icon' => 'heroicon-o-beaker', 'is_active' => true],
            ['name_en' => 'Elevator Maintenance', 'name_ar' => 'صيانة المصاعد', 'icon' => 'heroicon-o-arrow-up', 'is_active' => true],
            ['name_en' => 'Flooring', 'name_ar' => 'الأرضيات', 'icon' => 'heroicon-o-cube', 'is_active' => true],
            ['name_en' => 'Roofing', 'name_ar' => 'الأسقف', 'icon' => 'heroicon-o-building-office', 'is_active' => true],
            ['name_en' => 'Appliance Repair', 'name_ar' => 'إصلاح الأجهزة', 'icon' => 'heroicon-o-wrench-screwdriver', 'is_active' => true],
        ];

        foreach ($rootCategories as $categoryData) {
            Category::firstOrCreate(
                ['name_en' => $categoryData['name_en']],
                $categoryData
            );
        }
    }

    private function createSubcategories(): void
    {
        // Level 1 and 2 and 3 subcategories
        $subcategories = [
            'Plumbing' => [
                'Water Supply' => ['Hot Water Systems', 'Cold Water Systems', 'Water Pressure Issues'],
                'Drainage' => ['Sink Drainage', 'Toilet Drainage', 'Floor Drainage'],
                'Fixtures' => ['Faucets', 'Showers', 'Toilets'],
            ],
            'Electrical' => [
                'Lighting' => ['Indoor Lighting', 'Outdoor Lighting', 'Emergency Lighting'],
                'Wiring' => ['Main Wiring', 'Circuit Breakers', 'Power Outlets'],
                'Appliances' => ['Kitchen Appliances', 'Laundry Appliances', 'Heating Appliances'],
            ],
            'HVAC' => [
                'Air Conditioning' => ['Split AC', 'Central AC', 'Window AC'],
                'Ventilation' => ['Exhaust Fans', 'Air Ducts', 'Air Quality'],
                'Heating' => ['Water Heaters', 'Space Heaters', 'Central Heating'],
            ],
            'Carpentry' => [
                'Doors' => ['Main Doors', 'Interior Doors', 'Door Frames'],
                'Windows' => ['Window Frames', 'Window Screens', 'Window Locks'],
                'Furniture' => ['Built-in Cabinets', 'Shelving', 'Custom Furniture'],
            ],
            'Painting' => [
                'Interior Painting' => ['Wall Painting', 'Ceiling Painting', 'Trim Painting'],
                'Exterior Painting' => ['Building Facade', 'Balcony', 'Gates & Fences'],
            ],
            'Cleaning' => [
                'Regular Cleaning' => ['Daily Cleaning', 'Weekly Cleaning', 'Monthly Cleaning'],
                'Deep Cleaning' => ['Carpet Cleaning', 'Upholstery Cleaning', 'Window Cleaning'],
                'Specialized Cleaning' => ['Post-Construction', 'Move-in/Move-out', 'Disinfection'],
            ],
        ];

        foreach ($subcategories as $parentName => $level1) {
            $parent = Category::where('name_en', $parentName)->first();

            if (! $parent) {
                continue;
            }

            foreach ($level1 as $level1Name => $level2Items) {
                $level1Category = Category::firstOrCreate(
                    ['name_en' => $level1Name, 'parent_id' => $parent->id],
                    [
                        'name_en' => $level1Name,
                        'name_ar' => $this->translateToArabic($level1Name),
                        'parent_id' => $parent->id,
                        'icon' => $parent->icon,
                        'is_active' => true,
                    ]
                );

                foreach ($level2Items as $level2Name) {
                    Category::firstOrCreate(
                        ['name_en' => $level2Name, 'parent_id' => $level1Category->id],
                        [
                            'name_en' => $level2Name,
                            'name_ar' => $this->translateToArabic($level2Name),
                            'parent_id' => $level1Category->id,
                            'icon' => $parent->icon,
                            'is_active' => true,
                        ]
                    );
                }
            }
        }
    }

    private function translateToArabic(string $english): string
    {
        // Simplified Arabic translations (in production, use a proper translation service)
        $translations = [
            'Water Supply' => 'إمدادات المياه',
            'Hot Water Systems' => 'أنظمة المياه الساخنة',
            'Cold Water Systems' => 'أنظمة المياه الباردة',
            'Water Pressure Issues' => 'مشاكل ضغط المياه',
            'Drainage' => 'الصرف الصحي',
            'Sink Drainage' => 'تصريف المغسلة',
            'Toilet Drainage' => 'تصريف المرحاض',
            'Floor Drainage' => 'تصريف الأرضية',
            'Fixtures' => 'التركيبات',
            'Faucets' => 'الصنابير',
            'Showers' => 'الدشات',
            'Toilets' => 'المراحيض',
            'Lighting' => 'الإضاءة',
            'Indoor Lighting' => 'الإضاءة الداخلية',
            'Outdoor Lighting' => 'الإضاءة الخارجية',
            'Emergency Lighting' => 'إضاءة الطوارئ',
            'Wiring' => 'الأسلاك',
            'Main Wiring' => 'الأسلاك الرئيسية',
            'Circuit Breakers' => 'قواطع الدائرة',
            'Power Outlets' => 'مآخذ الكهرباء',
            'Appliances' => 'الأجهزة',
            'Kitchen Appliances' => 'أجهزة المطبخ',
            'Laundry Appliances' => 'أجهزة الغسيل',
            'Heating Appliances' => 'أجهزة التدفئة',
            'Air Conditioning' => 'تكييف الهواء',
            'Split AC' => 'مكيف سبليت',
            'Central AC' => 'مكيف مركزي',
            'Window AC' => 'مكيف شباك',
            'Ventilation' => 'التهوية',
            'Exhaust Fans' => 'مراوح الشفط',
            'Air Ducts' => 'قنوات الهواء',
            'Air Quality' => 'جودة الهواء',
            'Heating' => 'التدفئة',
            'Water Heaters' => 'سخانات المياه',
            'Space Heaters' => 'سخانات الفضاء',
            'Central Heating' => 'التدفئة المركزية',
            'Doors' => 'الأبواب',
            'Main Doors' => 'الأبواب الرئيسية',
            'Interior Doors' => 'الأبواب الداخلية',
            'Door Frames' => 'إطارات الأبواب',
            'Windows' => 'النوافذ',
            'Window Frames' => 'إطارات النوافذ',
            'Window Screens' => 'شبكات النوافذ',
            'Window Locks' => 'أقفال النوافذ',
            'Furniture' => 'الأثاث',
            'Built-in Cabinets' => 'خزائن مدمجة',
            'Shelving' => 'الأرفف',
            'Custom Furniture' => 'أثاث مخصص',
            'Interior Painting' => 'الدهان الداخلي',
            'Wall Painting' => 'دهان الجدران',
            'Ceiling Painting' => 'دهان الأسقف',
            'Trim Painting' => 'دهان الزخارف',
            'Exterior Painting' => 'الدهان الخارجي',
            'Building Facade' => 'واجهة المبنى',
            'Balcony' => 'الشرفة',
            'Gates & Fences' => 'البوابات والأسوار',
            'Regular Cleaning' => 'التنظيف العادي',
            'Daily Cleaning' => 'التنظيف اليومي',
            'Weekly Cleaning' => 'التنظيف الأسبوعي',
            'Monthly Cleaning' => 'التنظيف الشهري',
            'Deep Cleaning' => 'التنظيف العميق',
            'Carpet Cleaning' => 'تنظيف السجاد',
            'Upholstery Cleaning' => 'تنظيف المفروشات',
            'Window Cleaning' => 'تنظيف النوافذ',
            'Specialized Cleaning' => 'التنظيف المتخصص',
            'Post-Construction' => 'ما بعد البناء',
            'Move-in/Move-out' => 'الانتقال',
            'Disinfection' => 'التعقيم',
        ];

        return $translations[$english] ?? $english;
    }
}
