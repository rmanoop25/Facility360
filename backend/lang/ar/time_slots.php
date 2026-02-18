<?php

return [
    'singular' => 'فترة زمنية',
    'plural' => 'الفترات الزمنية',

    'sections' => [
        'quick_setup' => 'إعداد سريع',
        'quick_setup_description' => 'حدد الأيام وطبّق نفس ساعات العمل على جميعها دفعة واحدة.',
        'weekly_schedule' => 'الجدول الأسبوعي',
        'weekly_schedule_description' => 'عرض وتعديل جداول الأيام الفردية أدناه.',
    ],

    'fields' => [
        'day_of_week' => 'اليوم',
        'start_time' => 'وقت البداية',
        'end_time' => 'وقت النهاية',
        'time_range' => 'نطاق الوقت',
        'is_active' => 'نشط',
        'is_full_day' => 'يوم كامل',
        'select_days' => 'اختر الأيام',
    ],

    'filters' => [
        'day' => 'اليوم',
        'active' => 'حالة النشاط',
    ],

    'presets' => [
        'weekdays' => 'أيام الأسبوع',
        'weekend' => 'نهاية الأسبوع',
        'all_week' => 'كل الأسبوع',
    ],

    'actions' => [
        'activate' => 'تفعيل',
        'deactivate' => 'إلغاء التفعيل',
        'add_slot' => 'إضافة فترة زمنية',
        'new_slot' => 'فترة زمنية جديدة',
        'apply_to_selected' => 'تطبيق على الأيام المحددة',
        'clear_all' => 'مسح الكل',
    ],

    'messages' => [
        'no_days_selected' => 'يرجى تحديد يوم واحد على الأقل.',
        'applied_successfully' => 'تم تطبيق الفترات الزمنية بنجاح.',
        'select_time_first' => 'يرجى تحديد وقت البداية والنهاية أولاً.',
        'cleared_successfully' => 'تم مسح جميع الفترات الزمنية.',
    ],

    'status' => [
        'configured' => 'تم التكوين',
        'not_configured' => 'غير مكوّن',
    ],
];
