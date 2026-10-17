-- REKONSILIASI OBAT - Supabase schema
-- Jalankan pada SQL Editor proyek Supabase baru. Terapkan hanya setelah ditinjau admin TI/penanggung jawab.
create extension if not exists pgcrypto;
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null check (role in ('admin','apoteker','petugas','viewer')),
  location text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create or replace function public.current_app_role()
returns text language sql stable security definer set search_path=public
as $$ select role from public.user_profiles where id=auth.uid() and active=true limit 1 $$;
create or replace function public.current_user_active()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.user_profiles where id=auth.uid() and active=true) $$;
revoke all on function public.current_app_role() from public;
revoke all on function public.current_user_active() from public;
grant execute on function public.current_app_role() to authenticated;
grant execute on function public.current_user_active() to authenticated;
create table if not exists public.stock_transactions (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  type text not null check(type in ('opening','receipt','transfer_in','transfer_out','use','expired','return','adjustment')),
  item_name text not null check(length(item_name) between 1 and 180),
  location text not null check(length(location) between 1 and 140),
  qty numeric(14,3) not null check(qty>0),
  batch text,
  note text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists stock_transactions_date_idx on public.stock_transactions(date);
create index if not exists stock_transactions_item_location_idx on public.stock_transactions(item_name,location);
create table if not exists public.patient_reconciliations (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  case_ref text not null check(length(case_ref) between 1 and 40),
  service text not null,
  done boolean not null default false,
  discrepancy boolean not null default false,
  outcome text not null check(outcome in ('resolved','pending','referred','none')),
  note text,
  allergy_status text not null default 'unknown' check(allergy_status in ('unknown','none','reported','confirmed')),
  adherence_status text not null default 'unknown' check(adherence_status in ('unknown','good','issue','not_applicable')),
  issue_type text not null default 'none' check(issue_type in ('none','omission','duplication','dose','frequency','allergy','interaction','adherence','other')),
  medication_comparison jsonb not null default '[]'::jsonb check(jsonb_typeof(medication_comparison)='array'),
  decision text,
  education text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(date,case_ref)
);
create index if not exists patient_reconciliations_date_idx on public.patient_reconciliations(date);
alter table public.user_profiles enable row level security;
alter table public.stock_transactions enable row level security;
alter table public.patient_reconciliations enable row level security;
drop policy if exists "profile read self or admin" on public.user_profiles;
create policy "profile read self or admin" on public.user_profiles for select to authenticated
using (id=auth.uid() or public.current_app_role()='admin');
drop policy if exists "admin manages profiles" on public.user_profiles;
create policy "admin manages profiles" on public.user_profiles for all to authenticated
using(public.current_app_role()='admin') with check(public.current_app_role()='admin');
drop policy if exists "active team reads stock" on public.stock_transactions;
create policy "active team reads stock" on public.stock_transactions for select to authenticated
using(public.current_user_active());
drop policy if exists "authorized team adds stock" on public.stock_transactions;
create policy "authorized team adds stock" on public.stock_transactions for insert to authenticated
with check(public.current_user_active() and public.current_app_role() in ('admin','apoteker','petugas') and created_by=auth.uid());
drop policy if exists "admin and apoteker correct stock" on public.stock_transactions;
create policy "admin and apoteker correct stock" on public.stock_transactions for update to authenticated
using(public.current_app_role() in ('admin','apoteker')) with check(public.current_app_role() in ('admin','apoteker'));
drop policy if exists "admin deletes stock" on public.stock_transactions;
create policy "admin deletes stock" on public.stock_transactions for delete to authenticated
using(public.current_app_role()='admin');
drop policy if exists "active team reads patient indicators" on public.patient_reconciliations;
create policy "active team reads patient indicators" on public.patient_reconciliations for select to authenticated
using(public.current_user_active());
drop policy if exists "authorized team adds patient indicators" on public.patient_reconciliations;
create policy "authorized team adds patient indicators" on public.patient_reconciliations for insert to authenticated
with check(public.current_user_active() and public.current_app_role() in ('admin','apoteker','petugas') and created_by=auth.uid());
drop policy if exists "admin and apoteker correct patient indicators" on public.patient_reconciliations;
create policy "admin and apoteker correct patient indicators" on public.patient_reconciliations for update to authenticated
using(public.current_app_role() in ('admin','apoteker')) with check(public.current_app_role() in ('admin','apoteker'));
drop policy if exists "admin deletes patient indicators" on public.patient_reconciliations;
create policy "admin deletes patient indicators" on public.patient_reconciliations for delete to authenticated
using(public.current_app_role()='admin');
-- Initial setup: create users in Supabase Auth dashboard first, then insert their auth UUID here.
-- Example (replace values):
-- insert into public.user_profiles(id,display_name,role,location)
-- values ('AUTH-USER-UUID','Nama Petugas','admin','Puskesmas Ngalupolo');
-- Never put service_role key in frontend. Do not store patient names, NIK, address, phone, diagnoses,
-- prescription images, or other direct identifiers in this aggregate-indicator prototype.

create table if not exists public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  item_name text not null check (length(item_name) between 1 and 180),
  location text not null check (length(location) between 1 and 140),
  period text not null check (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  physical_qty numeric(14,3) not null check (physical_qty >= 0),
  counted_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  unique(item_name, location, period)
);
alter table public.stock_counts enable row level security;
drop policy if exists "active team reads stock counts" on public.stock_counts;
create policy "active team reads stock counts" on public.stock_counts
  for select to authenticated using (public.current_user_active());
drop policy if exists "team records stock counts" on public.stock_counts;
create policy "team records stock counts" on public.stock_counts
  for insert to authenticated
  with check (
    public.current_user_active()
    and public.current_app_role() in ('admin','apoteker','petugas')
    and counted_by = auth.uid()
  );
drop policy if exists "team updates stock counts" on public.stock_counts;
create policy "team updates stock counts" on public.stock_counts
  for update to authenticated
  using (public.current_user_active() and public.current_app_role() in ('admin','apoteker','petugas'))
  with check (public.current_user_active() and public.current_app_role() in ('admin','apoteker','petugas') and counted_by = auth.uid());
drop policy if exists "admin deletes stock counts" on public.stock_counts;
create policy "admin deletes stock counts" on public.stock_counts
  for delete to authenticated using (public.current_user_active() and public.current_app_role()='admin');
