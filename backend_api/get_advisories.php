<?php
/**
 * get_advisories.php — GET
 * Shared Advisory & Guides content from `farming_advisories`. The rows are
 * public editorial content (not user data), but the endpoint still requires a
 * signed-in caller so the API stays closed to anonymous traffic.
 */
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
