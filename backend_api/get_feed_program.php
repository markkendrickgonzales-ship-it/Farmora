<?php

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

    foreach ($rows as &$row) {
        $row['log_date'] = str_replace(' ', 'T', substr($row['log_date'], 0, 10));
    }
    unset($row);
    $payload['history'] = array_reverse($rows);
}

json_response(true, $payload);
