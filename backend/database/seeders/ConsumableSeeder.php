<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Consumable;
use Illuminate\Database\Seeder;

class ConsumableSeeder extends Seeder
{
    public function run(): void
    {
        $consumables = [
            'Plumbing' => [
                ['name_en' => 'Pipe Fittings', 'name_ar' => 'وصلات الأنابيب', 'is_active' => true],
                ['name_en' => 'Faucets', 'name_ar' => 'الصنابير', 'is_active' => true],
                ['name_en' => 'Washers', 'name_ar' => 'الحلقات المطاطية', 'is_active' => true],
                ['name_en' => 'Drain Cleaner', 'name_ar' => 'منظف المصارف', 'is_active' => true],
                ['name_en' => 'Plumber\'s Tape', 'name_ar' => 'شريط السباكة', 'is_active' => true],
                ['name_en' => 'PVC Pipes', 'name_ar' => 'أنابيب PVC', 'is_active' => true],
                ['name_en' => 'Toilet Flush Kit', 'name_ar' => 'طقم سيفون المرحاض', 'is_active' => true],
                ['name_en' => 'Water Heater Element', 'name_ar' => 'عنصر سخان الماء', 'is_active' => true],
                ['name_en' => 'Valve Sets', 'name_ar' => 'مجموعات الصمامات', 'is_active' => true],
                ['name_en' => 'Copper Pipes', 'name_ar' => 'أنابيب نحاسية', 'is_active' => true],
                ['name_en' => 'Pipe Insulation', 'name_ar' => 'عزل الأنابيب', 'is_active' => true],
                ['name_en' => 'Sink Strainers', 'name_ar' => 'مصافي المغاسل', 'is_active' => true],
                ['name_en' => 'Water Filters', 'name_ar' => 'فلاتر المياه', 'is_active' => true],
                ['name_en' => 'Shower Heads', 'name_ar' => 'رؤوس الدش', 'is_active' => true],
                ['name_en' => 'Bathroom Accessories', 'name_ar' => 'إكسسوارات الحمام', 'is_active' => true],
                ['name_en' => 'Old Style Fittings', 'name_ar' => 'وصلات قديمة', 'is_active' => false],
            ],
            'Electrical' => [
                ['name_en' => 'Light Bulbs', 'name_ar' => 'المصابيح', 'is_active' => true],
                ['name_en' => 'Switches', 'name_ar' => 'المفاتيح', 'is_active' => true],
                ['name_en' => 'Outlets', 'name_ar' => 'مآخذ الكهرباء', 'is_active' => true],
                ['name_en' => 'Wiring', 'name_ar' => 'الأسلاك', 'is_active' => true],
                ['name_en' => 'Circuit Breakers', 'name_ar' => 'قواطع الدائرة', 'is_active' => true],
                ['name_en' => 'LED Strips', 'name_ar' => 'شرائط LED', 'is_active' => true],
                ['name_en' => 'Junction Boxes', 'name_ar' => 'علب التوصيل', 'is_active' => true],
                ['name_en' => 'Wire Connectors', 'name_ar' => 'موصلات الأسلاك', 'is_active' => true],
                ['name_en' => 'Cable Clips', 'name_ar' => 'مشابك الكابلات', 'is_active' => true],
                ['name_en' => 'Electrical Tape', 'name_ar' => 'شريط كهربائي', 'is_active' => true],
                ['name_en' => 'Conduit Pipes', 'name_ar' => 'أنابيب التوصيل', 'is_active' => true],
                ['name_en' => 'Dimmers', 'name_ar' => 'منظمات الإضاءة', 'is_active' => true],
                ['name_en' => 'Timers', 'name_ar' => 'مؤقتات', 'is_active' => true],
                ['name_en' => 'Motion Sensors', 'name_ar' => 'مستشعرات الحركة', 'is_active' => true],
                ['name_en' => 'Extension Cords', 'name_ar' => 'أسلاك تمديد', 'is_active' => true],
                ['name_en' => 'Incandescent Bulbs', 'name_ar' => 'مصابيح متوهجة', 'is_active' => false],
            ],
            'HVAC' => [
                ['name_en' => 'Air Filters', 'name_ar' => 'فلاتر الهواء', 'is_active' => true],
                ['name_en' => 'Refrigerant', 'name_ar' => 'غاز التبريد', 'is_active' => true],
                ['name_en' => 'Thermostat', 'name_ar' => 'منظم الحرارة', 'is_active' => true],
                ['name_en' => 'Duct Tape', 'name_ar' => 'شريط القنوات', 'is_active' => true],
                ['name_en' => 'Compressor Oil', 'name_ar' => 'زيت الضاغط', 'is_active' => true],
                ['name_en' => 'Condensate Pump', 'name_ar' => 'مضخة التكثيف', 'is_active' => true],
                ['name_en' => 'Fan Motor', 'name_ar' => 'محرك المروحة', 'is_active' => true],
                ['name_en' => 'Capacitor', 'name_ar' => 'المكثف', 'is_active' => true],
                ['name_en' => 'Blower Wheel', 'name_ar' => 'عجلة النفخ', 'is_active' => true],
                ['name_en' => 'Evaporator Coils', 'name_ar' => 'ملفات التبخير', 'is_active' => true],
                ['name_en' => 'Condenser Coils', 'name_ar' => 'ملفات التكثيف', 'is_active' => true],
                ['name_en' => 'AC Remote Control', 'name_ar' => 'جهاز تحكم عن بعد', 'is_active' => true],
                ['name_en' => 'Insulation Material', 'name_ar' => 'مواد العزل', 'is_active' => true],
                ['name_en' => 'Drain Hose', 'name_ar' => 'خرطوم الصرف', 'is_active' => true],
                ['name_en' => 'Fan Blades', 'name_ar' => 'شفرات المروحة', 'is_active' => true],
            ],
            'Carpentry' => [
                ['name_en' => 'Nails', 'name_ar' => 'المسامير', 'is_active' => true],
                ['name_en' => 'Screws', 'name_ar' => 'البراغي', 'is_active' => true],
                ['name_en' => 'Wood Glue', 'name_ar' => 'غراء الخشب', 'is_active' => true],
                ['name_en' => 'Sandpaper', 'name_ar' => 'ورق الصنفرة', 'is_active' => true],
                ['name_en' => 'Hinges', 'name_ar' => 'المفصلات', 'is_active' => true],
                ['name_en' => 'Door Handles', 'name_ar' => 'مقابض الأبواب', 'is_active' => true],
                ['name_en' => 'Cabinet Knobs', 'name_ar' => 'مقابض الخزائن', 'is_active' => true],
                ['name_en' => 'Wood Filler', 'name_ar' => 'معجون الخشب', 'is_active' => true],
                ['name_en' => 'Wood Stain', 'name_ar' => 'صبغة الخشب', 'is_active' => true],
                ['name_en' => 'Drawer Slides', 'name_ar' => 'منزلقات الأدراج', 'is_active' => true],
                ['name_en' => 'Door Stops', 'name_ar' => 'موقفات الأبواب', 'is_active' => true],
                ['name_en' => 'L-Brackets', 'name_ar' => 'أقواس L', 'is_active' => true],
                ['name_en' => 'Wood Varnish', 'name_ar' => 'ورنيش الخشب', 'is_active' => true],
                ['name_en' => 'Corner Braces', 'name_ar' => 'دعامات الزوايا', 'is_active' => true],
                ['name_en' => 'Dowels', 'name_ar' => 'المسامير الخشبية', 'is_active' => true],
            ],
            'Painting' => [
                ['name_en' => 'Paint', 'name_ar' => 'الدهان', 'is_active' => true],
                ['name_en' => 'Primer', 'name_ar' => 'البرايمر', 'is_active' => true],
                ['name_en' => 'Brushes', 'name_ar' => 'الفرش', 'is_active' => true],
                ['name_en' => 'Rollers', 'name_ar' => 'البكرات', 'is_active' => true],
                ['name_en' => 'Painter\'s Tape', 'name_ar' => 'شريط الدهان', 'is_active' => true],
                ['name_en' => 'Paint Thinner', 'name_ar' => 'مخفف الدهان', 'is_active' => true],
                ['name_en' => 'Drop Cloths', 'name_ar' => 'أغطية الحماية', 'is_active' => true],
                ['name_en' => 'Putty', 'name_ar' => 'المعجون', 'is_active' => true],
                ['name_en' => 'Spray Paint', 'name_ar' => 'دهان بالرش', 'is_active' => true],
                ['name_en' => 'Wallpaper', 'name_ar' => 'ورق الجدران', 'is_active' => true],
                ['name_en' => 'Paint Trays', 'name_ar' => 'صواني الدهان', 'is_active' => true],
                ['name_en' => 'Caulk', 'name_ar' => 'سد الفراغات', 'is_active' => true],
                ['name_en' => 'Sealant', 'name_ar' => 'مانع التسرب', 'is_active' => true],
                ['name_en' => 'Stencils', 'name_ar' => 'القوالب', 'is_active' => true],
                ['name_en' => 'Paint Stripper', 'name_ar' => 'مزيل الدهان', 'is_active' => true],
            ],
            'Cleaning' => [
                ['name_en' => 'Cleaning Solution', 'name_ar' => 'محلول التنظيف', 'is_active' => true],
                ['name_en' => 'Mops', 'name_ar' => 'الممسحات', 'is_active' => true],
                ['name_en' => 'Sponges', 'name_ar' => 'الإسفنج', 'is_active' => true],
                ['name_en' => 'Garbage Bags', 'name_ar' => 'أكياس القمامة', 'is_active' => true],
                ['name_en' => 'Disinfectant', 'name_ar' => 'المطهر', 'is_active' => true],
                ['name_en' => 'Glass Cleaner', 'name_ar' => 'منظف الزجاج', 'is_active' => true],
                ['name_en' => 'Floor Cleaner', 'name_ar' => 'منظف الأرضيات', 'is_active' => true],
                ['name_en' => 'Microfiber Cloths', 'name_ar' => 'قماش الميكروفايبر', 'is_active' => true],
                ['name_en' => 'Broom', 'name_ar' => 'المكنسة', 'is_active' => true],
                ['name_en' => 'Vacuum Bags', 'name_ar' => 'أكياس المكنسة الكهربائية', 'is_active' => true],
                ['name_en' => 'Toilet Cleaner', 'name_ar' => 'منظف المرحاض', 'is_active' => true],
                ['name_en' => 'Bleach', 'name_ar' => 'مبيض', 'is_active' => true],
                ['name_en' => 'Deodorizer', 'name_ar' => 'مزيل الروائح', 'is_active' => true],
                ['name_en' => 'Scrubbing Brushes', 'name_ar' => 'فرش التنظيف', 'is_active' => true],
                ['name_en' => 'Rubber Gloves', 'name_ar' => 'قفازات مطاطية', 'is_active' => true],
            ],
            'General Maintenance' => [
                ['name_en' => 'Lubricant', 'name_ar' => 'زيت التشحيم', 'is_active' => true],
                ['name_en' => 'Adhesive Tape', 'name_ar' => 'الشريط اللاصق', 'is_active' => true],
                ['name_en' => 'Batteries', 'name_ar' => 'البطاريات', 'is_active' => true],
                ['name_en' => 'Silicone Sealant', 'name_ar' => 'مانع التسرب السيليكوني', 'is_active' => true],
                ['name_en' => 'Cable Ties', 'name_ar' => 'رباط الكابلات', 'is_active' => true],
                ['name_en' => 'Mounting Hardware', 'name_ar' => 'معدات التثبيت', 'is_active' => true],
                ['name_en' => 'WD-40', 'name_ar' => 'WD-40', 'is_active' => true],
                ['name_en' => 'Zip Ties', 'name_ar' => 'روابط بلاستيكية', 'is_active' => true],
                ['name_en' => 'Anchors & Bolts', 'name_ar' => 'مراسي وبراغي', 'is_active' => true],
                ['name_en' => 'Super Glue', 'name_ar' => 'صمغ قوي', 'is_active' => true],
                ['name_en' => 'Safety Goggles', 'name_ar' => 'نظارات السلامة', 'is_active' => true],
                ['name_en' => 'Work Gloves', 'name_ar' => 'قفازات العمل', 'is_active' => true],
                ['name_en' => 'Utility Knife', 'name_ar' => 'سكين متعددة الاستخدامات', 'is_active' => true],
                ['name_en' => 'Measuring Tape', 'name_ar' => 'شريط القياس', 'is_active' => true],
                ['name_en' => 'Level Tool', 'name_ar' => 'أداة التسوية', 'is_active' => true],
            ],
            'Pest Control' => [
                ['name_en' => 'Insecticide Spray', 'name_ar' => 'بخاخ المبيدات', 'is_active' => true],
                ['name_en' => 'Rodent Traps', 'name_ar' => 'مصائد القوارض', 'is_active' => true],
                ['name_en' => 'Gel Bait', 'name_ar' => 'الطعم الهلامي', 'is_active' => true],
                ['name_en' => 'Pest Control Powder', 'name_ar' => 'مسحوق مكافحة الآفات', 'is_active' => true],
                ['name_en' => 'Fumigation Tablets', 'name_ar' => 'أقراص التبخير', 'is_active' => true],
                ['name_en' => 'Glue Traps', 'name_ar' => 'مصائد لاصقة', 'is_active' => true],
                ['name_en' => 'Ant Baits', 'name_ar' => 'طعم النمل', 'is_active' => true],
                ['name_en' => 'Mosquito Repellent', 'name_ar' => 'طارد البعوض', 'is_active' => true],
                ['name_en' => 'Cockroach Killer', 'name_ar' => 'قاتل الصراصير', 'is_active' => true],
                ['name_en' => 'Termite Treatment', 'name_ar' => 'علاج النمل الأبيض', 'is_active' => true],
            ],
            'Landscaping' => [
                ['name_en' => 'Fertilizer', 'name_ar' => 'الأسمدة', 'is_active' => true],
                ['name_en' => 'Soil', 'name_ar' => 'التربة', 'is_active' => true],
                ['name_en' => 'Plant Seeds', 'name_ar' => 'بذور النباتات', 'is_active' => true],
                ['name_en' => 'Irrigation Pipes', 'name_ar' => 'أنابيب الري', 'is_active' => true],
                ['name_en' => 'Garden Tools', 'name_ar' => 'أدوات الحديقة', 'is_active' => true],
                ['name_en' => 'Mulch', 'name_ar' => 'النشارة', 'is_active' => true],
                ['name_en' => 'Grass Seeds', 'name_ar' => 'بذور العشب', 'is_active' => true],
                ['name_en' => 'Pesticides', 'name_ar' => 'مبيدات الآفات', 'is_active' => true],
                ['name_en' => 'Weed Killer', 'name_ar' => 'قاتل الأعشاب', 'is_active' => true],
                ['name_en' => 'Garden Hose', 'name_ar' => 'خرطوم الحديقة', 'is_active' => true],
                ['name_en' => 'Sprinklers', 'name_ar' => 'الرشاشات', 'is_active' => true],
                ['name_en' => 'Plant Food', 'name_ar' => 'غذاء النباتات', 'is_active' => true],
                ['name_en' => 'Compost', 'name_ar' => 'السماد العضوي', 'is_active' => true],
                ['name_en' => 'Planters', 'name_ar' => 'أحواض الزراعة', 'is_active' => true],
                ['name_en' => 'Pruning Shears', 'name_ar' => 'مقصات التقليم', 'is_active' => true],
            ],
            'Security' => [
                ['name_en' => 'Lock Cylinders', 'name_ar' => 'أسطوانات القفل', 'is_active' => true],
                ['name_en' => 'Door Chains', 'name_ar' => 'سلاسل الأبواب', 'is_active' => true],
                ['name_en' => 'Peepholes', 'name_ar' => 'عين الباب', 'is_active' => true],
                ['name_en' => 'Security Screws', 'name_ar' => 'براغي الأمان', 'is_active' => true],
                ['name_en' => 'Deadbolts', 'name_ar' => 'الأقفال المزدوجة', 'is_active' => true],
                ['name_en' => 'Padlocks', 'name_ar' => 'أقفال عادية', 'is_active' => true],
                ['name_en' => 'Door Alarms', 'name_ar' => 'إنذارات الأبواب', 'is_active' => true],
                ['name_en' => 'Window Locks', 'name_ar' => 'أقفال النوافذ', 'is_active' => true],
                ['name_en' => 'Security Cameras', 'name_ar' => 'كاميرات المراقبة', 'is_active' => true],
                ['name_en' => 'Motion Detectors', 'name_ar' => 'كاشفات الحركة', 'is_active' => true],
            ],
        ];

        $activeCount = 0;
        $inactiveCount = 0;

        foreach ($consumables as $categoryName => $items) {
            $category = Category::where('name_en', $categoryName)->first();

            if (! $category) {
                $this->command->warn("Category '{$categoryName}' not found. Skipping consumables.");

                continue;
            }

            foreach ($items as $item) {
                Consumable::firstOrCreate(
                    [
                        'category_id' => $category->id,
                        'name_en' => $item['name_en'],
                    ],
                    array_merge($item, ['category_id' => $category->id])
                );

                if ($item['is_active']) {
                    $activeCount++;
                } else {
                    $inactiveCount++;
                }
            }
        }

        $this->command->info("Consumables seeded: {$activeCount} active, {$inactiveCount} inactive");
    }
}
