<?php
/**
 * db_connect.php — shared bootstrap for every Farmora API endpoint.
 *
 * Hostinger setup:
 *   1. Create a MySQL database + user in hPanel → MySQL (use them below).
 *   2. Upload this whole folder to public_html/api (or your sub-folder).
 *   3. Import schema.sql via phpMyAdmin.
 *   4. Set FILE_BASE_URL to the public URL of this folder + '/uploads'.
 */

// ── Hostinger MySQL credentials (edit these) ────────────────────────────────
define('DB_HOST', 'localhost');            // Hostinger is always 'localhost'
define('DB_NAME', 'u000000000_farmora');   // from hPanel → MySQL
define('DB_USER', 'u000000000_farmora');   // from hPanel → MySQL
define('DB_PASS', 'CHANGE_ME');            // the DB user's password
define('DB_PORT', 3306);

// Public base used to build download URLs returned by upload_file.php.
define('FILE_BASE_URL', 'https://yourdomain.com/api/uploads');

// Session token lifetime.
define('TOKEN_TTL_SECONDS', 60 * 60 * 24 * 30); // 30 days

// ── Transport ───────────────────────────────────────────────────────────────
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

/** PDO connection (lazy, shared per request). */
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
            json_response(false, null, 'Database connection failed', 500);
        }
    }
    return $pdo;
}

/** The single JSON envelope the Flutter ApiService expects. */
function json_response(bool $success, $data = null, ?string $message = null, int $status = 200): void
{
    http_response_code($status);
    echo json_encode(['success' => $success, 'data' => $data, 'message' => $message]);
    exit;
}

/** Decoded JSON request body (empty array when absent). */
function request_body(): array
{
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw ?: '[]', true);
    return is_array($decoded) ? $decoded : [];
}

/** Bearer token from the Authorization header. */
function bearer_token(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';
    if (stripos($header, 'Bearer ') === 0) {
        return substr($header, 7);
    }
    // Apache on shared hosting sometimes strips Authorization; allow a field.
    return $_POST['token'] ?? request_body()['token'] ?? null;
}

/**
 * Resolves the caller from the bearer token. Answers 401 and exits when the
 * token is missing or expired — every data endpoint calls this first, which
 * is the MySQL replacement for Supabase's per-user RLS: all queries below
 * it are filtered by the returned user id.
 */
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

/** Fresh opaque session token. */
function new_token(): string
{
    return bin2hex(random_bytes(32));
}

/** Creates (and optionally replaces) a session row, returns the token. */
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

// ── Batch helpers (nutrition + vitamins) ────────────────────────────────────

/**
 * The caller's most-recent broiler batch. A user who already has a farm but
 * no batches row gets one started today, so the daily nutrition/vitamin
 * screens always have something to log against. Null only for brand-new
 * accounts without any farm.
 */
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

    // Seed a batch from the user's newest farm (register.php always makes one).
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

/** Flock day number (1-based, capped at the 45-day program) for a start date. */
function batch_day_number(string $startDate): int
{
    $start = new DateTime(substr($startDate, 0, 10));
    $today = new DateTime('today');
    $day = $today->diff($start)->days + 1;
    return min(max($day, 1), 45);
}
