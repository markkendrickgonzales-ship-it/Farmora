<?php

require_once __DIR__ . '/db_connect.php';

$user = require_auth();

$stmt = db()->prepare(
    "SELECT id, email, full_name, role, phone, location,
            DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s') AS created_at
       FROM users
      WHERE id = ?
      LIMIT 1"
);
$stmt->execute([(int)$user['id']]);
json_response(true, $stmt->fetch());
