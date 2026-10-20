-- Samyama Sadhana · v1.0 database update
-- Run once in Supabase → SQL Editor before the v1.0 app goes live. Safe to run again.

-- 1. Each person's sadhana choices (preparation level, logging mode, add-ons, own practices)
alter table public.profiles add column if not exists sadhana jsonb;
grant update (sadhana) on public.profiles to authenticated;

-- 2. Sangha becomes opt-in ------------------------------------------------
-- visible: appears in the sangha (name and photo). share: also shows a daily summary.
-- New sign-ups start private. Existing people keep what they had until they choose in the app.
alter table public.profiles add column if not exists visible boolean;
update public.profiles set visible = share where visible is null;
alter table public.profiles alter column visible set default false;
alter table public.profiles alter column visible set not null;
alter table public.profiles alter column share set default false;
grant update (visible) on public.profiles to authenticated;

-- Each logged day carries a small summary (mandatory met, score). Only this ever reaches the sangha.
alter table public.logs add column if not exists summary jsonb;

-- Nobody reads anyone else's profile or logs directly any more.
drop policy if exists "profiles read" on public.profiles;
drop policy if exists "profiles read own" on public.profiles;
create policy "profiles read own" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "logs read" on public.logs;
drop policy if exists "logs read own" on public.logs;
create policy "logs read own" on public.logs for select to authenticated using (user_id = auth.uid());

-- The sangha, for people who joined it: others who joined, plus summaries from those who share.
create or replace function public.sangha_feed()
returns table (id uuid, name text, color text, photo text, batch text, share boolean, days jsonb)
language sql stable security definer set search_path = public as $$
  select p.id, p.name, p.color, p.photo, p.batch, p.share,
         case when p.share then coalesce((select jsonb_object_agg(l.day::text, l.summary)
                                          from public.logs l
                                          where l.user_id = p.id and l.summary is not null
                                            and l.day >= current_date - 150), '{}'::jsonb)
              else '{}'::jsonb end
    from public.profiles p
   where p.visible and p.id <> auth.uid() and not p.is_admin
     and exists (select 1 from public.profiles me where me.id = auth.uid() and me.visible)
$$;
revoke all on function public.sangha_feed() from public, anon;
grant execute on function public.sangha_feed() to authenticated;
