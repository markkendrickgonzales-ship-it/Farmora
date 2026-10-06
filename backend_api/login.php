<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

$body  = request_body();
$email = strtolower(trim($body['email'] ?? ''));
$pass  = (string)($body['password'] ?? '');

if ($email === '' || $pass === '') {
    json_response(false, null, 'Please enter email and password.', 400);
}

$stmt = db()->prepare(
    'SELECT id, email, full_name, password_hash FROM users WHERE email = ? LIMIT 1'
);
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($pass, $user['password_hash'])) {
    json_response(false, null, 'Invalid email or password.', 401);
}

json_response(true, [
    'token' => issue_token((int)$user['id']),
    'user'  => [
        'id'        => (int)$user['id'],
        'email'     => $user['email'],
        'full_name' => $user['full_name'],
    ],
]);
