<?php

return [
    'title' => 'مستخدمو الإدارة',
    'singular' => 'مستخدم إداري',
    'plural' => 'مستخدمو الإدارة',

    'sections' => [
        'user_info' => 'معلومات المستخدم',
        'role_status' => 'الدور والحالة',
    ],

    'fields' => [
        'name' => 'الاسم',
        'email' => 'البريد الإلكتروني',
        'password' => 'كلمة المرور',
        'phone' => 'الهاتف',
        'role' => 'الدور',
        'is_active' => 'نشط',
        'created_at' => 'تاريخ الإنشاء',
        'updated_at' => 'تاريخ التحديث',
        'new_password' => 'كلمة المرور الجديدة',
        'confirm_password' => 'تأكيد كلمة المرور',
    ],

    'roles' => [
        'super_admin' => 'المدير العام',
        'manager' => 'مدير',
        'viewer' => 'مشاهد',
    ],

    'filters' => [
        'role' => 'الدور',
        'active' => 'حالة النشاط',
    ],

    'actions' => [
        'reset_password' => 'إعادة تعيين كلمة المرور',
        'reset_password_confirmation' => 'هل أنت متأكد من إعادة تعيين كلمة مرور هذا المستخدم؟',
        'toggle_active' => 'تبديل النشاط',
        'activate' => 'تفعيل',
        'deactivate' => 'إلغاء التفعيل',
    ],

    'messages' => [
        'created' => 'تم إنشاء المستخدم الإداري بنجاح',
        'updated' => 'تم تحديث المستخدم الإداري بنجاح',
        'deleted' => 'تم حذف المستخدم الإداري بنجاح',
        'password_reset' => 'تم إعادة تعيين كلمة المرور بنجاح',
        'activated' => 'تم تفعيل المستخدم بنجاح',
        'deactivated' => 'تم إلغاء تفعيل المستخدم بنجاح',
        'cannot_delete_self' => 'لا يمكنك حذف حسابك الخاص',
        'cannot_deactivate_self' => 'لا يمكنك إلغاء تفعيل حسابك الخاص',
    ],
];
