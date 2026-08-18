# Handoff — overnight session, 2026-08-19

Branch: **`lifeos-v1-auth`** (6 commits, nothing pushed, `main` untouched).
Everything below is on disk and committed. **Nothing has touched Supabase.**

---

## Do this first — 2 minutes, unrelated to LifeOS

Your `git` broke partway through the session:

```bash
sudo xcodebuild -license accept
```

`/usr/bin/git` is the Xcode shim and it now refuses to run until the licence is
accepted — every git command exits 69, including `git status`. It needs your
password, so I couldn't do it. I finished the night on `/opt/homebrew/bin/git`
(2.48.1), which is unaffected, so the commits are real and intact. Xcode most
likely updated in the background while we were working.

---

## What shipped

| | |
|---|---|
| `build:` | Pinned supabase-js from the floating `@2` tag to `2.112.3` |
| `feat:` | **Task 3** — sign-in gate |
| `feat:` | **Task 4** — `rls.sql` for `tasks` + `research` |
| `feat:` | **Task 5** — RLS on `work_events`, `security_invoker` on the freshness view |
| `docs:` | Shortcut bridge now authenticates with a JWT instead of the anon key |
| `chore:` | v1.1.0 + service worker cache key |

### Verified

- Sign-in screen renders on desktop and mobile widths, in the existing design language
- **Zero Supabase network calls while signed out** — `Dashboard` doesn't mount, so no panel data is fetched
- Failed sign-in doesn't hang: button re-enables, error shows, console clean
- The pinned CDN URL serves (HTTP 200, 212 KB)

### Not verified, and can't be until you're back

Successful sign-in, session-survives-reload, and sign-out. All three need an
account that doesn't exist yet, against a project that's paused. The code is
written to the documented API but **has never once completed a real sign-in.**
Treat Task 3 as done-pending-verification, not done.

---

## Your queue, in order

1. **Resume Supabase** (project `eefycklvsmuqhdckymmw`) and confirm the tasks and
   research rows survived. Task 1.
2. **Create the auth account** — one user, then turn off public sign-ups. Task 2.
   This account is also the Shortcut's credential, so use a password manager entry
   you can retrieve on the phone.
3. **Sign in to the deployed app and confirm everything still works.** Do this
   *before* step 4. It is the whole reason the gate shipped first.
4. **Run `rls.sql`** in the SQL editor. Then confirm an anon `curl` returns `[]`
   and a signed-in session still reads rows — both commands are in Task 4.
5. From there Task 5 onward in `tasks/todo.md` runs normally.

If step 4 goes wrong and locks you out, the rollback is two lines:

```sql
ALTER TABLE public.tasks DISABLE ROW LEVEL SECURITY; ALTER TABLE public.research DISABLE ROW LEVEL SECURITY;
```

---

## Three decisions I made without you

**Pinned supabase-js to 2.112.3.** The app was loading the floating `@2` range and
I was about to build auth on it. `@2` resolves to 2.112.3 today, so the pin changes
nothing now and prevents the client version shifting under the auth code later.

**Changed the sign-in error message.** A failed sign-in against the paused project
showed "Failed to fetch". Since this project's Supabase pauses on inactivity, that
case is routine, and the raw message points at the wrong problem. Network errors
now read "Can't reach Supabase — the project may be paused, or you're offline."
The check is on `error.name`, which is what the Supabase docs prescribe over string
matching. `AuthRetryableFetchError` isn't listed on their error-codes page, so I
confirmed the name at runtime against 2.112.3; anything unrecognised falls through
to the server's own message.

**Added `security_invoker` to `work_events_freshness`.** I'd written a comment
claiming the view inherits the base table's RLS. Checking it, that's backwards:
"Views bypass RLS by default because they are usually created with the `postgres`
user." As originally written, the view would have read `work_events` with RLS
bypassed and exposed sync timing to anon. Only timestamps, not meeting titles —
but it's a bypass, and the fix is one clause. Needs Postgres 15+, which your
project runs.

---

## Two things for you to decide

**The Shortcut password.** Decision D2 has the Shortcut sign in with the account's
email and password to get a JWT. That means your Supabase password sits in a
Shortcut on your phone. I think that's the right call for a personal app — the
alternative was standing up a serverless function to hold a service-role key — but
it is your credential and your call, and it's the one part of the plan that trades
security for simplicity. Reversible: it changes Tasks 5–6 only.

**"Atelier" is still on the sign-in screen.** The rename to LifeOS is Task 14, at
the end. It's the first thing you'll see every morning until then, so if it grates,
say so and I'll pull the rename forward — it's about ten minutes.

---

## Noticed, not touched

- `.brand-sub` ("Sign in to continue") is hidden at mobile width by an existing
  media query, so the phone sign-in card is a little bare. Cosmetic, pre-existing rule.
- `index.html` still loads React's **development** build from the CDN in
  production. Called out in `CLAUDE.md`; deliberately not fixed as a drive-by.
- Nothing is pushed. `main` is untouched, and `PLAN.md` / `docs/` were untracked
  before tonight — they're now committed on the branch.
