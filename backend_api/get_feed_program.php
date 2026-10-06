<?php
/**
 * get_feed_program.php — GET
 * One round trip for NutritionService._loadProgram:
 *   { batch: {id, start_date} | null, phases: [...], history: [...] }
 *
 * `batch`   – the caller's most-recent flock batch (auto-seeded once the user
 *             owns a farm, see resolve_latest_batch()).
 * `phases`  – the batch's own feed phases when defined, otherwise the shared
 *             templates (batch_id IS NULL) seeded by schema.sql.
 * `history` – the batch's last 7 days of nutrition_logs, oldest first, for
 *             the "Nutrition history" strip.
 */
require_once __DIR__ . '/db_connect.php';

$user  = require_auth();
$batch = resolve_latest_batch((int)$user['id']);

$payload = ['batch' => null, 'phases' => [], 'history' => []];

if ($batch !== null) {
    $payload['batch'] = [
        'id'         => (int)$batch['id'],
        'start_date' => substr($batch['start_date'], 0, 10),
    ];
}

// Phases: prefer the batch's custom program, fall back to shared templates.
if ($batch !== null) {
    $stmt = db()->prepare(
        'SELECT name, start_day, end_day, crude_protein, crude_fat, crude_fiber,
                calcium, phosphorus, lysine, methionine, metabolizable_energy
           FROM feed_phases
          WHERE batch_id = ?
          ORDER BY start_day'
    );
    $stmt->execute([(int)$batch['id']]);
    $payload['phases'] = $stmt->fetchAll();
}

if (empty($payload['phases'])) {
    $payload['phases'] = db()->query(
        'SELECT name, start_day, end_day, crude_protein, crude_fat, crude_fiber,
                calcium, phosphorus, lysine, methionine, metabolizable_energy
           FROM feed_phases
          WHERE batch_id IS NULL
          ORDER BY start_day'
    )->fetchAll();
}

// History: last 7 recorded days for this batch's owner.
if ($batch !== null) {
    $stmt = db()->prepare(
        'SELECT log_date, feed_intake_g, body_weight_kg, fcr, notes
           FROM nutrition_logs
          WHERE batch_id = ? AND owner_id = ?
            AND log_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
          ORDER BY log_date DESC
          LIMIT 7'
    );
    $stmt->execute([(int)$batch['id'], (int)$user['id']]);
    $rows = $stmt->fetchAll();

    // Flutter parses log_date with DateTime.tryParse — normalise DATE output.
    foreach ($rows as &$row) {
        $row['log_date'] = str_replace(' ', 'T', substr($row['log_date'], 0, 10));
    }
    unset($row);
    $payload['history'] = array_reverse($rows); // oldest first for the strip
}

json_response(true, $payload);
