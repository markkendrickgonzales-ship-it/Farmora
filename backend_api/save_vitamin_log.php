<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}
$user = require_auth();

$body     = request_body();
$logId    = filter_var($body['id'] ?? null, FILTER_VALIDATE_INT);
$batchId  = filter_var($body['batch_id'] ?? null, FILTER_VALIDATE_INT);
$vitaminId = filter_var($body['vitamin_id'] ?? null, FILTER_VALIDATE_INT);
$customName = isset($body['custom_name']) && $body['custom_name'] !== ''
    ? mb_substr(trim((string)$body['custom_name']), 0, 100) : null;
$dosage   = filter_var($body['dosage'] ?? null, FILTER_VALIDATE_FLOAT);
$unit     = trim((string)($body['unit'] ?? ''));
$logDate  = preg_match('/^\d{4}-\d{2}-\d{2}$/', (string)($body['log_date'] ?? ''))
    ? $body['log_date'] : null;
$rawTime = (string)($body['time_given'] ?? '');
$timeGiven = preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $rawTime)
    ? (strlen($rawTime) === 5 ? $rawTime . ':00' : $rawTime)
    : null;
$dayNumber = max((int)($body['day_number'] ?? 1), 1);
$notes    = isset($body['notes']) && $body['notes'] !== ''
    ? mb_substr((string)$body['notes'], 0, 255) : null;

if ($dosage === false || $dosage === null || $dosage <= 0) {
    json_response(false, null, 'dosage must be a positive number', 400);
}
if ($unit === '' || $logDate === null || $timeGiven === null) {
    json_response(false, null, 'unit, log_date and time_given are required', 400);
}
if ($vitaminId === false) $vitaminId = null;
if ($batchId === false || $batchId === null) {

    $batch = resolve_latest_batch((int)$user['id']);
    if ($batch === null) {
        json_response(false, null, 'No active batch — create a farm first', 400);
    }
    $batchId = (int)$batch['id'];
}

$pdo = db();
if ($logId === false || $logId === null) {

    if ($vitaminId === null && $customName === null) {
        json_response(false, null, 'Provide either vitamin_id or custom_name', 400);
    }
    $stmt = $pdo->prepare(
        'INSERT INTO vitamin_logs
            (batch_id, vitamin_id, custom_name, dosage, unit,
             log_date, time_given, day_number, notes, logged_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $batchId, $vitaminId, $customName, $dosage, $unit,
        $logDate, $timeGiven, $dayNumber, $notes, (int)$user['id'],
    ]);
    json_response(true, ['id' => (int)$pdo->lastInsertId()], 'Vitamin dose logged', 201);
}

$stmt = $pdo->prepare(
    'UPDATE vitamin_logs
        SET batch_id    = ?,
            vitamin_id  = ?,
            custom_name = ?,
            dosage      = ?,
            unit        = ?,
            log_date    = ?,
            time_given  = ?,
            day_number  = ?,
            notes       = ?
      WHERE id = ? AND logged_by = ?'
);
$stmt->execute([
    $batchId, $vitaminId, $customName, $dosage, $unit,
    $logDate, $timeGiven, $dayNumber, $notes,
    $logId, (int)$user['id'],
]);
if ($stmt->rowCount() === 0) {

    $check = $pdo->prepare('SELECT 1 FROM vitamin_logs WHERE id = ? AND logged_by = ? LIMIT 1');
    $check->execute([$logId, (int)$user['id']]);
    if (!$check->fetch()) {
        json_response(false, null, 'Log not found for this account', 404);
    }
}
json_response(true, null, 'Vitamin dose updated');
