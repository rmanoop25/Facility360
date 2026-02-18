<?php

return [
    'singular' => 'تعيين',
    'plural' => 'التعيينات',

    'sections' => [
        'details' => 'تفاصيل التعيين',
        'timestamps' => 'الطوابع الزمنية',
        'proofs' => 'الإثباتات',
        'consumables' => 'المستهلكات المستخدمة',
    ],

    'fields' => [
        'service_provider' => 'مزود الخدمة',
        'category' => 'الفئة',
        'time_slot' => 'الفترة الزمنية',
        'time_slots' => 'الفترات الزمنية',
        'scheduled_date' => 'التاريخ المحدد',
        'assigned_start_time' => 'وقت البدء',
        'assigned_end_time' => 'وقت الانتهاء',
        'assigned_time' => 'الوقت المحدد',
        'total_duration' => 'المدة الإجمالية',
        'status' => 'الحالة',
        'notes' => 'ملاحظات',
        'started_at' => 'تاريخ البدء',
        'held_at' => 'تاريخ الإيقاف',
        'resumed_at' => 'تاريخ الاستئناف',
        'finished_at' => 'تاريخ الانتهاء',
        'completed_at' => 'تاريخ الإكمال',
        'quantity' => 'الكمية',
    ],

    'status' => [
        'assigned' => 'معين',
        'in_progress' => 'قيد التنفيذ',
        'on_hold' => 'معلق',
        'finished' => 'منتهي',
        'completed' => 'مكتمل',
    ],

    'filters' => [
        'status' => 'الحالة',
    ],

    'not_found' => 'لم يتم العثور على التعيين.',
    'cannot_edit_started' => 'لا يمكن تعديل التعيين بعد بدء العمل.',
    'updated' => 'تم تحديث التعيين بنجاح.',
    'auto_calculated' => 'محسوب تلقائيًا',
];
