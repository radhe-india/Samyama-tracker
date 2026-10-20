-- Samyama Sadhana · Supabase setup
-- Paste this whole script into Supabase → SQL Editor → New query, then press Run.

-- 1. Tables ---------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  name       text not null default '',
  color      text default 'teal',
  photo      text,
  batch      text default 'dec26',
  share      boolean not null default false,
  visible    boolean not null default false,
  is_admin   boolean not null default false,
  durs       jsonb,
  routines   jsonb,
  sadhana    jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.logs (
  user_id    uuid not null references auth.users on delete cascade,
  day        date not null,
  data       jsonb not null default '{}',
  summary    jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- Reflections live apart from logs so the sangha can never read them.
create table if not exists public.notes (
  user_id    uuid not null references auth.users on delete cascade,
  day        date not null,
  text       text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.profiles enable row level security;
alter table public.logs     enable row level security;
alter table public.notes    enable row level security;

-- 2. Who can see and change what -----------------------------------------
-- Profiles: you see only your own. The sangha comes from sangha_feed() in migrate_v1.sql.
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (id = auth.uid());
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- Nobody can make themselves admin from the app.
revoke insert, update, delete on public.profiles from authenticated, anon;
grant update (name, color, photo, batch, share, visible, durs, routines, sadhana, updated_at) on public.profiles to authenticated;

-- Logs: only ever your own.
drop policy if exists "logs read" on public.logs;
create policy "logs read" on public.logs for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "logs write own" on public.logs;
create policy "logs write own" on public.logs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Notes: only ever your own.
drop policy if exists "notes own" on public.notes;
create policy "notes own" on public.notes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3. Create a profile automatically for every new sign-up -----------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Admin -----------------------------------------------------------------
-- First create the admin user in Authentication → Users → Add user → Create new user:
--   Email: admin@samyama.app   Password: admin@123   (tick "Auto Confirm User")
-- Then run this line (select it and press Run):
update public.profiles
   set is_admin = true, share = false, visible = false, name = 'Admin'
 where id = (select id from auth.users where email = 'admin@samyama.app');

-- 5. Admin can read everyone's data (for backups) ---------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;
drop policy if exists "admin reads profiles" on public.profiles;
create policy "admin reads profiles" on public.profiles for select to authenticated using (public.is_admin());
drop policy if exists "admin reads logs" on public.logs;
create policy "admin reads logs" on public.logs for select to authenticated using (public.is_admin());
drop policy if exists "admin reads notes" on public.notes;
create policy "admin reads notes" on public.notes for select to authenticated using (public.is_admin());
