-- Samyama Sadhana · v1.0 database update
-- Run once in Supabase → SQL Editor before the v1.0 app goes live. Safe to run again.

-- 1. Each person's sadhana choices (preparation level, logging mode, add-ons, own practices)
alter table public.profiles add column if not exists sadhana jsonb;
grant update (sadhana) on public.profiles to authenticated;
