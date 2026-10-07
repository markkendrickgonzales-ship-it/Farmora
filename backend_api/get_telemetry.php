<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

try {
    $user   = require_auth();
    $farmId = filter_var($_GET['farm_id'] ?? null, FILTER_VALIDATE_INT);
    $mode   = ($_GET['mode'] ?? 'latest') === 'history' ? 'history' : 'latest';
    $limit  = min(max((int)($_GET['limit'] ?? 20), 1), 200);

    if ($farmId === false || $farmId === null) {
        json_response(false, null, 'farm_id is required', 400);
    }

    $owned = db()->prepare(
        'SELECT 1 FROM farms WHERE id = ? AND owner_id = ? LIMIT 1'
    );
    $owned->execute([$farmId, (int)$user['id']]);
    if (!$owned->fetch()) {
        json_response(false, null, 'Farm not found for this account', 404);
    }

    $cols = "id,
             farm_id,
             temperature_c,
             humidity_percent,
             power_load_kw,
             ammonia_ppm,
             status,
             DATE_FORMAT(recorded_at, '%Y-%m-%dT%H:%i:%s') AS recorded_at";

    if ($mode === 'latest') {
        $stmt = db()->prepare(
            "SELECT $cols FROM sensor_telemetry
              WHERE farm_id = ?
              ORDER BY recorded_at DESC LIMIT 1"
        );
        $stmt->execute([$farmId]);
        json_response(true, $stmt->fetchAll());
    }

    $stmt = db()->prepare(
        "SELECT $cols FROM sensor_telemetry
          WHERE farm_id = ?
          ORDER BY recorded_at DESC
          LIMIT $limit"
    );
    $stmt->execute([$farmId]);
    json_response(true, $stmt->fetchAll());
} catch (Throwable $e) {
    json_response(false, null, 'Error: ' . $e->getMessage(), 500);
}
