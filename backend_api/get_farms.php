<?php
/**
 * get_farms.php — GET
 * Farms owned by the bearer token's user, ordered by name.
 */
require_once __DIR__ . '/db_connect.php';

$user = require_auth();

$stmt = db()->prepare(
    'SELECT id, farm_name, location, farm_type, created_at
       FROM farms
      WHERE owner_id = ?
      ORDER BY farm_name ASC'
);
$stmt->execute([(int)$user['id']]);

json_response(true, $stmt->fetchAll());
