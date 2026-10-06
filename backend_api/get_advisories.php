<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

require_auth();

$stmt = db()->query(
    "SELECT id,
            title,
            category,
            situation,
            steps,
            resource_link,
            DATE_FORMAT(published_at, '%Y-%m-%dT%H:%i:%s') AS published_at
       FROM farming_advisories
      ORDER BY published_at DESC, id DESC"
);
json_response(true, $stmt->fetchAll());
