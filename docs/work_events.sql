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
-- security_invoker matters here. A view runs with its creator's rights by
-- default, and this one gets created by the postgres user in the SQL editor —
-- so without this it would read work_events with RLS bypassed and expose sync
-- timing to the anon role. "Views bypass RLS by default because they are
-- usually created with the postgres user."
-- Source: https://supabase.com/docs/guides/database/postgres/row-level-security#rls-and-views
-- Requires Postgres 15+, which every current Supabase project runs.
CREATE OR REPLACE VIEW public.work_events_freshness
  WITH (security_invoker = true) AS
  SELECT max(synced_at) AS last_sync,
         now() - max(synced_at) AS age
  FROM public.work_events;

-- RLS. This table holds work meeting titles, i.e. employer data, and the
-- publishable key is embedded in publicly deployed client HTML — so the anon
-- role gets no policy at all. Decision D1 in tasks/plan.md.
--
-- The iOS Shortcut writes here too. It authenticates as the same single account
-- (password grant against /auth/v1/token) and presents that JWT as a Bearer
-- token, so it lands on the authenticated role and needs no separate policy.
-- Decision D2; see work-calendar-shortcut.md.
--
-- Syntax follows https://supabase.com/docs/guides/database/postgres/row-level-security
ALTER TABLE public.work_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "work_events: authenticated full access" ON public.work_events;
CREATE POLICY "work_events: authenticated full access"
  ON public.work_events FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- work_events_freshness needs no policy of its own: security_invoker makes it
-- run the caller's RLS against work_events, so a signed-in session reads it and
-- the anon role gets nothing.
