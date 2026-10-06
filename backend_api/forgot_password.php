<?php

require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}

const RESET_LINK_BASE = 'https://frmora.space/reset-password';

$email = strtolower(trim(request_body()['email'] ?? ''));
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_response(false, null, 'Please enter a valid email address.', 400);
}

$stmt = db()->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
$stmt->execute([$email]);
$user = $stmt->fetch();

if ($user) {
    $token = new_token();
    $stmt = db()->prepare(
        'INSERT INTO password_resets (token, user_id, expires_at)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))'
    );
    $stmt->execute([$token, (int)$user['id']]);

    $link = RESET_LINK_BASE . '?token=' . $token;
    @mail(
        $email,
        'Farmora password reset',
        "Use this link within one hour to choose a new password:\n\n{$link}\n\nIf you did not request this, ignore this email."
    );
}

json_response(true, null, 'If the address exists, a reset link has been sent.');
