<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

try {
    $user = require_auth();
    $body = request_body();

    $farmId   = filter_var($body['farm_id'] ?? null, FILTER_VALIDATE_INT);
    $title    = trim((string)($body['title'] ?? ''));
    $category = trim((string)($body['category'] ?? '')) ?: 'General inspection';

    if ($farmId === false || $farmId === null) {
        json_response(false, null, 'farm_id is required', 400);
    }
    $owned = db()->prepare('SELECT 1 FROM farms WHERE id = ? AND owner_id = ? LIMIT 1');
    $owned->execute([$farmId, (int)$user['id']]);
    if (!$owned->fetch()) {
        json_response(false, null, 'Farm not found for this account', 404);
    }
    if ($title === '') {
        json_response(false, null, 'Title is required', 400);
    }

    $notes   = trim((string)($body['notes'] ?? ''));
    $fileUrl = trim((string)($body['file_url'] ?? ''));

    $createdAt = trim((string)($body['created_at'] ?? ''));
    $ts = $createdAt !== '' ? strtotime($createdAt) : false;
    $createdAt = $ts !== false ? date('Y-m-d H:i:s', $ts) : date('Y-m-d H:i:s');

    $stmt = db()->prepare(
        'INSERT INTO reports (user_id, farm_id, title, category, notes, file_url, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        (int)$user['id'],
        $farmId,
        $title,
        $category,
        $notes !== '' ? $notes : null,
        $fileUrl !== '' ? $fileUrl : null,
        $createdAt,
    ]);

    json_response(true, ['id' => (int)db()->lastInsertId()], 'Report submitted', 201);
} catch (Throwable $e) {
    json_response(false, null, 'Error: ' . $e->getMessage(), 500);
}
