<?php

return [
    // General
    'tenant_only' => 'هذا الإجراء متاح للمستأجرين فقط.',
    'service_provider_only' => 'هذا الإجراء متاح لمقدمي الخدمة فقط.',

    // Issues
    'issues' => [
        'list_success' => 'تم جلب المشكلات بنجاح.',
        'show_success' => 'تم جلب تفاصيل المشكلة بنجاح.',
        'created_success' => 'تم إنشاء المشكلة بنجاح.',
        'admin_created_success' => 'تم إنشاء المشكلة بنجاح نيابة عن المستأجر.',
        'created_by_admin' => 'تم الإنشاء بواسطة :admin نيابة عن المستأجر.',
        'create_failed' => 'فشل في إنشاء المشكلة.',
        'cancelled_success' => 'تم إلغاء المشكلة بنجاح.',
        'cancel_failed' => 'فشل في إلغاء المشكلة.',
        'cannot_cancel' => 'لا يمكن إلغاء هذه المشكلة.',
        'not_found' => 'المشكلة غير موجودة.',
    ],

    // Assignments
    'assignments' => [
        'list_success' => 'تم جلب المهام بنجاح.',
        'show_success' => 'تم جلب تفاصيل المهمة بنجاح.',
        'not_found' => 'المهمة غير موجودة.',
        'cannot_start' => 'لا يمكن بدء هذه المهمة.',
        'started_success' => 'تم بدء العمل بنجاح.',
        'start_failed' => 'فشل في بدء العمل.',
        'cannot_hold' => 'لا يمكن تعليق هذه المهمة.',
        'held_success' => 'تم تعليق المهمة بنجاح.',
        'hold_failed' => 'فشل في تعليق المهمة.',
        'cannot_resume' => 'لا يمكن استئناف هذه المهمة.',
        'resumed_success' => 'تم استئناف العمل بنجاح.',
        'resume_failed' => 'فشل في استئناف العمل.',
        'cannot_finish' => 'لا يمكن إنهاء هذه المهمة.',
        'finished_success' => 'تم إكمال العمل بنجاح.',
        'finish_failed' => 'فشل في إكمال العمل.',
        'proof_required' => 'مطلوب إثبات الإنجاز.',
    ],

    // Categories
    'categories' => [
        'list_success' => 'تم جلب الفئات بنجاح.',
        'show_success' => 'تم جلب تفاصيل الفئة بنجاح.',
        'created_success' => 'تم إنشاء الفئة بنجاح.',
        'create_failed' => 'فشل في إنشاء الفئة.',
        'updated_success' => 'تم تحديث الفئة بنجاح.',
        'update_failed' => 'فشل في تحديث الفئة.',
        'deleted_success' => 'تم حذف الفئة بنجاح.',
        'delete_failed' => 'فشل في حذف الفئة.',
        'not_found' => 'الفئة غير موجودة.',
        'in_use' => 'لا يمكن حذف فئة قيد الاستخدام.',
    ],

    // Consumables
    'consumables' => [
        'list_success' => 'تم جلب المستهلكات بنجاح.',
        'show_success' => 'تم جلب تفاصيل المستهلك بنجاح.',
        'created_success' => 'تم إنشاء المستهلك بنجاح.',
        'create_failed' => 'فشل في إنشاء المستهلك.',
        'updated_success' => 'تم تحديث المستهلك بنجاح.',
        'update_failed' => 'فشل في تحديث المستهلك.',
        'deleted_success' => 'تم حذف المستهلك بنجاح.',
        'delete_failed' => 'فشل في حذف المستهلك.',
        'not_found' => 'المستهلك غير موجود.',
    ],

    // Tenants
    'tenants' => [
        'list_success' => 'تم جلب المستأجرين بنجاح.',
        'show_success' => 'تم جلب تفاصيل المستأجر بنجاح.',
        'created_success' => 'تم إنشاء المستأجر بنجاح.',
        'create_failed' => 'فشل في إنشاء المستأجر.',
        'updated_success' => 'تم تحديث المستأجر بنجاح.',
        'update_failed' => 'فشل في تحديث المستأجر.',
        'deleted_success' => 'تم حذف المستأجر بنجاح.',
        'delete_failed' => 'فشل في حذف المستأجر.',
        'not_found' => 'المستأجر غير موجود.',
    ],

    // Service Providers
    'service_providers' => [
        'list_success' => 'تم جلب مقدمي الخدمة بنجاح.',
        'show_success' => 'تم جلب تفاصيل مقدم الخدمة بنجاح.',
        'created_success' => 'تم إنشاء مقدم الخدمة بنجاح.',
        'create_failed' => 'فشل في إنشاء مقدم الخدمة.',
        'updated_success' => 'تم تحديث مقدم الخدمة بنجاح.',
        'update_failed' => 'فشل في تحديث مقدم الخدمة.',
        'deleted_success' => 'تم حذف مقدم الخدمة بنجاح.',
        'delete_failed' => 'فشل في حذف مقدم الخدمة.',
        'not_found' => 'مقدم الخدمة غير موجود.',
        'availability_success' => 'تم جلب التوفر بنجاح.',
    ],

    // Devices (FCM)
    'devices' => [
        'registered' => 'تم تسجيل الجهاز بنجاح.',
        'removed' => 'تم إلغاء تسجيل الجهاز بنجاح.',
        'token_not_found' => 'رمز الجهاز غير موجود.',
    ],

    // Sync
    'sync' => [
        'master_data_success' => 'تم جلب البيانات الرئيسية بنجاح.',
        'batch_success' => 'تمت المزامنة الدفعية بنجاح.',
    ],

    // Dashboard
    'dashboard' => [
        'stats_success' => 'تم جلب إحصائيات لوحة التحكم بنجاح.',
    ],

    // Profile
    'profile' => [
        'show_success' => 'تم جلب الملف الشخصي بنجاح.',
        'updated' => 'تم تحديث الملف الشخصي بنجاح.',
        'locale_updated' => 'تم تحديث تفضيل اللغة بنجاح.',
        'photo_uploaded' => 'تم رفع صورة الملف الشخصي بنجاح.',
        'photo_deleted' => 'تم حذف صورة الملف الشخصي بنجاح.',
        'no_photo' => 'لا توجد صورة للحذف.',
    ],
];
