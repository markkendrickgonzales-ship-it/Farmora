<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

try {
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
} catch (Throwable $e) {
    json_response(false, null, 'Error: ' . $e->getMessage(), 500);
}
