-- Relax plan timeline condition reference to allow slug IDs and avoid FK blocking
alter table if exists public.plan_timelines drop constraint if exists plan_timelines_condition_id_fkey;

alter table if exists public.plan_timelines
  alter column condition_id type text using condition_id::text;

-- Keep the column required but ensure it accepts slugs/text identifiers
alter table if exists public.plan_timelines alter column condition_id set not null;

create index if not exists plan_timelines_condition_id_idx on public.plan_timelines(condition_id);