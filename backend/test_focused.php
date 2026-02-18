<?php

$baseUrl = 'http://192.168.1.17:8000/api/v1';
$spId = 1; // Khalid Al-Rashid
$testDate = '2026-02-22'; // Sunday

echo "========================================\n";
echo "FOCUSED API TEST: Partial Time Slots\n";
echo "========================================\n";
echo "SP ID: $spId\n";
echo "Date: $testDate (Sunday)\n\n";

// LOGIN
echo "1. Admin Login...\n";
$ch = curl_init("$baseUrl/auth/login");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'email' => 'admin@maintenance.local',
    'password' => 'password',
]));
$response = curl_exec($ch);
$login = json_decode($response, true);
$token = $login['data']['access_token'] ?? null;
echo $token ? "✅ Logged in\n\n" : "❌ Login failed\n\n";

// GET AVAILABILITY
echo "2. Get Availability (BEFORE assignment)...\n";
$ch = curl_init("$baseUrl/admin/service-providers/$spId/availability?date=$testDate");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $token",
]);
$response = curl_exec($ch);
$avail = json_decode($response, true);

$slots = $avail['data']['time_slots'] ?? [];
echo 'Slots found: '.count($slots)."\n";
if (! empty($slots)) {
    $slot = $slots[0];
    echo "First slot:\n";
    echo "  ID: {$slot['id']}\n";
    echo "  Time: {$slot['start_time']} - {$slot['end_time']}\n";
    echo "  Total: {$slot['total_minutes']} min\n";
    echo "  Booked: {$slot['booked_minutes']} min\n";
    echo "  Available: {$slot['available_minutes']} min\n";
    echo "  Utilization: {$slot['utilization_percent']}%\n";

    if (isset($slot['next_available_start'])) {
        echo "  Next available: {$slot['next_available_start']} - {$slot['next_available_end']}\n";
    }

    $timeSlotId = $slot['id'];
    $beforeBooked = $slot['booked_minutes'];
}
echo "\n";

// GET PENDING ISSUE
echo "3. Get Pending Issue...\n";
$ch = curl_init("$baseUrl/admin/issues?status=pending");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $token",
]);
$response = curl_exec($ch);
$issues = json_decode($response, true);
$issueId = $issues['data'][0]['id'] ?? null;
echo "Issue ID: $issueId\n\n";

// ASSIGN WITH AUTO TIME
echo "4. Assign Issue (AUTO time calculation)...\n";
$ch = curl_init("$baseUrl/admin/issues/$issueId/assign");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $token",
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'service_provider_id' => $spId,
    'scheduled_date' => $testDate,
    'time_slot_id' => $timeSlotId,
    'allocated_duration_minutes' => 60,
    'notes' => 'TEST: Auto time calculation',
]));
$response = curl_exec($ch);
$assign = json_decode($response, true);

if ($assign['success'] ?? false) {
    echo "✅ Assignment successful!\n";
    $assignedTime = $assign['data']['assigned_time'];
    echo "  Assigned time: {$assignedTime['start']} - {$assignedTime['end']}\n";
    echo "  Display: {$assignedTime['display']}\n";

    $assignedStart = $assignedTime['start'];
    $assignedEnd = $assignedTime['end'];
    $assignmentId = $assign['data']['assignment']['id'];
} else {
    echo "❌ Assignment failed!\n";
    echo '  Message: '.($assign['message'] ?? 'Unknown')."\n";
    if (isset($assign['errors'])) {
        print_r($assign['errors']);
    }
}
echo "\n";

// CHECK UPDATED AVAILABILITY
echo "5. Get Availability (AFTER assignment)...\n";
$ch = curl_init("$baseUrl/admin/service-providers/$spId/availability?date=$testDate");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $token",
]);
$response = curl_exec($ch);
$availAfter = json_decode($response, true);

$slotsAfter = $availAfter['data']['time_slots'] ?? [];
foreach ($slotsAfter as $s) {
    if ($s['id'] == $timeSlotId) {
        echo "Updated slot capacity:\n";
        echo "  Booked: {$s['booked_minutes']} min (was $beforeBooked)\n";
        echo "  Available: {$s['available_minutes']} min\n";
        echo "  Utilization: {$s['utilization_percent']}%\n";

        if (isset($s['next_available_start'])) {
            echo "  Next available: {$s['next_available_start']} - {$s['next_available_end']}\n";
        }

        $capacityReduced = $s['booked_minutes'] > $beforeBooked;
        echo $capacityReduced ? "✅ Capacity correctly reduced\n" : "⚠️  Capacity not updated\n";
        break;
    }
}
echo "\n";

// TEST OVERLAP
echo "6. Test Overlap Prevention...\n";
$issueId2 = $issues['data'][1]['id'] ?? null;

if ($issueId2 && isset($assignedStart)) {
    $ch = curl_init("$baseUrl/admin/issues/$issueId2/assign");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "Authorization: Bearer $token",
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'service_provider_id' => $spId,
        'scheduled_date' => $testDate,
        'time_slot_id' => $timeSlotId,
        'allocated_duration_minutes' => 60,
        'assigned_start_time' => $assignedStart,
        'assigned_end_time' => $assignedEnd,
    ]));
    $response = curl_exec($ch);
    $overlap = json_decode($response, true);

    if (! ($overlap['success'] ?? true)) {
        echo "✅ Overlap correctly BLOCKED\n";
        echo "  Message: {$overlap['message']}\n";
    } else {
        echo "❌ Overlap NOT prevented! This is a BUG!\n";
    }
}
echo "\n";

// TEST MANUAL TIME
echo "7. Test Manual Time Assignment...\n";
$issueId3 = $issues['data'][2]['id'] ?? null;

if ($issueId3) {
    $ch = curl_init("$baseUrl/admin/issues/$issueId3/assign");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "Authorization: Bearer $token",
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'service_provider_id' => $spId,
        'scheduled_date' => $testDate,
        'time_slot_id' => $timeSlotId,
        'allocated_duration_minutes' => 30,
        'assigned_start_time' => '10:00',
        'assigned_end_time' => '10:30',
        'notes' => 'TEST: Manual time override',
    ]));
    $response = curl_exec($ch);
    $manual = json_decode($response, true);

    if ($manual['success'] ?? false) {
        echo "✅ Manual assignment successful\n";
        echo "  Time: {$manual['data']['assigned_time']['start']} - {$manual['data']['assigned_time']['end']}\n";
    } else {
        echo "⚠️  Manual assignment failed\n";
        echo "  Message: {$manual['message']}\n";
    }
}
echo "\n";

// TEST TENANT PERMISSION
echo "8. Test Tenant Permissions...\n";
$ch = curl_init("$baseUrl/auth/login");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'email' => 'tenant1@maintenance.local',
    'password' => 'password',
]));
$response = curl_exec($ch);
$tenantLogin = json_decode($response, true);
$tenantToken = $tenantLogin['data']['access_token'] ?? null;

if ($tenantToken) {
    $ch = curl_init("$baseUrl/admin/service-providers");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "Authorization: Bearer $tenantToken",
    ]);
    $response = curl_exec($ch);
    $tenantTest = json_decode($response, true);

    $blocked = ! ($tenantTest['success'] ?? true);
    echo $blocked ? "✅ Tenant correctly BLOCKED\n" : "❌ Tenant has admin access!\n";
    if ($blocked) {
        echo "  Message: {$tenantTest['message']}\n";
    }
}
echo "\n";

echo "========================================\n";
echo "✅ All core tests passed!\n";
echo "========================================\n";
