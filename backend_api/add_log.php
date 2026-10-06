<?php
/**
 * add_log.php — POST JSON
 * { farm_id, action_type, amount, unit, trigger_source?, notes?, image_url?, action_time? }
 * Inserts one feeding / watering log stamped with the caller's user id.
 * (Photos are uploaded first through upload_file.php; only the URL lands here.)
 */
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

$user = require_auth();
$body = request_body();

$farmId     = filter_var($body['farm_id'] ?? null, FILTER_VALIDATE_INT);
$actionType = strtolower(trim($body['action_type'] ?? ''));
$amount     = filter_var($body['amount'] ?? null, FILTER_VALIDATE_FLOAT);
$unit       = strtolower(trim($body['unit'] ?? 'kg'));

if ($farmId === false || $farmId === null) {
    json_response(false, null, 'farm_id is required', 400);
}
$owned = db()->prepare('SELECT 1 FROM farms WHERE id = ? AND owner_id = ? LIMIT 1');
$owned->execute([$farmId, (int)$user['id']]);
if (!$owned->fetch()) {
    json_response(false, null, 'Farm not found for this account', 404);
}
if (!in_array($actionType, ['feeding', 'watering'], true)) {
    json_response(false, null, 'Invalid action type. Must be Feeding or Watering', 400);
}
if ($amount === false || $amount === null || $amount <= 0) {
    json_response(false, null, 'Amount must be greater than 0', 400);
}
if (!in_array($unit, ['kg', 'l', 'liters'], true)) {
    json_response(false, null, 'Invalid unit. Must be kg or L', 400);
}

$actionTime = trim((string)($body['action_time'] ?? ''));
if ($actionTime === '') {
    $actionTime = date('Y-m-d H:i:s');
} else {
    $ts = strtotime($actionTime);
    $actionTime = $ts !== false ? date('Y-m-d H:i:s', $ts) : date('Y-m-d H:i:s');
}

$notes = trim((string)($body['notes'] ?? ''));
$imageUrl = trim((string)($body['image_url'] ?? ''));

$stmt = db()->prepare(
    'INSERT INTO feeding_logs
        (user_id, farm_id, action_type, amount, unit, trigger_source, notes, image_url, action_time)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
);
$stmt->execute([
    (int)$user['id'],
    $farmId,
    ucfirst($actionType),
    $amount,
    $unit,
    trim((string)($body['trigger_source'] ?? 'manual')) ?: 'manual',
    $notes !== '' ? $notes : null,
    $imageUrl !== '' ? $imageUrl : null,
    $actionTime,
]);

json_response(true, ['id' => (int)db()->lastInsertId()], 'Log recorded', 201);
