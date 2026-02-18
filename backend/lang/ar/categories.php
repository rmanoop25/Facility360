<?php

return [
    'title' => 'الفئات',
    'singular' => 'فئة',
    'plural' => 'الفئات',

    'sections' => [
        'basic_info' => 'المعلومات الأساسية',
    ],

    'fields' => [
        'name' => 'الاسم',
        'name_en' => 'الاسم (إنجليزي)',
        'name_ar' => 'الاسم (عربي)',
        'icon' => 'الأيقونة',
        'icon_help' => 'أدخل اسم أيقونة Heroicon (مثال: heroicon-o-wrench)',
        'is_active' => 'نشط',
        'is_active_help' => 'إلغاء التفعيل سيؤدي أيضًا إلى إلغاء تفعيل جميع الفئات الفرعية',
        'sort_order' => 'ترتيب الفرز',
        'consumables_count' => 'المستهلكات',
        'service_providers_count' => 'مزودو الخدمات',
        'created_at' => 'تاريخ الإنشاء',
        'updated_at' => 'تاريخ التحديث',
        // Hierarchy fields
        'parent' => 'الفئة الأم',
        'no_parent' => 'لا يوجد (فئة رئيسية)',
        'parent_help' => 'اختر فئة أم لإنشاء فئة فرعية',
        'depth' => 'المستوى',
        'full_path' => 'المسار الكامل',
        'children_count' => 'الفئات الفرعية',
    ],

    'filters' => [
        'active' => 'حالة النشاط',
        'has_consumables' => 'لديه مستهلكات',
        'has_service_providers' => 'لديه مزودو خدمات',
        'has_children' => 'لديه فئات فرعية',
        'roots_only' => 'الفئات الرئيسية فقط',
        'depth' => 'مستوى العمق',
        'parent' => 'الفئة الأم',
    ],

    'depth_options' => [
        'root' => 'رئيسي (المستوى 0)',
        'level_1' => 'المستوى 1',
        'level_2' => 'المستوى 2',
        'level_3_plus' => 'المستوى 3+',
    ],

    'depth_level' => 'المستوى :level',
    'level' => 'م:level',

    'actions' => [
        'activate' => 'تفعيل',
        'deactivate' => 'إلغاء التفعيل',
        'archive' => 'أرشفة',
        'restore' => 'استعادة',
        'view_children' => 'عرض الفئات الفرعية',
    ],

    'messages' => [
        'created' => 'تم إنشاء الفئة بنجاح',
        'updated' => 'تم تحديث الفئة بنجاح',
        'deleted' => 'تم حذف الفئة بنجاح',
    ],

    // Archive/Restore messages
    'archive_heading' => 'أرشفة الفئة',
    'archive_warning' => 'سيتم أرشفة هذه الفئة وإخفاؤها عن المستخدمين.',
    'archive_warning_with_children' => 'سيتم أرشفة هذه الفئة و :count فئة فرعية.',
    'archived_successfully' => 'تم أرشفة الفئة بنجاح',
    'restored_successfully' => 'تم استعادة الفئة بنجاح',
    'not_archived' => 'هذه الفئة ليست مؤرشفة',
    'bulk_archive_warning' => 'سيتم أرشفة الفئات المحددة وفئاتها الفرعية.',
    'bulk_deactivate_warning' => 'سيتم إلغاء تفعيل الفئات المحددة وفئاتها الفرعية.',

    // Deactivation messages
    'deactivate_warning_with_children' => 'سيتم أيضًا إلغاء تفعيل :count فئة فرعية.',

    // Validation messages
    'cannot_be_own_parent' => 'لا يمكن للفئة أن تكون أمًا لنفسها.',
    'cannot_move_to_descendant' => 'لا يمكن نقل فئة إلى أحد فروعها.',

    // API messages
    'created_successfully' => 'تم إنشاء الفئة بنجاح',
    'updated_successfully' => 'تم تحديث الفئة بنجاح',
    'archived_successfully' => 'تم أرشفة الفئة بنجاح',
    'restored_successfully' => 'تم استعادة الفئة بنجاح',
    'moved_successfully' => 'تم نقل الفئة بنجاح',
    'not_found' => 'الفئة غير موجودة',
    'has_consumables' => 'لا يمكن أرشفة فئة تحتوي على :count مستهلكات',
    'has_service_providers' => 'لا يمكن أرشفة فئة تحتوي على :count مزودي خدمات',
    'has_issues' => 'لا يمكن أرشفة فئة تحتوي على :count مشكلات',
];
