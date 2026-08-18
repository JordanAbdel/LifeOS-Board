-- LifeOS — Row Level Security for the existing tables
-- Run in the Supabase SQL editor AFTER the sign-in gate is deployed and you can
-- sign in. Enabling RLS before that locks you out of your own app.
--
-- Decision D1 (tasks/plan.md): single-user app, so policies grant the whole table
-- to any authenticated session. No owner column and no auth.uid() predicate —
-- multi-user is explicitly out of scope, and an ownership column with one owner
-- is a column that only ever holds one value.
--
-- Syntax follows https://supabase.com/docs/guides/database/postgres/row-level-security
-- Note from those docs: "Once you have enabled RLS, no data will be accessible via
-- the API when using a publishable key, until you create policies." So the ALTERs
-- and the CREATE POLICYs must be run together, not one at a time.

ALTER TABLE public.tasks    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.research ENABLE ROW LEVEL SECURITY;

-- One FOR ALL policy per table rather than four per operation. USING governs which
-- existing rows are visible to reads, updates and deletes; WITH CHECK governs rows
-- being written. Both are unconditional here, so the gate is authentication itself.
DROP POLICY IF EXISTS "tasks: authenticated full access" ON public.tasks;
CREATE POLICY "tasks: authenticated full access"
  ON public.tasks FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "research: authenticated full access" ON public.research;
CREATE POLICY "research: authenticated full access"
  ON public.research FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Deliberately no policy for the anon role. The publishable key is embedded in the
-- publicly deployed index.html; after this runs it grants nothing on its own.

-- Verify (expect: RLS true, one policy each, roles = {authenticated}):
--   SELECT relname, relrowsecurity FROM pg_class
--    WHERE relname IN ('tasks','research','work_events');
--   SELECT tablename, policyname, roles, cmd FROM pg_policies
--    WHERE schemaname = 'public';
