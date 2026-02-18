<?php

return [
    'title' => 'المستخدمون',
    'singular' => 'مستخدم',
    'plural' => 'المستخدمون',

    'roles' => [
        'super_admin' => 'المدير العام',
        'manager' => 'مدير',
        'viewer' => 'مشاهد',
        'tenant' => 'مستأجر',
        'service_provider' => 'مزود الخدمة',
    ],

    'fields' => [
        'name' => 'الاسم',
        'email' => 'البريد الإلكتروني',
        'phone' => 'الهاتف',
        'password' => 'كلمة المرور',
        'password_confirmation' => 'تأكيد كلمة المرور',
        'role' => 'الدور',
        'is_active' => 'نشط',
        'locale' => 'اللغة',
        'fcm_token' => 'رمز FCM',
        'created_at' => 'تاريخ الإنشاء',
    ],

    'messages' => [
        'created' => 'تم إنشاء المستخدم بنجاح',
        'updated' => 'تم تحديث المستخدم بنجاح',
        'deleted' => 'تم حذف المستخدم بنجاح',
        'password_reset' => 'تم إعادة تعيين كلمة المرور بنجاح',
    ],
];
