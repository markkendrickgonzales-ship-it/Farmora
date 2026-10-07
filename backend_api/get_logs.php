<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

try {
    $user   = require_auth();
    $farmId = filter_var($_GET['farm_id'] ?? null, FILTER_VALIDATE_INT);
    $limit  = min(max((int)($_GET['limit'] ?? 50), 1), 500);

    if ($farmId === false || $farmId === null) {
        json_response(false, null, 'farm_id is required', 400);
    }

    $owned = db()->prepare('SELECT 1 FROM farms WHERE id = ? AND owner_id = ? LIMIT 1');
    $owned->execute([$farmId, (int)$user['id']]);
    if (!$owned->fetch()) {
        json_response(false, null, 'Farm not found for this account', 404);
    }

    $stmt = db()->prepare(
        "SELECT id,
                farm_id,
                action_type,
                amount,
                unit,
                trigger_source,
                notes,
                image_url,
                DATE_FORMAT(action_time, '%Y-%m-%dT%H:%i:%s') AS action_time
           FROM feeding_logs
          WHERE (user_id = ? OR farm_id = ?) AND farm_id = ?
          ORDER BY action_time DESC
          LIMIT $limit"
    );
    $stmt->execute([(int)$user['id'], $farmId, $farmId]);

    json_response(true, $stmt->fetchAll());
} catch (Throwable $e) {
    json_response(false, null, 'Error: ' . $e->getMessage(), 500);
}
