# Start here — new chat primer

Paste the block at the bottom into a fresh chat opened in `LifeOS_Board/`.
`CLAUDE.md` loads automatically and points at the rest, so the new session does
not need this file explained to it.

---

## State as of 2026-08-19

**Branch `lifeos-v1-auth`**, 8 commits, nothing pushed, `main` untouched.
Working tree clean. Run `git log --oneline main..HEAD` to see the night's work.

**Done and committed:** sign-in gate (Task 3), `rls.sql` (Task 4), RLS +
`security_invoker` on `work_events` (Task 5), Shortcut doc corrected to use a JWT,
supabase-js pinned to 2.112.3, v1.1.0.

**Done by Jordan:** Xcode licence accepted (git works again), Supabase resumed.

**Verified working:** git 2.50.1, Supabase Auth (GoTrue v2.195.0) responding.

**Open question at handoff time:** PostgREST reports zero tables in `public`.
Either the schema cache was still cold right after the resume, or the tables did
not survive. **Confirm in the dashboard Table Editor before doing anything else** —
it changes the first task materially. See "If the tables are gone" below.

---

## What Jordan still needs to do

Nothing can proceed past step 2 without these. They need his credentials or his
phone, so an agent cannot do them.

1. **Confirm `tasks` and `research` exist** with their rows (dashboard → Table
   Editor). Task 1.
2. **Create the single auth account**, then disable public sign-ups. Task 2.
   This is also the Shortcut's credential — store it where the phone can reach it.
3. **Sign in to the deployed app and confirm tasks still load.** Before step 4.
   This is the whole reason the gate shipped ahead of RLS.
4. **Run `rls.sql`** in the SQL editor, then the two verification curls in Task 4.

Later, and independent: the iOS Shortcut (Tasks 6–7) and the Google Cloud OAuth
client (Task 9). Task 9 has no upstream dependency and can be done any time.

### If the tables are gone

The plan assumed "resume, don't start clean". If the data did not survive, the
recovery is `schema.sql` — it is `CREATE TABLE IF NOT EXISTS`, so it rebuilds the
structure cleanly. The rows themselves would be unrecoverable, which is worth
knowing before building three more panels on top: it means the only copy of the
task data was in a free-tier project that pauses. Flag it to Jordan rather than
quietly recreating.

---

## Paste this into the new chat

> Continuing LifeOS v1. Read `CLAUDE.md` first — it has the reading ladder.
> State: branch `lifeos-v1-auth`, tasks 3–5 written and committed but never run
> against Supabase. I've resumed Supabase and fixed git.
>
> First: confirm whether `public.tasks` and `public.research` actually exist with
> their rows — the last session found PostgREST reporting zero tables right after
> the resume and couldn't tell a cold schema cache from lost data. Tell me which
> it is before doing anything else.
>
> Then walk me through Tasks 1–4 in `tasks/todo.md`, in order. I'll run the SQL
> and the dashboard steps; you verify each one with the curl commands in the task.
