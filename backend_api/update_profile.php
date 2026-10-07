<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

try {
    $user = require_auth();

    $body       = request_body();
    $fullName   = trim((string)($body['full_name'] ?? ''));
    $role       = trim((string)($body['role'] ?? ''));
    $phone      = trim((string)($body['phone'] ?? ''));
    $location   = trim((string)($body['location'] ?? ''));

    if ($fullName === '' || mb_strlen($fullName) > 120) {
        json_response(false, null, 'Full name is required (max 120 chars)', 400);
    }

    $stmt = db()->prepare(
        'UPDATE users
            SET full_name = ?,
                role      = ?,
                phone     = ?,
                location  = ?
          WHERE id = ?'
    );
    $stmt->execute([
        $fullName,
        mb_substr($role !== '' ? $role : 'Farm manager', 0, 60),
        mb_substr($phone, 0, 40),
        mb_substr($location, 0, 120),
        (int)$user['id'],
    ]);

    $stmt = db()->prepare(
        'SELECT id, email, full_name, role, phone, location
           FROM users WHERE id = ? LIMIT 1'
    );
    $stmt->execute([(int)$user['id']]);
    json_response(true, $stmt->fetch(), 'Profile updated');
} catch (Throwable $e) {
    json_response(false, null, 'Error: ' . $e->getMessage(), 500);
}
