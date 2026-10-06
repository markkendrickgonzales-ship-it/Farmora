<?php

require_once __DIR__ . '/db_connect.php';

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
            title,
            category,
            notes,
            file_url,
            DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s') AS created_at
       FROM reports
      WHERE user_id = ? AND farm_id = ?
      ORDER BY created_at DESC
      LIMIT $limit"
);
$stmt->execute([(int)$user['id'], $farmId]);

json_response(true, $stmt->fetchAll());
