-- ============================================================================
-- Farmora — Hostinger MySQL schema (replaces the former Supabase/Postgres DB)
-- Import through phpMyAdmin (hPanel → Databases → phpMyAdmin) or:
--   mysql -u u000000000_farmora -p u000000000_farmora < schema.sql
-- ============================================================================

SET NAMES utf8mb4;

-- ── Auth (replaces Supabase Auth) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name     VARCHAR(120) NOT NULL DEFAULT '',
  role          VARCHAR(60)  NOT NULL DEFAULT 'Farm manager',
  phone         VARCHAR(40)  NOT NULL DEFAULT '',
  location      VARCHAR(120) NOT NULL DEFAULT '',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auth_tokens (
  token      CHAR(64)     PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME     NOT NULL,
  CONSTRAINT fk_token_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_token_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS password_resets (
  token       CHAR(64)     PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  expires_at  DATETIME     NOT NULL,
  used        TINYINT(1)   NOT NULL DEFAULT 0,
  CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Core farm data (per-user isolation via owner_id / user_id) ──────────────
CREATE TABLE IF NOT EXISTS farms (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_id   INT UNSIGNED NOT NULL,
  farm_name  VARCHAR(150) NOT NULL,
  location   VARCHAR(150) NOT NULL DEFAULT '',
  farm_type  VARCHAR(60)  NOT NULL DEFAULT 'Poultry',
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_farm_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_farm_owner (owner_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batches (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_id   INT UNSIGNED NOT NULL,
  farm_id    INT UNSIGNED NULL,
  start_date DATE NOT NULL,
  flock_size INT  NOT NULL DEFAULT 0,
  CONSTRAINT fk_batch_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_batch_owner (owner_id, start_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sensor_telemetry (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  farm_id          INT UNSIGNED NOT NULL,
  temperature_c    DECIMAL(6,2) NULL,
  humidity_percent DECIMAL(6,2) NULL,
  power_load_kw    DECIMAL(8,2) NULL,
  ammonia_ppm      DECIMAL(8,2) NULL,
  status           VARCHAR(20)  NOT NULL DEFAULT 'ok',
  recorded_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_telemetry_farm FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE,
  INDEX idx_telemetry_farm (farm_id, recorded_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alerts (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  farm_id      INT UNSIGNED NOT NULL,
  severity     VARCHAR(20)  NOT NULL DEFAULT 'warning',   -- info | warning | critical
  alert_type   VARCHAR(100) NOT NULL DEFAULT 'Alert',
  message      VARCHAR(255) NOT NULL DEFAULT '',
  triggered_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_alert_farm FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE,
  INDEX idx_alert_farm (farm_id, created_at)
) ENGINE=InnoDB;

-- ── Feeding logs (Farm Logs feature) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feeding_logs (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id        INT UNSIGNED NOT NULL,
  farm_id        INT UNSIGNED NOT NULL,
  action_type    VARCHAR(30)  NOT NULL,                   -- Feeding | Watering
  amount         DECIMAL(10,2) NOT NULL,
  unit           VARCHAR(10)  NOT NULL DEFAULT 'kg',
  trigger_source VARCHAR(20)  NOT NULL DEFAULT 'manual',
  notes          TEXT NULL,
  image_url      VARCHAR(255) NULL,                       -- from upload_file.php
  action_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_log_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_log_farm FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE,
  INDEX idx_log_user_farm (user_id, farm_id, action_time)
) ENGINE=InnoDB;

-- ── Reports (Reports feature) ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  farm_id    INT UNSIGNED NOT NULL,
  title      VARCHAR(190) NOT NULL,
  category   VARCHAR(60)  NOT NULL DEFAULT 'General inspection',
  notes      TEXT NULL,
  file_url   VARCHAR(255) NULL,                           -- photo/document from upload_file.php
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_report_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_report_farm FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE,
  INDEX idx_report_user_farm (user_id, farm_id, created_at)
) ENGINE=InnoDB;

-- ── Nutrition: feed phases + daily logs ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS feed_phases (
  id                   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  batch_id             INT UNSIGNED NULL,                 -- NULL = shared template
  name                 VARCHAR(60) NOT NULL,              -- Starter | Grower | Finisher
  start_day            INT NOT NULL,
  end_day              INT NOT NULL,
  crude_protein        DECIMAL(6,2) NOT NULL DEFAULT 0,
  crude_fat            DECIMAL(6,2) NOT NULL DEFAULT 0,
  crude_fiber          DECIMAL(6,2) NOT NULL DEFAULT 0,
  calcium              DECIMAL(6,2) NOT NULL DEFAULT 0,
  phosphorus           DECIMAL(6,2) NOT NULL DEFAULT 0,
  lysine               DECIMAL(6,2) NOT NULL DEFAULT 0,
  methionine           DECIMAL(6,2) NOT NULL DEFAULT 0,
  metabolizable_energy DECIMAL(9,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_phase_batch FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE,
  INDEX idx_phase_batch (batch_id, start_day)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS nutrition_logs (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  batch_id        INT UNSIGNED NOT NULL,
  owner_id        INT UNSIGNED NOT NULL,
  log_date        DATE NOT NULL,
  feed_intake_g   DECIMAL(9,2) NOT NULL DEFAULT 0,
  body_weight_kg  DECIMAL(8,3) NULL,
  fcr             DECIMAL(8,3) NULL,
  notes           VARCHAR(255) NULL,
  UNIQUE KEY uq_nutrition_batch_date (batch_id, log_date), -- upsert target
  CONSTRAINT fk_nut_batch FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE,
  CONSTRAINT fk_nut_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Vitamins: catalog + daily doses ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vitamin_catalog (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  default_dosage  DECIMAL(10,3) NULL,
  default_unit    VARCHAR(30)  NULL,
  purpose         VARCHAR(190) NULL,
  is_default      TINYINT(1)   NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vitamin_logs (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  batch_id    INT UNSIGNED NOT NULL,
  vitamin_id  INT UNSIGNED NULL,               -- NULL for custom entries
  custom_name VARCHAR(100) NULL,
  dosage      DECIMAL(10,3) NOT NULL,
  unit        VARCHAR(30) NOT NULL,
  log_date    DATE NOT NULL,
  time_given  TIME NOT NULL,
  day_number  INT NOT NULL DEFAULT 1,
  notes       VARCHAR(255) NULL,
  logged_by   INT UNSIGNED NOT NULL,           -- owner column (was RLS-filtered)
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_vlog_vitamin FOREIGN KEY (vitamin_id) REFERENCES vitamin_catalog(id) ON DELETE SET NULL,
  CONSTRAINT fk_vlog_user FOREIGN KEY (logged_by) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_vlog_day (batch_id, log_date, logged_by)
) ENGINE=InnoDB;

-- Display-name view (COALESCE of catalog name and custom name), like the old
-- Supabase vitamin_logs_view the app reads through vitamins.php.
CREATE OR REPLACE VIEW vitamin_logs_view AS
SELECT v.id,
       v.batch_id,
       v.vitamin_id,
       COALESCE(c.name, v.custom_name, 'Vitamin') AS display_name,
       v.custom_name,
       v.dosage,
       v.unit,
       v.log_date,
       v.time_given,
       v.day_number,
       v.notes,
       v.logged_by
  FROM vitamin_logs v
  LEFT JOIN vitamin_catalog c ON c.id = v.vitamin_id;

-- ── Advisory & Guides content ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS farming_advisories (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title        VARCHAR(190) NOT NULL,
  category     VARCHAR(80)  NOT NULL DEFAULT 'General',
  situation    TEXT NULL,
  steps        TEXT NULL,                      -- JSON-encoded array of strings
  resource_link VARCHAR(300) NULL,
  published_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================================
-- Seed data: shared feed-phase templates, vitamin catalog and sample guides.
-- Create your first account through the app's "Create account" screen — it
-- lands in `users` with a properly hashed password (never insert hashes here).
-- ============================================================================

INSERT INTO feed_phases (batch_id, name, start_day, end_day, crude_protein, crude_fat, crude_fiber, calcium, phosphorus, lysine, methionine, metabolizable_energy)
VALUES
 (NULL, 'Starter',  1, 10, 23.00, 5.00, 4.00, 0.90, 0.45, 1.30, 0.50, 2900.00),
 (NULL, 'Grower',  11, 24, 21.00, 5.50, 4.50, 0.85, 0.42, 1.15, 0.44, 3000.00),
 (NULL, 'Finisher', 25, 45, 19.00, 6.00, 5.00, 0.80, 0.40, 1.00, 0.40, 3100.00);

INSERT INTO vitamin_catalog (name, default_dosage, default_unit, purpose, is_default)
VALUES
 ('Multivitamin AD3E', 1.0,  'mL/L water',  'General vitality & growth support', 1),
 ('Vitamin C',         0.5,  'g/L water',   'Heat-stress relief',                1),
 ('Electrolytes',      1.0,  'g/L water',   'Hydration after transport / shock', 1),
 ('Probiotic',         0.25, 'g/L water',   'Gut flora balance',                 0),
 ('Vitamin K3',        0.3,  'mg/bird',     'Clotting support during coccidiosis therapy', 0);

INSERT INTO farming_advisories (title, category, situation, steps, resource_link)
VALUES
 ('Heat stress in broiler houses', 'Climate',
  'During sustained temperatures above 32 C, birds pant, eat less and can die.',
  '["Increase ventilation to maximum before 10:00", "Provide electrolyte + vitamin C water", "Raise drinker count so no bird walks more than 3 meters", "Shift feeding to the cool evening hours"]',
  'https://www.fao.org/animal-health/en/'),
 ('Biosecurity entry routine', 'Health',
  'Most disease outbreaks are traced to people and equipment entering the house.',
  '["Footbath refreshed daily", "Dedicated house boots and overalls", "Visitor log kept at the door", "Bird-free zone of 3 m around house perimeter"]',
  NULL);
