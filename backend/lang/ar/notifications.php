<?php

return [
    'title' => 'الإشعارات',
    'singular' => 'إشعار',
    'plural' => 'الإشعارات',
    'unread' => 'غير مقروء',
    'mark_all_read' => 'تحديد الكل كمقروء',
    'mark_read' => 'تحديد كمقروء',
    'delete' => 'حذف',
    'delete_all' => 'حذف الكل',
    'confirm_delete' => 'هل أنت متأكد من حذف هذا الإشعار؟',
    'confirm_delete_all' => 'هل أنت متأكد من حذف جميع الإشعارات؟',
    'all_marked_read' => 'تم تحديد جميع الإشعارات كمقروء',
    'all_deleted' => 'تم حذف جميع الإشعارات',
    'deleted' => 'تم حذف الإشعار',
    'no_notifications' => 'لا توجد إشعارات بعد',
    'view_issue' => 'عرض المشكلة',
    'unread_description' => 'إشعارات تنتظر انتباهك',
    'today_description' => 'استلمت اليوم',

    'channels' => [
        'fcm' => 'إشعارات Firebase',
        'database' => 'قاعدة البيانات',
    ],

    'types' => [
        'issue_created' => 'تم إنشاء مشكلة جديدة',
        'issue_assigned' => 'تم تعيين مشكلة',
        'work_started' => 'بدأ العمل',
        'work_finished' => 'انتهى العمل',
        'assignment_approved' => 'تمت الموافقة على المهمة',
        'partial_progress' => 'تحديث التقدم',
        'issue_completed' => 'اكتملت المشكلة',
        'issue_cancelled' => 'تم إلغاء المشكلة',
    ],

    'messages' => [
        'issue_created' => [
            'title' => 'مشكلة جديدة',
            'body' => 'تم الإبلاغ عن مشكلة جديدة: :title',
        ],
        'issue_assigned' => [
            'title' => 'تم تعيين مشكلة',
            'body' => 'تم تعيينك لـ: :title',
        ],
        'work_started' => [
            'title' => 'بدأ العمل',
            'body' => 'بدأ العمل على: :title',
        ],
        'work_on_hold' => [
            'title' => 'العمل معلق',
            'body' => 'تم تعليق العمل على: :title',
        ],
        'work_resumed' => [
            'title' => 'استئناف العمل',
            'body' => 'تم استئناف العمل على: :title',
        ],
        'work_finished' => [
            'title' => 'انتهى العمل',
            'body' => 'اكتمل العمل على: :title. يرجى المراجعة والموافقة.',
        ],
        'assignment_approved' => [
            'title' => 'تمت الموافقة على المهمة',
            'body' => 'تمت الموافقة على عملك في: :title',
        ],
        'partial_progress' => [
            'title' => 'تحديث التقدم',
            'body' => 'اكتمل :completed من :total مهام لـ: :title',
        ],
        'issue_completed' => [
            'title' => 'اكتملت المشكلة',
            'body' => 'تم حل مشكلتك: :title',
        ],
        'issue_cancelled' => [
            'title' => 'تم إلغاء المشكلة',
            'body' => 'تم إلغاء المشكلة: :title',
        ],
        'general' => [
            'title' => 'إشعار',
            'body' => ':message',
        ],
    ],
];
