<?php
/**
 * vitamins.php — GET
 * One round trip for VitaminService._fetchAll:
 *   { batch_id, day_number, catalog: [...], logs: [...] }
 *
 * `batch_id` / `day_number`  – resolved from the caller's most-recent batch
 *                              (auto-seeded once the user owns a farm).
 * `catalog`                  – shared vitamin_catalog rows for the quick-add
 *                              chips.
 * `logs`                     – the caller's OWN doses for today, read through
 *                              vitamin_logs_view (display_name = COALESCE of
 *                              catalog name and custom_name), newest first.
 */
require_once __DIR__ . '/db_connect.php';

$user  = require_auth();
$batch = resolve_latest_batch((int)$user['id']);

$catalog = db()->query(
    'SELECT id, name, default_dosage, default_unit, purpose, is_default
       FROM vitamin_catalog
      ORDER BY is_default DESC, name'
)->fetchAll();

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
