<?php

ob_start();

error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

if (is_file(__DIR__ . '/config.php')) {
    require_once __DIR__ . '/config.php';
} else {
    define('DB_HOST', 'localhost');
   define('DB_NAME', 'u900587911_Farmora');
define('DB_USER', 'u900587911_farmora');
define('DB_PASS', 'Farmora123');
    define('DB_PORT', 3306);
}

define('FILE_BASE_URL', 'https://frmora.space/api/uploads');

define('TOKEN_TTL_SECONDS', 60 * 60 * 24 * 30);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    http_response_code(200);
    exit();
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, DB_NAME);
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        } catch (PDOException $e) {
            $detail = (defined('DB_DEBUG') && DB_DEBUG && PHP_OS_FAMILY === 'Windows')
                ? 'Database connection failed: ' . $e->getMessage()
                : 'Database connection failed';
            json_response(false, null, $detail, 500);
        }
    }
    return $pdo;
}

function json_response(bool $success, $data = null, ?string $message = null, int $status = 200): void
{
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    http_response_code($status);
    echo json_encode(['success' => $success, 'data' => $data, 'message' => $message]);
    exit();
}

function request_body(): array
{
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw ?: '[]', true);
    return is_array($decoded) ? $decoded : [];
}

function bearer_token(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';
    if (stripos($header, 'Bearer ') === 0) {
        return substr($header, 7);
    }

    return $_POST['token'] ?? request_body()['token'] ?? null;
}

function require_auth(): array
{
    $token = bearer_token();
    if (!$token) {
        json_response(false, null, 'Missing authentication token', 401);
    }
    $stmt = db()->prepare(
        'SELECT u.id, u.email, u.full_name
           FROM auth_tokens t
           JOIN users u ON u.id = t.user_id
          WHERE t.token = ? AND t.expires_at > NOW()
          LIMIT 1'
    );
    $stmt->execute([$token]);
    $user = $stmt->fetch();
    if (!$user) {
        json_response(false, null, 'Session expired, please sign in again', 401);
    }
    return $user;
}

function new_token(): string
{
    return bin2hex(random_bytes(32));
}

function issue_token(int $userId, bool $replaceExisting = false): string
{
    $pdo = db();
    if ($replaceExisting) {
        $stmt = $pdo->prepare('DELETE FROM auth_tokens WHERE user_id = ?');
        $stmt->execute([$userId]);
    }
    $token = new_token();
    $stmt = $pdo->prepare(
        'INSERT INTO auth_tokens (token, user_id, expires_at)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ' . TOKEN_TTL_SECONDS . ' SECOND))'
    );
    $stmt->execute([$token, $userId]);
    return $token;
}

function resolve_latest_batch(int $userId): ?array
{
    $pdo = db();
    $stmt = $pdo->prepare(
        'SELECT id, farm_id, start_date, flock_size
           FROM batches
          WHERE owner_id = ?
          ORDER BY start_date DESC, id DESC
          LIMIT 1'
    );
    $stmt->execute([$userId]);
    $batch = $stmt->fetch();
    if ($batch) {
        return $batch;
    }

    $stmt = $pdo->prepare(
        'SELECT id FROM farms WHERE owner_id = ? ORDER BY id DESC LIMIT 1'
    );
    $stmt->execute([$userId]);
    $farm = $stmt->fetch();
    if (!$farm) {
        return null;
    }
    $pdo->prepare(
        'INSERT INTO batches (owner_id, farm_id, start_date, flock_size)
         VALUES (?, ?, CURDATE(), 0)'
    )->execute([$userId, (int)$farm['id']]);
    $id = (int)$pdo->lastInsertId();
    return ['id' => $id, 'farm_id' => (int)$farm['id'],
            'start_date' => date('Y-m-d'), 'flock_size' => 0];
}

function batch_day_number(string $startDate): int
{
    $start = new DateTime(substr($startDate, 0, 10));
    $today = new DateTime('today');
    $day = $today->diff($start)->days + 1;
    return min(max($day, 1), 45);
}
?>
