-- Receiving table for work calendar events pushed from the iOS Shortcut.
-- The phone is the only place this calendar exists, so this table is a mirror,
-- not a source of truth: each sync replaces the day's rows wholesale.

CREATE TABLE IF NOT EXISTS public.work_events (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  ext_id      TEXT        NOT NULL,          -- Shortcut-supplied event identifier
  title       TEXT        NOT NULL,
  starts_at   TIMESTAMPTZ NOT NULL,
  ends_at     TIMESTAMPTZ,
  all_day     BOOLEAN     NOT NULL DEFAULT false,
  location    TEXT        NOT NULL DEFAULT '',
  synced_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (ext_id, starts_at)
);

-- Read path is always "today forward", so index that.
CREATE INDEX IF NOT EXISTS work_events_starts_at_idx
  ON public.work_events (starts_at);

-- Staleness check: if the newest synced_at is hours old, the phone stopped
-- syncing and the panel must say so rather than silently showing an empty day.
CREATE OR REPLACE VIEW public.work_events_freshness AS
  SELECT max(synced_at) AS last_sync,
         now() - max(synced_at) AS age
  FROM public.work_events;

-- DECISION REQUIRED before running this — see PLAN.md, Open Decisions #1.
-- The line below copies Atelier's existing pattern and is NOT safe here.
-- Atelier ships its Supabase key in publicly deployed client HTML; with RLS
-- off, anyone who views source can read and write this table. That table holds
-- work meeting titles, i.e. employer data. Replace with auth-scoped RLS before
-- any of this is deployed.
ALTER TABLE public.work_events DISABLE ROW LEVEL SECURITY;
