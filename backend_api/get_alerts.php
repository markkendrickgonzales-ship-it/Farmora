<?php

require_once __DIR__ . '/db_connect.php';

$user   = require_auth();
$farmId = filter_var($_GET['farm_id'] ?? null, FILTER_VALIDATE_INT);
$limit  = min(max((int)($_GET['limit'] ?? 10), 1), 100);

$sql = "SELECT a.id,
               a.farm_id,
               a.severity,
               a.alert_type,
               a.message,
               DATE_FORMAT(a.triggered_at, '%Y-%m-%dT%H:%i:%s') AS triggered_at,
               DATE_FORMAT(a.created_at,  '%Y-%m-%dT%H:%i:%s') AS created_at
          FROM alerts a
          JOIN farms f ON f.id = a.farm_id
         WHERE f.owner_id = ?";
$params = [(int)$user['id']];

if ($farmId !== false && $farmId !== null) {
    $sql .= ' AND a.farm_id = ?';
    $params[] = $farmId;
}
$sql .= " ORDER BY a.created_at DESC LIMIT $limit";

$stmt = db()->prepare($sql);
$stmt->execute($params);
json_response(true, $stmt->fetchAll());
