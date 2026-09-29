-- =============================================================================
-- Farmora · Per-user data isolation (Row Level Security)
--
-- Every business table except `profiles` and `vitamin_logs` is currently
-- readable/writable by ANY authenticated user, so one account sees another
-- account's farms, telemetry, alerts, feeding logs and reports.
--
-- This migration:
--   1. adds an `owner_id` column to each user-owned table (idempotent),
--   2. backfills existing rows to the oldest user so no data disappears
--      when RLS turns on (reassign afterwards if you have several accounts),
--   3. enables RLS and creates owner-only policies on every app-facing table,
--   4. scopes device-written tables (sensor_telemetry / alerts) through farm
--      ownership, and feeding_logs through the farm link as well,
--   5. tightens vitamin_logs SELECT (was `using (true)`) and rebuilds
--      vitamin_logs_view as a security-invoker view so RLS actually applies
--      through it, and adds a farm_id trigger default for device writes.
--
-- Safe to re-run: IF NOT EXISTS / DROP POLICY IF EXISTS / CREATE OR REPLACE.
-- Apply via the SQL editor or `supabase db push`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Helper: oldest user, used to backfill legacy rows.
-- -----------------------------------------------------------------------------
do $$
declare
  legacy_owner uuid;
begin
  select id into legacy_owner from auth.users order by created_at limit 1;

  -- ---------------------------------------------------------------------------
  -- 1. Owner columns (only when the table exists and the column is missing).
  -- ---------------------------------------------------------------------------
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'farms') then
    alter table public.farms add column if not exists owner_id uuid
      references auth.users (id) on delete set null;
    update public.farms set owner_id = legacy_owner
      where owner_id is null and legacy_owner is not null;
  end if;

  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'batches') then
    alter table public.batches add column if not exists owner_id uuid
      references auth.users (id) on delete set null;
    update public.batches set owner_id = legacy_owner
      where owner_id is null and legacy_owner is not null;
  end if;

  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'feeding_logs') then
    alter table public.feeding_logs add column if not exists user_id uuid
      references auth.users (id) on delete set null;
    -- Backfill through the farm link where possible.
    update public.feeding_logs fl set user_id = f.owner_id
      from public.farms f
      where fl.user_id is null
        and fl.farm_id::text = f.farm_id::text;
  end if;

  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'reports') then
    alter table public.reports add column if not exists user_id uuid
      references auth.users (id) on delete set null;
    update public.reports r set user_id = f.owner_id
      from public.farms f
      where r.user_id is null
        and r.farm_id::text = f.farm_id::text;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 2. RLS + owner policies on farms / batches / feeding_logs / reports.
-- -----------------------------------------------------------------------------

-- farms ---------------------------------------------------------------------
alter table public.farms enable row level security;

drop policy if exists "farms_select_owner" on public.farms;
create policy "farms_select_owner" on public.farms
  for select to authenticated using (owner_id = auth.uid());

drop policy if exists "farms_insert_owner" on public.farms;
create policy "farms_insert_owner" on public.farms
  for insert to authenticated with check (owner_id = auth.uid());

-- Auto-assign the caller as owner when a farm is created without owner_id.
create or replace function public.set_farms_owner()
  returns trigger language plpgsql as $$
begin
  if new.owner_id is null then new.owner_id := auth.uid(); end if;
  return new;
end $$;

drop trigger if exists farms_set_owner on public.farms;
create trigger farms_set_owner
  before insert on public.farms
  for each row execute function public.set_farms_owner();

-- batches ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'batches') then
    alter table public.batches enable row level security;

    drop policy if exists "batches_select_owner" on public.batches;
    create policy "batches_select_owner" on public.batches
      for select to authenticated using (owner_id = auth.uid());

    drop policy if exists "batches_write_owner" on public.batches;
    create policy "batches_write_owner" on public.batches
      for all to authenticated
      using (owner_id = auth.uid()) with check (owner_id = auth.uid());
  end if;
end
$$;

-- feeding_logs ----------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'feeding_logs') then
    alter table public.feeding_logs enable row level security;

    -- Owner column OR a row whose farm belongs to the caller.
    drop policy if exists "feeding_logs_owner" on public.feeding_logs;
    create policy "feeding_logs_owner" on public.feeding_logs
      for all to authenticated
      using (
        user_id = auth.uid()
        or exists (
          select 1 from public.farms f
          where f.farm_id::text = feeding_logs.farm_id::text
            and f.owner_id = auth.uid()
        )
      )
      with check (
        user_id = auth.uid()
        or exists (
          select 1 from public.farms f
          where f.farm_id::text = feeding_logs.farm_id::text
            and f.owner_id = auth.uid()
        )
      );
  end if;
end
$$;

-- reports ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'reports') then
    alter table public.reports enable row level security;

    drop policy if exists "reports_owner" on public.reports;
    create policy "reports_owner" on public.reports
      for all to authenticated
      using (
        user_id = auth.uid()
        or exists (
          select 1 from public.farms f
          where f.farm_id::text = reports.farm_id::text
            and f.owner_id = auth.uid()
        )
      )
      with check (
        user_id = auth.uid()
        or exists (
          select 1 from public.farms f
          where f.farm_id::text = reports.farm_id::text
            and f.owner_id = auth.uid()
        )
      );

    create or replace function public.set_reports_owner()
      returns trigger language plpgsql as $$
    begin
      if new.user_id is null then new.user_id := auth.uid(); end if;
      return new;
    end $$;

    drop trigger if exists reports_set_owner on public.reports;
    create trigger reports_set_owner
      before insert on public.reports
      for each row execute function public.set_reports_owner();
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 3. Device-written tables: sensor_telemetry & alerts are scoped through the
--    owning farm, because the sensor inserts rows without a user session.
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'sensor_telemetry') then
    alter table public.sensor_telemetry enable row level security;

    drop policy if exists "telemetry_select_own_farm" on public.sensor_telemetry;
    create policy "telemetry_select_own_farm" on public.sensor_telemetry
      for select to authenticated
      using (
        exists (
          select 1 from public.farms f
          where f.farm_id::text = sensor_telemetry.farm_id::text
            and f.owner_id = auth.uid()
        )
      );

    -- Device/ingestion writes: only require that the farm exists and is
    -- claimed. Until the sensor uses a service role key, an insert-time
    -- trigger attaches the farm owner so the row is immediately visible.
    create or replace function public.set_telemetry_farm_owner()
      returns trigger language plpgsql as $$
    declare
      farm_owner uuid;
    begin
      select f.owner_id into farm_owner
        from public.farms f
        where f.farm_id::text = new.farm_id::text
        limit 1;
      if farm_owner is not null then
        new.user_id := farm_owner;
      end if;
      return new;
    end $$;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'sensor_telemetry'
        and column_name = 'user_id'
    ) then
      drop trigger if exists telemetry_set_owner on public.sensor_telemetry;
      create trigger telemetry_set_owner
        before insert on public.sensor_telemetry
        for each row execute function public.set_telemetry_farm_owner();
    end if;
  end if;

  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'alerts') then
    alter table public.alerts enable row level security;

    drop policy if exists "alerts_select_own_farm" on public.alerts;
    create policy "alerts_select_own_farm" on public.alerts
      for select to authenticated
      using (
        exists (
          select 1 from public.farms f
          where f.farm_id::text = alerts.farm_id::text
            and f.owner_id = auth.uid()
        )
      );
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 4. vitamin_logs: SELECT was `using (true)` — tighten to the logger.
--    Legacy rows with logged_by = NULL stay visible to their farm's owner.
-- -----------------------------------------------------------------------------
drop policy if exists "logs_select" on public.vitamin_logs;
create policy "logs_select" on public.vitamin_logs
  for select to authenticated
  using (
    logged_by = auth.uid()
    or (
      logged_by is null
      and exists (
        select 1 from public.farms f
        where f.farm_id::text = vitamin_logs.batch_id::text
          and f.owner_id = auth.uid()
      )
    )
  );

-- -----------------------------------------------------------------------------
-- 5. vitamin_logs_view must NOT bypass RLS. Postgres defaults to security_invoker
--    for views not explicitly DEFINER, but the view was created by postgres (the
--    Supabase superuser, which bypasses RLS). Recreate it as owner-role-owned
--    with security_invoker = true so queries through the view are filtered by
--    the vitamin_logs policies.
-- -----------------------------------------------------------------------------
drop view if exists public.vitamin_logs_view;
create view public.vitamin_logs_view
with (security_invoker = true) as
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

grant select on public.vitamin_logs_view to authenticated;

-- -----------------------------------------------------------------------------
-- 6. profiles: one row per auth user, owner-only.
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'profiles') then
    alter table public.profiles enable row level security;

    drop policy if exists "profiles_select_self" on public.profiles;
    create policy "profiles_select_self" on public.profiles
      for select to authenticated using (id = auth.uid());

    drop policy if exists "profiles_upsert_self" on public.profiles;
    create policy "profiles_upsert_self" on public.profiles
      for insert to authenticated with check (id = auth.uid());

    drop policy if exists "profiles_update_self" on public.profiles;
    create policy "profiles_update_self" on public.profiles
      for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
  end if;
end
$$;
