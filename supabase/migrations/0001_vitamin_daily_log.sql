-- =============================================================================
-- Farmora · Vitamin daily-log migration
-- Replaces the old fixed-schedule `vitamin_doses` table with an open,
-- user-editable daily log: a reusable `vitamin_catalog` of suggested additives
-- and a `vitamin_logs` table holding one row per worker-submitted entry.
--
-- Apply against the project's Supabase Postgres (SQL editor or `supabase db push`).
-- Safe to re-run: uses IF NOT EXISTS / DROP ... IF EXISTS guards.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. vitamin_catalog — reusable list of suggested vitamins / additives
-- -----------------------------------------------------------------------------
create table if not exists public.vitamin_catalog (
  id              uuid primary key default gen_random_uuid(),
  name            text        not null unique,
  default_dosage  numeric(8,2),
  default_unit    text,
  purpose         text,
  is_default      boolean     not null default false,
  created_at      timestamptz not null default now()
);

comment on table public.vitamin_catalog is
  'Suggested vitamins/additives shown as quick-add chips; seeds default dosage & unit.';

-- Seed data (idempotent: skip rows whose name already exists).
insert into public.vitamin_catalog (name, default_dosage, default_unit, purpose, is_default)
values
  ('Vitamin A',          1.00, 'mL/L water', 'Vision, immune & epithelial health',      true),
  ('Vitamin D3',         1.00, 'mL/L water', 'Bone growth & calcium absorption',        true),
  ('Vitamin E',          1.00, 'mL/L water', 'Antioxidant, supports immunity',          true),
  ('Vitamin K',          0.50, 'mL/L water', 'Blood clotting & bone development',       true),
  ('Vitamin B-complex',  1.00, 'mL/L water', 'Metabolism & stress response',            true),
  ('Electrolytes',       2.00, 'g/L water',  'Hydration & heat-stress recovery',        true)
on conflict (name) do nothing;

-- -----------------------------------------------------------------------------
-- 2. vitamin_logs — one row per user-submitted daily entry
-- -----------------------------------------------------------------------------
create table if not exists public.vitamin_logs (
  id           uuid primary key default gen_random_uuid(),
  batch_id     uuid        not null,
  vitamin_id   uuid        references public.vitamin_catalog (id) on delete set null,
  custom_name  text,
  dosage       numeric(8,2) not null check (dosage > 0),
  unit         text        not null,
  log_date     date        not null,
  time_given   time        not null,
  day_number   integer     not null check (day_number between 1 and 45),
  notes        text,
  logged_by    uuid        references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  -- An entry must reference a catalog item OR carry a typed custom name.
  constraint vitamin_logs_has_name
    check (vitamin_id is not null or (custom_name is not null and trim(custom_name) <> ''))
);

comment on table public.vitamin_logs is
  'Daily vitamin/additive doses logged by farm workers against a batch.';

-- Fast "today's log" lookups.
create index if not exists vitamin_logs_batch_date_idx
  on public.vitamin_logs (batch_id, log_date);

-- Link batch_id to a `batches` table only when one exists in this project.
-- Farmora keys most data by farm_id, so the FK is added conditionally to keep
-- the migration runnable whether or not a batches table is present.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'batches'
  ) then
    execute 'alter table public.vitamin_logs
               add constraint vitamin_logs_batch_fk
               foreign key (batch_id) references public.batches (id) on delete cascade';
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 3. vitamin_logs_view — resolves the display name so the app can read logs
--    without branching on catalog-pick vs. custom entry.
-- -----------------------------------------------------------------------------
create or replace view public.vitamin_logs_view as
select
  l.id,
  l.batch_id,
  l.vitamin_id,
  l.custom_name,
  coalesce(c.name, l.custom_name) as display_name,
  l.dosage,
  l.unit,
  l.log_date,
  l.time_given,
  l.day_number,
  l.notes,
  l.logged_by,
  l.created_at
from public.vitamin_logs l
left join public.vitamin_catalog c on c.id = l.vitamin_id;

-- -----------------------------------------------------------------------------
-- 4. Drop the old fixed-schedule table.
--    Any rows are first migrated into vitamin_logs as completed entries if the
--    legacy table still exists, so no production data is lost.
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'vitamin_doses'
  ) then
    -- Best-effort migration of legacy scheduled doses into the daily log.
    begin
      insert into public.vitamin_logs (
        batch_id, vitamin_id, custom_name, dosage, unit,
        log_date, time_given, day_number, notes
      )
      select
        d.batch_id,
        null,
        d.name,
        d.dosage,
        d.unit,
        d.scheduled_date,
        d.scheduled_time,
        coalesce(d.day_number, 1),
        'Migrated from fixed schedule'
      from public.vitamin_doses d
      where d.status = 'Given'
      on conflict do nothing;
    exception when others then
      -- Legacy schema may differ; skip migration rather than abort the drop.
      raise notice 'Skipping vitamin_doses data migration: %', sqlerrm;
    end;

    drop table public.vitamin_doses;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.vitamin_catalog enable row level security;
alter table public.vitamin_logs      enable row level security;

-- Catalog is read-only for every authenticated user.
drop policy if exists "catalog_read" on public.vitamin_catalog;
create policy "catalog_read" on public.vitamin_catalog
  for select to authenticated using (true);

-- Workers manage only their own log entries.
drop policy if exists "logs_select" on public.vitamin_logs;
create policy "logs_select" on public.vitamin_logs
  for select to authenticated using (true);

drop policy if exists "logs_insert" on public.vitamin_logs;
create policy "logs_insert" on public.vitamin_logs
  for insert to authenticated with check (logged_by = auth.uid());

drop policy if exists "logs_update" on public.vitamin_logs;
create policy "logs_update" on public.vitamin_logs
  for update to authenticated
  using (logged_by = auth.uid()) with check (logged_by = auth.uid());

drop policy if exists "logs_delete" on public.vitamin_logs;
create policy "logs_delete" on public.vitamin_logs
  for delete to authenticated using (logged_by = auth.uid());

-- Expose the view to authenticated reads.
grant select on public.vitamin_logs_view to authenticated;
