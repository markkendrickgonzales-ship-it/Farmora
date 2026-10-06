<?php
/**
 * upsert_nutrition_log.php — POST
 * Body: { batch_id, log_date (YYYY-MM-DD), feed_intake_g,
 *         body_weight_kg?, fcr?, notes? }
 *
 * Inserts or updates one daily reading against the UNIQUE(batch_id, log_date)
 * key of `nutrition_logs`. The batch must belong to the caller; owner_id is
 * stamped from the bearer token, never from the request body.
 */
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}
$user = require_auth();

$body       = request_body();
$batchId    = filter_var($body['batch_id'] ?? null, FILTER_VALIDATE_INT);
$logDate    = preg_match('/^\d{4}-\d{2}-\d{2}$/', (string)($body['log_date'] ?? ''))
              ? $body['log_date'] : null;
$intakeG    = filter_var($body['feed_intake_g'] ?? null, FILTER_VALIDATE_FLOAT);

if ($batchId === false || $batchId === null || $batchId < 1) {
    json_response(false, null, 'batch_id is required', 400);
}
if ($logDate === null) {
    json_response(false, null, 'log_date must be YYYY-MM-DD', 400);
}
if ($intakeG === false || $intakeG === null || $intakeG < 0) {
    json_response(false, null, 'feed_intake_g must be a non-negative number', 400);
}

// The batch must be the caller's own.
$owned = db()->prepare('SELECT 1 FROM batches WHERE id = ? AND owner_id = ? LIMIT 1');
$owned->execute([$batchId, (int)$user['id']]);
if (!$owned->fetch()) {
    json_response(false, null, 'Batch not found for this account', 404);
}

$bodyWeight = filter_var($body['body_weight_kg'] ?? null, FILTER_VALIDATE_FLOAT);
$fcr        = filter_var($body['fcr'] ?? null, FILTER_VALIDATE_FLOAT);
$notes      = isset($body['notes']) && $body['notes'] !== ''
    ? mb_substr((string)$body['notes'], 0, 255) : null;

$stmt = db()->prepare(
    'INSERT INTO nutrition_logs
        (batch_id, owner_id, log_date, feed_intake_g, body_weight_kg, fcr, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
        feed_intake_g   = VALUES(feed_intake_g),
        body_weight_kg  = VALUES(body_weight_kg),
        fcr             = VALUES(fcr),
        notes           = VALUES(notes)'
);
$stmt->execute([
    $batchId,
    (int)$user['id'],
    $logDate,
    $intakeG,
    $bodyWeight === false ? null : $bodyWeight,
    $fcr === false ? null : $fcr,
    $notes,
]);

json_response(true, null, 'Daily reading saved');
