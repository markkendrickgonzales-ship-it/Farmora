<?php

ob_start();
require_once __DIR__ . '/db_connect.php';

try {
    $user  = require_auth();
    $batch = resolve_latest_batch((int)$user['id']);

    $catalogRes = db()->query(
        'SELECT id, name, default_dosage, default_unit, purpose, is_default
           FROM vitamin_catalog
          ORDER BY is_default DESC, name'
    );
    $catalog = $catalogRes ? $catalogRes->fetchAll() : [];

    // Query logs directly or via view if available
    $stmt = db()->prepare(
        'SELECT id, vitamin_id, display_name, custom_name, dosage, unit,
                log_date, time_given, day_number, notes
           FROM vitamin_logs_view
          WHERE logged_by = ? AND log_date = CURDATE()
          ORDER BY time_given DESC'
    );
    $stmt->execute([(int)$user['id']]);
    $logs = $stmt->fetchAll();

    json_response(true, [
        'batch_id'   => $batch !== null ? (int)$batch['id'] : null,
        'day_number' => $batch !== null ? batch_day_number($batch['start_date']) : 1,
        'catalog'    => $catalog,
        'logs'       => $logs,
    ]);
} catch (Throwable $e) {
    json_response(false, null, 'Error: ' . $e->getMessage(), 500);
}
