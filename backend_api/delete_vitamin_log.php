<?php
/**
 * delete_vitamin_log.php — POST { id }
 * Removes one of the caller's own vitamin log rows. The `logged_by` clause in
 * the DELETE is the MySQL stand-in for the old RLS delete policy.
 */
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}
$user = require_auth();

$body = request_body();
$logId = filter_var($body['id'] ?? null, FILTER_VALIDATE_INT);
if ($logId === false || $logId === null || $logId < 1) {
    json_response(false, null, 'id is required', 400);
}

$stmt = db()->prepare('DELETE FROM vitamin_logs WHERE id = ? AND logged_by = ?');
$stmt->execute([$logId, (int)$user['id']]);
if ($stmt->rowCount() === 0) {
    json_response(false, null, 'Log not found for this account', 404);
}
json_response(true, null, 'Vitamin dose deleted');
