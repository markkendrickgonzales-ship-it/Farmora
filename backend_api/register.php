<?php
/**
 * register.php — POST { email, password, full_name? }
 * Creates the account and returns a session in one step (the app signs the
 * new user straight in, mirroring the old "email confirmation disabled"
 * Supabase behaviour).
 */
require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

$body    = request_body();
$email   = strtolower(trim($body['email'] ?? ''));
$pass    = (string)($body['password'] ?? '');
$fullNom = trim($body['full_name'] ?? '');

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_response(false, null, 'Please enter a valid email address.', 400);
}
if (strlen($pass) < 6) {
    json_response(false, null, 'Password must be at least 6 characters.', 400);
}

$pdo = db();
$stmt = $pdo->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
$stmt->execute([$email]);
if ($stmt->fetch()) {
    json_response(false, null, 'An account with this email already exists.', 409);
}

$stmt = $pdo->prepare(
    'INSERT INTO users (email, password_hash, full_name) VALUES (?, ?, ?)'
);
$stmt->execute([$email, password_hash($pass, PASSWORD_DEFAULT), $fullNom]);
$userId = (int)$pdo->lastInsertId();

// New farmers start with a demo farm so the dashboard has something to show.
$stmt = $pdo->prepare(
    'INSERT INTO farms (owner_id, farm_name, location, farm_type) VALUES (?, ?, ?, ?)'
);
$stmt->execute([$userId, 'My First Farm', '', 'Poultry']);

json_response(true, [
    'token'     => issue_token($userId),
    'user_id'   => $userId,
    'email'     => $email,
    'full_name' => $fullNom,
], 'Account created', 201);
