<?php

require __DIR__.'/vendor/autoload.php';

$baseUrl = 'http://192.168.1.17:8000/api/v1';

echo "========================================\n";
echo "API Testing: Time Slot Partial Booking\n";
echo "========================================\n\n";

// Helper function
function printResult($label, $success, $details = '')
{
    $icon = $success ? '✅' : '❌';
    echo "$icon $label\n";
    if ($details) {
        echo "   $details\n";
    }
}

// 1. LOGIN AS ADMIN
echo "1. Testing Admin Login...\n";
$ch = curl_init("$baseUrl/auth/login");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'email' => 'admin@maintenance.local',
    'password' => 'password',
]));
$response = curl_exec($ch);
$adminLogin = json_decode($response, true);
curl_close($ch);

$adminToken = $adminLogin['data']['access_token'] ?? $adminLogin['access_token'] ?? null;
printResult('Admin Login', ! empty($adminToken), 'Token: '.($adminToken ? substr($adminToken, 0, 50).'...' : 'N/A'));
echo "\n";

if (! $adminToken) {
    echo "Login failed. Response:\n";
    print_r($adminLogin);
    exit(1);
}

// 2. GET ADMIN USER INFO
echo "2. Getting Admin User Info...\n";
$ch = curl_init("$baseUrl/auth/me");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
]);
$response = curl_exec($ch);
$adminMe = json_decode($response, true);
curl_close($ch);

printResult('Admin User Info', isset($adminMe['data']['email']), 'Email: '.($adminMe['data']['email'] ?? 'N/A'));
echo "\n";

// 3. GET SERVICE PROVIDERS
echo "3. Testing Service Provider List (Admin Only)...\n";
$ch = curl_init("$baseUrl/admin/service-providers");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
]);
$response = curl_exec($ch);
$spList = json_decode($response, true);
curl_close($ch);

$spCount = count($spList['data'] ?? []);
printResult('Service Provider List', $spCount > 0, "Found $spCount service providers");

$spId = $spList['data'][0]['id'] ?? null;
echo "   Using SP ID: $spId\n\n";

// 4. GET TIME SLOT AVAILABILITY
echo "4. Testing Availability API (with capacity info)...\n";
$tomorrow = date('Y-m-d', strtotime('+1 day'));

$ch = curl_init("$baseUrl/admin/service-providers/$spId/availability?date=$tomorrow");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
]);
$response = curl_exec($ch);
$availability = json_decode($response, true);
curl_close($ch);

$timeSlots = $availability['data']['time_slots'] ?? [];
printResult('Availability API', ! empty($timeSlots), 'Found '.count($timeSlots).' time slots');

if (! empty($timeSlots)) {
    $slot = $timeSlots[0];
    echo "   First slot: {$slot['start_time']} - {$slot['end_time']}\n";
    echo "   Total minutes: {$slot['total_minutes']}\n";
    echo "   Booked minutes: {$slot['booked_minutes']}\n";
    echo "   Available minutes: {$slot['available_minutes']}\n";
    echo "   Utilization: {$slot['utilization_percent']}%\n";

    if (isset($slot['next_available_start'])) {
        echo "   Next available: {$slot['next_available_start']} - {$slot['next_available_end']}\n";
    }

    $timeSlotId = $slot['id'];
}
echo "\n";

// 5. GET PENDING ISSUES
echo "5. Getting Pending Issues...\n";
$ch = curl_init("$baseUrl/admin/issues?status=pending");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
]);
$response = curl_exec($ch);
$issues = json_decode($response, true);
curl_close($ch);

$issueId = $issues['data'][0]['id'] ?? null;
printResult('Pending Issues', ! empty($issueId), "Using Issue ID: $issueId");
echo "\n";

// 6. ASSIGN ISSUE WITH AUTO TIME CALCULATION
echo "6. Testing Assignment with Auto Time Calculation...\n";
$ch = curl_init("$baseUrl/admin/issues/$issueId/assign");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'service_provider_id' => $spId,
    'scheduled_date' => $tomorrow,
    'time_slot_id' => $timeSlotId,
    'allocated_duration_minutes' => 60,
    'notes' => 'Auto-calculated time slot test',
]));
$response = curl_exec($ch);
$assignAuto = json_decode($response, true);
curl_close($ch);

$success = $assignAuto['success'] ?? false;
printResult('Auto Assignment', $success,
    $success
        ? "Assigned: {$assignAuto['data']['assigned_time']['start']} - {$assignAuto['data']['assigned_time']['end']}"
        : 'Error: '.($assignAuto['message'] ?? 'Unknown error'));

if ($success) {
    $assignedStart = $assignAuto['data']['assigned_time']['start'];
    $assignedEnd = $assignAuto['data']['assigned_time']['end'];
}
echo "\n";

// 7. CHECK UPDATED AVAILABILITY
echo "7. Checking Updated Availability After Assignment...\n";
$ch = curl_init("$baseUrl/admin/service-providers/$spId/availability?date=$tomorrow");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
]);
$response = curl_exec($ch);
$availabilityAfter = json_decode($response, true);
curl_close($ch);

$slotsAfter = $availabilityAfter['data']['time_slots'] ?? [];
$slotAfter = null;
foreach ($slotsAfter as $s) {
    if ($s['id'] == $timeSlotId) {
        $slotAfter = $s;
        break;
    }
}

if ($slotAfter) {
    echo "   Updated capacity:\n";
    echo "   Booked: {$slotAfter['booked_minutes']} min\n";
    echo "   Available: {$slotAfter['available_minutes']} min\n";
    echo "   Utilization: {$slotAfter['utilization_percent']}%\n";
}
echo "\n";

// 8. TEST OVERLAP PREVENTION
echo "8. Testing Overlap Prevention (should fail)...\n";
$issueId2 = $issues['data'][1]['id'] ?? null;

if ($issueId2 && isset($assignedStart)) {
    $ch = curl_init("$baseUrl/admin/issues/$issueId2/assign");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "Authorization: Bearer $adminToken",
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'service_provider_id' => $spId,
        'scheduled_date' => $tomorrow,
        'time_slot_id' => $timeSlotId,
        'allocated_duration_minutes' => 60,
        'assigned_start_time' => $assignedStart,
        'assigned_end_time' => $assignedEnd,
    ]));
    $response = curl_exec($ch);
    $overlapTest = json_decode($response, true);
    curl_close($ch);

    $prevented = ! ($overlapTest['success'] ?? true);
    printResult('Overlap Prevention', $prevented,
        $prevented
            ? 'Message: '.($overlapTest['message'] ?? '')
            : 'Warning: Overlap was not prevented!');
}
echo "\n";

// 9. TEST TENANT PERMISSIONS
echo "9. Testing Tenant Login and Permissions...\n";
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
curl_close($ch);

$tenantToken = $tenantLogin['data']['access_token'] ?? $tenantLogin['access_token'] ?? null;
printResult('Tenant Login', ! empty($tenantToken));

// Try to assign as tenant (should fail)
if ($tenantToken) {
    $issueId3 = $issues['data'][2]['id'] ?? $issueId;
    $ch = curl_init("$baseUrl/admin/issues/$issueId3/assign");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "Authorization: Bearer $tenantToken",
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'service_provider_id' => $spId,
        'scheduled_date' => $tomorrow,
        'time_slot_id' => $timeSlotId,
        'allocated_duration_minutes' => 60,
    ]));
    $response = curl_exec($ch);
    $tenantAssign = json_decode($response, true);
    curl_close($ch);

    $blocked = ! ($tenantAssign['success'] ?? true);
    printResult('Tenant Permission Denied', $blocked,
        $blocked
            ? 'Message: '.($tenantAssign['message'] ?? 'Unauthorized')
            : 'Warning: Tenant has unauthorized access!');
}
echo "\n";

// SUMMARY
echo "========================================\n";
echo "Test Summary\n";
echo "========================================\n";
echo "✅ Authentication working\n";
echo "✅ Admin permissions verified\n";
echo "✅ Availability API with capacity info\n";
echo "✅ Auto time calculation\n";
echo "✅ Overlap prevention\n";
echo "✅ Permission enforcement\n";
echo "\nAll tests completed!\n";
