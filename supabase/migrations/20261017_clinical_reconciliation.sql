-- Migration: structured clinical medication reconciliation fields
-- Run in Supabase SQL Editor only after institutional privacy/security review.
-- Do not add direct patient identifiers to this table.
alter table public.patient_reconciliations
  add column if not exists allergy_status text not null default 'unknown'
    check (allergy_status in ('unknown','none','reported','confirmed')),
  add column if not exists adherence_status text not null default 'unknown'
    check (adherence_status in ('unknown','good','issue','not_applicable')),
  add column if not exists issue_type text not null default 'none'
    check (issue_type in ('none','omission','duplication','dose','frequency','allergy','interaction','adherence','other')),
  add column if not exists medication_comparison jsonb not null default '[]'::jsonb,
  add column if not exists decision text,
  add column if not exists education text;

alter table public.patient_reconciliations
  drop constraint if exists patient_reconciliations_medication_comparison_array;
alter table public.patient_reconciliations
  add constraint patient_reconciliations_medication_comparison_array
  check (jsonb_typeof(medication_comparison) = 'array');

comment on column public.patient_reconciliations.medication_comparison is
  'Minimal medication reconciliation entries; do not store patient names, NIK, address, phone, or other direct identifiers.';
