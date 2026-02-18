<?php

return [
    'singular' => 'مزود الخدمة',
    'plural' => 'مزودو الخدمات',

    'sections' => [
        'personal_info' => 'المعلومات الشخصية',
        'work_info' => 'معلومات العمل',
        'time_slots' => 'ساعات العمل',
        'time_slots_description' => 'حدد متى يكون مزود الخدمة هذا متاحًا لمهام العمل.',
        'location' => 'الموقع',
        'status' => 'الحالة',
    ],

    'fields' => [
        'name' => 'الاسم',
        'email' => 'البريد الإلكتروني',
        'password' => 'كلمة المرور',
        'phone' => 'الهاتف',
        'profile_photo' => 'صورة الملف الشخصي',
        'categories' => 'الفئات',
        'is_available' => 'متاح',
        'is_active' => 'نشط',
        'latitude' => 'خط العرض',
        'longitude' => 'خط الطول',
        'assignments_count' => 'التعيينات',
        'new_password' => 'كلمة المرور الجديدة',
        'confirm_password' => 'تأكيد كلمة المرور',
    ],

    'filters' => [
        'category' => 'الفئة',
        'available' => 'التوفر',
        'active' => 'حالة النشاط',
    ],

    'actions' => [
        'reset_password' => 'إعادة تعيين كلمة المرور',
        'reset_password_confirmation' => 'أدخل كلمة المرور الجديدة لمزود الخدمة هذا.',
        'mark_available' => 'تحديد كمتاح',
        'mark_unavailable' => 'تحديد كغير متاح',
        'delete_with_assignments' => 'يحتوي مزود الخدمة هذا على :count تعيين(ات). سيؤدي الحذف إلى إزالة ارتباط مزود الخدمة من هذه التعيينات. هل أنت متأكد من المتابعة؟',
        'bulk_delete_warning' => 'سيؤدي هذا إلى حذف مزودي الخدمات المحددين. سيتم إزالة مرجع مزود الخدمة من أي تعيينات مرتبطة بهم.',
    ],
];
