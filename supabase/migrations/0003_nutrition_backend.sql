-- =============================================================================
-- Farmora · Nutrition backend
--
-- Replaces the hardcoded demo feed program in the app's NutritionService with
-- real tables:
--   * feed_phases     — Starter/Grower/Finisher targets (guaranteed analysis)
--                       per batch, or shared templates when batch_id/owner_id
--                       are NULL.
--   * nutrition_logs  — daily per-batch intake (g/bird/day), body weight and
--                       FCR readings that power "Nutrition history".
--
-- Both tables carry an owner column for the RLS convention introduced in
-- migration 0002, plus BEFORE INSERT triggers that stamp auth.uid() so device
-- or background writes are still attributed.
--
-- Safe to re-run: IF NOT EXISTS / DROP ... IF EXISTS guards.
-- Apply via the SQL editor or `supabase db push`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. feed_phases
-- -----------------------------------------------------------------------------
create table if not exists public.feed_phases (
  id                    uuid primary key default gen_random_uuid(),
  batch_id              uuid,                       -- NULL = shared template
  owner_id              uuid references auth.users (id) on delete set null,
  name                  text        not null,
  start_day             integer     not null check (start_day between 1 and 90),
  end_day               integer     not null check (end_day >= start_day),
  crude_protein         numeric(5,2) not null,      -- %
  crude_fat             numeric(5,2) not null,      -- %
  crude_fiber           numeric(5,2) not null,      -- %
  calcium               numeric(5,2) not null,      -- %
  phosphorus            numeric(5,2) not null,      -- %
  lysine                numeric(5,2) not null,      -- %
  methionine            numeric(5,2) not null,      -- %
  metabolizable_energy  numeric(7,1) not null,      -- kcal/kg
  created_at            timestamptz not null default now()
);

comment on table public.feed_phases is
  'Guaranteed-analysis targets per feed phase; batch-specific rows override
   the shared templates (batch_id IS NULL).';

-- Shared templates: the standard broiler Starter/Grower/Finisher program the
-- app previously hardcoded, now visible to every authenticated user. The
-- owner trigger must not stamp these rows, so auth.uid() (NULL in the SQL
-- editor / migrations service) naturally keeps them shared; the NOT EXISTS
-- guard makes the seed idempotent.
insert into public.feed_phases
  (batch_id, owner_id, name, start_day, end_day, crude_protein, crude_fat,
   crude_fiber, calcium, phosphorus, lysine, methionine, metabolizable_energy)
select t.batch_id, t.owner_id, t.name, t.start_day, t.end_day, t.crude_protein,
       t.crude_fat, t.crude_fiber, t.calcium, t.phosphorus, t.lysine,
       t.methionine, t.metabolizable_energy
from ( values
  (null::uuid, null::uuid, 'Starter',  1, 14, 23.0::numeric, 5.0::numeric, 4.0::numeric, 1.00::numeric, 0.65::numeric, 1.40::numeric, 0.60::numeric, 3000.0::numeric),
  (null::uuid, null::uuid, 'Grower',  15, 28, 21.0, 5.5, 4.5, 0.95, 0.60, 1.30, 0.55, 3100.0),
  (null::uuid, null::uuid, 'Finisher',29, 45, 19.0, 6.0, 5.0, 0.90, 0.55, 1.20, 0.50, 3200.0)
) as t(batch_id, owner_id, name, start_day, end_day, crude_protein, crude_fat,
       crude_fiber, calcium, phosphorus, lysine, methionine, metabolizable_energy)
where not exists (
  select 1 from public.feed_phases p
  where p.batch_id is null and p.name = t.name
);

create index if not exists feed_phases_batch_idx
  on public.feed_phases (batch_id, start_day);

-- -----------------------------------------------------------------------------
-- 2. nutrition_logs
-- -----------------------------------------------------------------------------
create table if not exists public.nutrition_logs (
  id                 uuid primary key default gen_random_uuid(),
  batch_id           uuid        not null,
  owner_id           uuid        references auth.users (id) on delete set null,
  log_date           date        not null,
  feed_intake_g      numeric(7,1) not null check (feed_intake_g >= 0), -- g/bird/day
  body_weight_kg     numeric(6,3) check (body_weight_kg > 0),
  fcr                numeric(5,2) check (fcr > 0),
  notes              text,
  created_at         timestamptz not null default now(),
  constraint nutrition_logs_batch_date unique (batch_id, log_date)
);

comment on table public.nutrition_logs is
  'Daily feed intake / body weight / FCR readings per batch.';

create index if not exists nutrition_logs_batch_date_idx
  on public.nutrition_logs (batch_id, log_date desc);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security (same owner convention as migration 0002)
-- -----------------------------------------------------------------------------
alter table public.feed_phases    enable row level security;
alter table public.nutrition_logs enable row level security;

-- feed_phases: own rows plus shared templates.
drop policy if exists "feed_phases_select" on public.feed_phases;
create policy "feed_phases_select" on public.feed_phases
  for select to authenticated
  using (owner_id = auth.uid() or owner_id is null);

drop policy if exists "feed_phases_write" on public.feed_phases;
create policy "feed_phases_write" on public.feed_phases
  for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- nutrition_logs: strictly owner-scoped.
drop policy if exists "nutrition_logs_select" on public.nutrition_logs;
create policy "nutrition_logs_select" on public.nutrition_logs
  for select to authenticated using (owner_id = auth.uid());

drop policy if exists "nutrition_logs_insert" on public.nutrition_logs;
create policy "nutrition_logs_insert" on public.nutrition_logs
  for insert to authenticated with check (owner_id = auth.uid());

drop policy if exists "nutrition_logs_update" on public.nutrition_logs;
create policy "nutrition_logs_update" on public.nutrition_logs
  for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "nutrition_logs_delete" on public.nutrition_logs;
create policy "nutrition_logs_delete" on public.nutrition_logs
  for delete to authenticated using (owner_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 4. Owner triggers — stamp auth.uid() when a row is created without one.
-- -----------------------------------------------------------------------------
create or replace function public.set_feed_phases_owner()
  returns trigger language plpgsql as $$
begin
  -- Only batch-specific phases get an owner; shared templates (batch_id IS
  -- NULL) must stay ownerless so every user can read them.
  if new.owner_id is null and new.batch_id is not null then
    new.owner_id := auth.uid();
  end if;
  return new;
end $$;

drop trigger if exists feed_phases_set_owner on public.feed_phases;
create trigger feed_phases_set_owner
  before insert on public.feed_phases
  for each row execute function public.set_feed_phases_owner();

create or replace function public.set_nutrition_logs_owner()
  returns trigger language plpgsql as $$
begin
  if new.owner_id is null then new.owner_id := auth.uid(); end if;
  return new;
end $$;

drop trigger if exists nutrition_logs_set_owner on public.nutrition_logs;
create trigger nutrition_logs_set_owner
  before insert on public.nutrition_logs
  for each row execute function public.set_nutrition_logs_owner();
