-- Life Dashboard — Supabase schema
-- Run this in your Supabase SQL editor (Dashboard → SQL Editor → New query)

CREATE TABLE IF NOT EXISTS public.tasks (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        TEXT        NOT NULL CHECK (kind IN ('personal', 'work')),
  title       TEXT        NOT NULL,
  pri         TEXT        NOT NULL DEFAULT 'med' CHECK (pri IN ('high', 'med', 'low')),
  due         DATE,
  done        BOOLEAN     NOT NULL DEFAULT false,
  tags        TEXT[]      NOT NULL DEFAULT '{}',
  note        TEXT        NOT NULL DEFAULT '',
  blocked     BOOLEAN     NOT NULL DEFAULT false,
  blocked_by  TEXT        NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.research (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  status      TEXT        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'stalled', 'complete')),
  progress    INTEGER     NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  tags        TEXT[]      NOT NULL DEFAULT '{}',
  note        TEXT        NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER research_updated_at
  BEFORE UPDATE ON public.research
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- RLS is NOT configured here. It lives in rls.sql, which must be run after the
-- sign-in gate is deployed. This file used to disable RLS outright, which gave
-- anyone who viewed the deployed page's source full read/write via the embedded
-- publishable key. See tasks/plan.md, decision D1.
