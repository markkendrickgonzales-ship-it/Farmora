<?php

require_once __DIR__ . '/db_connect.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, null, 'POST required', 405);
}
$user = require_auth();

if (empty($_FILES['file']) || ($_FILES['file']['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
    json_response(false, null, 'No file received (field name "file")', 400);
}

$file = $_FILES['file'];

if ($file['size'] > 15 * 1024 * 1024) {
    json_response(false, null, 'File is larger than 15 MB', 413);
}

$allowedExt  = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'];
$ext  = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $allowedExt, true)) {
    json_response(false, null, "File type .$ext is not allowed", 415);
}

$folder = preg_replace('/[^a-z_]/', '', strtolower((string)($_POST['folder'] ?? 'general')));
if (!in_array($folder, ['feeding_logs', 'reports', 'general'], true)) {
    $folder = 'general';
}

$uploadDir = __DIR__ . '/uploads/' . $folder;
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true)) {
    json_response(false, null, 'Could not create storage folder', 500);
}

$safeName = sprintf('u%d_%s_%s.%s',
    (int)$user['id'],
    date('Ymd_His'),
    bin2hex(random_bytes(4)),
    $ext);

$dest = $uploadDir . '/' . $safeName;
if (!move_uploaded_file($file['tmp_name'], $dest)) {
    json_response(false, null, 'Failed to store the file on the server', 500);
}
@chmod($dest, 0644);

json_response(true, [
    'url'  => FILE_BASE_URL . "/$folder/$safeName",
    'name' => $safeName,
    'size' => (int)$file['size'],
], 'File uploaded', 201);
