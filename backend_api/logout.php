<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

$token = bearer_token();
if ($token) {
    $stmt = db()->prepare('DELETE FROM auth_tokens WHERE token = ?');
    $stmt->execute([$token]);
}

json_response(true, null, 'Signed out');
