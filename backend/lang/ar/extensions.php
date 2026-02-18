<?php

return [
    'singular' => 'طلب تمديد الوقت',
    'plural' => 'طلبات تمديد الوقت',
    'request_submitted' => 'تم تقديم طلب تمديد الوقت بنجاح',
    'approved_successfully' => 'تم الموافقة على طلب تمديد الوقت بنجاح',
    'rejected_successfully' => 'تم رفض طلب تمديد الوقت بنجاح',
    'not_found' => 'طلب تمديد الوقت غير موجود',
    'cannot_approve' => 'لا يمكن الموافقة على طلب التمديد هذا',
    'overlap_conflict' => 'لا يمكن الموافقة: تمديد :minutes دقيقة يتعارض مع مهمة أخرى في نفس الفترة الزمنية',
    'cannot_reject' => 'لا يمكن رفض طلب التمديد هذا',
    'not_authorized' => 'غير مصرح لك بطلب تمديد لهذه المهمة',
    'work_not_started' => 'يجب أن يكون العمل قيد التقدم لطلب تمديد الوقت',
    'pending_request_exists' => 'يوجد بالفعل طلب تمديد معلق لهذه المهمة',
    'request_failed' => 'فشل تقديم طلب التمديد',

    'status' => [
        'pending' => 'قيد الانتظار',
        'approved' => 'مقبول',
        'rejected' => 'مرفوض',
    ],

    'fields' => [
        'id' => 'المعرف',
        'issue' => 'المشكلة',
        'service_provider' => 'مزود الخدمة',
        'requested_time' => 'الوقت المطلوب',
        'status' => 'الحالة',
        'requested_at' => 'تاريخ الطلب',
        'responded_by' => 'الرد من قبل',
        'responded_at' => 'تاريخ الرد',
        'requested_by' => 'طلب من قبل',
        'start_time' => 'وقت البداية',
        'end_time' => 'وقت النهاية (بعد التمديد)',
        'allocated_duration' => 'المدة المخصصة',
        'scheduled_date' => 'تاريخ الجدولة',
        'admin_notes' => 'ملاحظات المشرف',
        'rejection_reason' => 'سبب الرفض',
        'reason' => 'السبب',
    ],

    'filters' => [
        'status' => 'تصفية حسب الحالة',
    ],

    'actions' => [
        'approve' => 'موافقة',
        'reject' => 'رفض',
    ],

    'widget' => [
        'pending' => 'التمديدات المعلقة',
        'pending_description' => 'طلبات تمديد الوقت في انتظار الموافقة',
    ],

    'request_info' => 'معلومات الطلب',
    'admin_response' => 'رد المشرف',
    'slot_impact' => 'تأثير الفترة الزمنية',
    'reason' => 'السبب',
    'no_requests' => 'لا توجد طلبات تمديد',
    'detail_title' => 'تفاصيل طلب التمديد',
    'request_title' => 'طلب تمديد الوقت',
    'select_duration' => 'اختر المدة',
    'reason_hint' => 'اشرح لماذا تحتاج إلى مزيد من الوقت',
    'reason_min_length' => 'يجب أن يكون السبب 10 أحرف على الأقل',
    'submit_request' => 'إرسال الطلب',
    'rejection_reason_required' => 'سبب الرفض مطلوب (10 أحرف على الأقل)',
];
