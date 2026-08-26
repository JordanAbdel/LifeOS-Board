# LifeOS v1 — Task List

Plan and architecture decisions: [`tasks/plan.md`](plan.md). Spec: [`PLAN.md`](../PLAN.md).

> **Status 2026-08-26.** Verified against the live project, not from notes.
> Supabase is active. `tasks` and `research` exist and return `[]` to the anon key,
> so `rls.sql` has been run — Task 4 is done. `work_events` returns PGRST205, so
> **`docs/work_events.sql` has not been run** and Task 5 is the one blocker holding
> up the calendar. Task 8's code is now wired and ships ahead of that SQL: it reads
> a missing table as "not connected" rather than an error, the same way the sign-in
> gate shipped ahead of RLS. Task 14 was pulled forward — the app is called LifeOS
> everywhere now, v1.3.0.

Conventions used below:
- `SUPABASE_URL` = `https://eefycklvsmuqhdckymmw.supabase.co`, `ANON` = the publishable
  key currently hardcoded at `index.html:462`.
- Deployed: <https://life-os-board.vercel.app/> (currently v1.0.9, pre-gate).
- Local preview: `npx serve -p 3000 .` (already configured in `.claude/launch.json`).
- There is no test runner or build step in this repo, by decision D7.

---

## Phase 1 — Auth and RLS

## Task 1: Resume the paused Supabase project and confirm data survived — ✅ DONE 2026-08-19

**Description:** Project ref `eefycklvsmuqhdckymmw` is paused, not deleted. Resume it
from the Supabase dashboard and prove the existing `tasks` and `research` rows are
intact before anything is built on top of them. Nothing else in the plan is safe to
start until this is confirmed.

**Acceptance criteria:**
- [x] Project status is Active in the Supabase dashboard
- [x] `tasks` and `research` return their pre-pause rows, not empty sets
- [x] The deployed app at its Vercel URL loads real data again

**Verification:**
- [x] `curl -s "$SUPABASE_URL/rest/v1/tasks?select=id,title&limit=5" -H "apikey: $ANON"` returns rows
- [x] Manual check: open the deployed app; Today view lists existing tasks

**Dependencies:** None
**Files likely touched:** None
**Estimated scope:** XS

---

## Task 2: Create the single Supabase Auth account — ✅ DONE 2026-08-19

**Description:** Create one email/password user in Supabase Auth for Jordan. This
account is both the app's login (until Task 10 swaps the app to Google sign-in) and
the Shortcut's credential under decision D2. Disable public sign-ups so the project
cannot accumulate other accounts.

**Acceptance criteria:**
- [x] Exactly one user exists in Auth → Users
- [x] New user sign-ups are disabled in Auth settings
- [x] A password-grant token request returns a JWT (this is the mechanism Task 6 depends on)

**Verification:**
- [x] `curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"email":"...","password":"..."}'` returns an `access_token`
- [x] Auth → Users shows one row

**Dependencies:** Task 1
**Files likely touched:** None (dashboard configuration)
**Estimated scope:** XS

---

## Task 3: Add the sign-in gate to `index.html` — ✅ DONE (inferred, not re-run)

> Not re-verified in this session — that needs the account password. But RLS is
> live on `tasks` and `research`, and the app cannot read a row without a working
> session, so a successful sign-in has happened at least once.

**Description:** Wrap `App` in an auth gate: `getSession` on load, a minimal
email/password sign-in form in the existing design language when there is no session,
`onAuthStateChange` to react to sign-out, and a sign-out control in the sidebar. The
`_db` client (`index.html:1300`) stays as-is — supabase-js attaches the session JWT
automatically once signed in. Ships *before* RLS is enabled so the app never breaks.

**Acceptance criteria:**
- [ ] Signed out shows only the sign-in form; no panel data is fetched
- [ ] Signing in reveals the existing dashboard with data loading as before
- [ ] Session survives a page reload; sign-out returns to the form

**Verification:**
- [ ] Manual check via `npx serve -p 3000 .`: sign in, reload, confirm still signed in, sign out, confirm gated
- [ ] Browser console clean — no auth or React errors
- [ ] Existing task create/edit/toggle/delete all still work while signed in

**Dependencies:** Task 2
**Files likely touched:** `index.html`
**Estimated scope:** S

---

## Task 4: Enable RLS on `tasks` and `research` — ✅ DONE 2026-08-26 (confirmed live: anon reads return `[]`)

**Description:** New root-level `rls.sql` (matching the existing flat `schema.sql`
convention) that enables RLS on both tables and adds `TO authenticated USING (true)
WITH CHECK (true)` policies — no owner column, per decision D1. Also update
`schema.sql`'s trailing `DISABLE ROW LEVEL SECURITY` lines so the file stops
documenting the old pattern. This is the task that makes the embedded anon key inert.

**Acceptance criteria:**
- [ ] RLS enabled on `tasks` and `research`, each with one policy for `authenticated`
- [ ] Anon-key reads and writes are rejected
- [ ] The signed-in app is unaffected — all CRUD still works

**Verification:**
- [ ] `curl -s "$SUPABASE_URL/rest/v1/tasks?select=id" -H "apikey: $ANON"` returns `[]` or a permission error, not rows
- [ ] Same query with `-H "Authorization: Bearer $JWT"` returns rows
- [ ] Manual check: signed-in app creates, edits, and deletes a task successfully

**Dependencies:** Task 3
**Files likely touched:** `rls.sql` (new), `schema.sql`
**Estimated scope:** S

---

## Checkpoint A — Foundation
- [ ] App requires sign-in; anon key grants nothing
- [ ] All pre-existing task and research functionality works unchanged
- [ ] Deployed to Vercel and working on both Mac and phone
- [ ] Closes spec §6.1 and §6.4 — review before creating any new table

---

## Phase 2 — Work calendar

## Task 5: Create `work_events` with RLS on from the start — ⛔ NEEDS JORDAN: run `docs/work_events.sql`

> This is the single blocker for the whole calendar phase. The SQL is written and
> correct (RLS enabled, `security_invoker` on the view, no `DISABLE` line). It just
> needs pasting into the Supabase SQL editor. Task 8's panel is already wired and
> will light up the moment the table exists.

**Description:** Run `docs/work_events.sql`, with its final line replaced: the file
currently ends in `DISABLE ROW LEVEL SECURITY` under an explicit "DECISION REQUIRED"
comment. Enable RLS with an `authenticated` policy instead, matching Task 4. The
`work_events_freshness` view ships with it — it is load-bearing, not polish. Per
decision D2 the Shortcut authenticates as the Task 2 account, so the policy is the
same `TO authenticated` shape as Task 4 — no separate service role, no second key.

**Acceptance criteria:**
- [ ] `work_events` and `work_events_freshness` exist with the index
- [ ] RLS enabled; anon cannot read or write; a password-grant JWT can do both
- [ ] `docs/work_events.sql` no longer contains the unsafe RLS line or its warning

**Verification:**
- [ ] Insert one row with a JWT via `curl`, read it back, delete it
- [ ] Same insert with only `apikey: $ANON` is rejected
- [ ] `curl` on `work_events_freshness` returns `last_sync` and `age`

**Dependencies:** Task 4
**Files likely touched:** `docs/work_events.sql`
**Estimated scope:** S

---

## Task 6: Build the iOS Shortcut and land real events — ⛔ NEEDS JORDAN (doc now correct)

**Description:** Build the Shortcut exactly as specified in
`docs/work-calendar-shortcut.md`, plus the two auth actions decision D2 requires: a
password-grant POST to `/auth/v1/token` and use of the returned `access_token` as the
`Authorization: Bearer` header on both the DELETE and the POST. The zero-event abort
and delete-then-insert order are non-negotiable — both exist so a failed sync cannot
masquerade as a free day. Update the doc to match what was actually built.

**Acceptance criteria:**
- [ ] A manual run writes today's real work meetings into `work_events`
- [ ] Titles, start/end times (correct in Australia/Sydney) and all-day flags are right
- [ ] A run on a day with zero events leaves existing rows untouched rather than clearing them

**Verification:**
- [ ] `curl -s "$SUPABASE_URL/rest/v1/work_events?select=title,starts_at&order=starts_at" -H "apikey: $ANON" -H "Authorization: Bearer $JWT"` matches the phone's Calendar app
- [ ] `work_events_freshness.age` is under a minute right after a run
- [ ] Run twice in a row: row count stays stable, no duplicates

**Dependencies:** Task 5
**Files likely touched:** `docs/work-calendar-shortcut.md`
**Estimated scope:** M (phone work, no code)

---

## Task 7: Schedule the three daily automations

**Description:** Shortcuts → Automation → Time of Day at 07:00, 12:00 and 17:00, with
"Ask Before Running" off or they never fire unattended. No on-app-open trigger in v1
(decision D5) — the freshness banner is what will tell you whether the gap matters.

**Acceptance criteria:**
- [ ] Three time-of-day automations exist, all with confirmation off
- [ ] An unattended run fires and updates `synced_at`

**Verification:**
- [ ] The morning after setup, `work_events_freshness.last_sync` shows the 07:00 run without any manual trigger

**Dependencies:** Task 6
**Files likely touched:** None
**Estimated scope:** XS

---

## Task 8: Render the work calendar panel with the staleness banner — ✅ CODE DONE v1.3.0, awaiting Task 5

**Description:** Add a calendar panel to `TodayView` (`index.html:991`) showing today's
`work_events`, alongside the existing task columns. Fetch `work_events_freshness` in
the same load and, when `age` exceeds roughly 8 hours, render "last synced Nh ago"
instead of an empty-day state. An empty panel and a broken sync must never look alike —
this is the panel's main job, not decoration.

**Acceptance criteria:**
- [ ] Today's work meetings render in start-time order in Australia/Sydney time
- [ ] A genuinely free day and a stale sync are visually distinct
- [ ] Panel does not disturb the existing tasks layout on phone or Mac

**Verification:**
- [ ] Manual check against the phone's Calendar app for today
- [ ] Force staleness (temporarily backdate `synced_at` on the newest row) and confirm the banner appears; restore afterwards
- [ ] Check both viewports in the browser preview; console clean

> Wired 2026-08-26. `Dashboard` fetches today's `work_events` (bounded by
> `sydneyMidnightUTC(0)`/`(1)`) and `work_events_freshness` in a dedicated effect,
> maps rows through `toWorkEvent`, and derives `staleHours` from `last_sync`.
> A missing table (PGRST205) or a null `last_sync` both report as "not connected"
> rather than an error or a free day.
>
> All seven states were rendered and checked at desktop and mobile widths, and the
> Sydney day window was checked across both 2026 DST transitions. What is **not**
> verified is the only thing that needs the table: real rows rendering in real
> order. Re-run the manual check in this task once Task 5 lands.

**Dependencies:** Task 5 (can be built against hand-inserted rows before Task 6 lands)
**Files likely touched:** `index.html`
**Estimated scope:** M

---

## Checkpoint B — Work calendar end-to-end
- [ ] Real work meetings appear in the app without touching the phone
- [ ] Sync failure is visible rather than silent
- [ ] Deployed; confirmed on the phone
- [ ] The spec's single sinkable assumption is now a working panel — review before Phase 3

---

## Phase 3 — Google Calendar

## Task 9: Create the Google OAuth client and wire the Supabase Google provider — ⛔ NEEDS JORDAN

**Description:** Google Cloud project, OAuth consent screen in **Testing** status with
Jordan as the sole test user, OAuth client with Supabase's callback URL, Calendar and
Gmail APIs enabled, scopes `calendar.readonly` and `gmail.readonly`. Do **not** request
`access_type=offline` — decision D3 uses no refresh tokens, which is what makes the
Testing-mode 7-day expiry a non-issue. Enable the Google
provider in Supabase Auth with the client ID and secret. Both scopes are requested now
so Phase 4 needs no second consent round. No code — pure configuration, and it has no
upstream dependency, so it can be done during Phase 2.

**Acceptance criteria:**
- [ ] Consent screen in Testing with Jordan as a test user; both APIs enabled
- [ ] Supabase Google provider enabled and saved
- [ ] A test sign-in returns a session carrying `provider_token`

**Verification:**
- [ ] Run `supabase.auth.signInWithOAuth` from the browser console against the local preview; confirm `session.provider_token` is present
- [ ] Call `GET /calendar/v3/users/me/calendarList` with that token — expect the six known calendars

**Dependencies:** Task 1 (independent of Phase 2 — parallelizable)
**Files likely touched:** None (console configuration)
**Estimated scope:** S

---

## Task 10: Sign in with Google and hold `provider_token`

**Description:** Switch the Task 3 gate from email/password to "Sign in with Google",
requesting both scopes and **no** `access_type=offline` (decision D3). Hold
`provider_token` in React state only — never `localStorage`. When it is absent on load,
or a Google call returns 401, re-run `signInWithOAuth` immediately rather than showing
an error: consent is already granted, so Google bounces straight back and the user sees
a redirect flicker, not a login. Guard against a redirect loop by attempting the silent
re-auth at most once per page load, falling back to a visible "sign in again" button.
The email/password account stays alive as the Shortcut's credential.

**Acceptance criteria:**
- [ ] Google sign-in produces a Supabase session with a usable `provider_token`
- [ ] Tasks, research and the work calendar panel all still work under the Google session
- [ ] A missing or rejected `provider_token` triggers one silent re-auth; a second failure shows a button instead of looping

**Verification:**
- [ ] Manual check: sign in with Google, reload, confirm the panels repopulate without a visible login step
- [ ] Clear `provider_token` in state and confirm the silent redirect restores it
- [ ] Break the token deliberately twice and confirm the app stops at the button rather than redirect-looping
- [ ] Console clean on all three paths

**Dependencies:** Tasks 4, 9
**Files likely touched:** `index.html`
**Estimated scope:** M

---

## Task 11: Merge Google events into the calendar panel, sports feeds off

**Description:** Fetch today's events from the Google Calendar API for the personal and
family calendars and merge them with `work_events` into one time-ordered list, with a
per-source visual distinction. The three sports feeds (Formula 1, Seahawks, Nuggets)
default **off** behind a toggle whose state persists in `localStorage` — half the
calendar volume is sports and a naive all-calendars view is mostly game times.

**Acceptance criteria:**
- [ ] Today's Google and work events appear merged and correctly ordered in Australia/Sydney
- [ ] Sports feeds hidden by default; the toggle reveals them and the choice survives reload
- [ ] Google API failure degrades to work-events-only with a visible note, never a silent partial day

**Verification:**
- [ ] Manual check against Google Calendar's own today view for a day with events on both sides
- [ ] Toggle sports on/off, reload, confirm persistence
- [ ] Simulate failure (revoke the token in state) and confirm the degraded state is labelled

**Dependencies:** Tasks 8, 10
**Files likely touched:** `index.html`
**Estimated scope:** M

---

## Checkpoint C — Calendar complete
- [ ] One panel answers "what is on today" across both calendars
- [ ] Sports noise is off by default
- [ ] Decision D3 confirmed in practice: app open repopulates panels with no visible login step
- [ ] Deployed; used for at least two real mornings before starting Phase 4

---

## Phase 4 — Email triage and rename

## Task 12: Gmail fetch + heuristic ranking (headless) — 🟡 SCORING DONE v1.3.0, fetch blocked on Task 9

> Ranking landed 2026-08-26: `scoreMessage`, `explainMessage` and `rankInbox` in
> `index.html`, plus the `KNOWN_SENDERS` constant (empty — fill it in with the few
> people whose mail should interrupt a morning). Pure, no I/O, takes a normalised
> message rather than a Gmail payload, and returns exactly the shape `EmailPanel`
> already renders. Verified against four fabricated inbox shapes.
>
> Parsing landed 2026-08-26 too: `toInboxMessage` plus `header`,
> `splitAddressList` and `parseAddress`, checked against nine payload shapes.
> Case-folded header lookup, comma-safe address splitting and both calendar-invite
> shapes are covered.
>
> **Remaining: the HTTP call only.** `messages.list` with `in:inbox -from:me`,
> then `messages.get(format: "METADATA", metadataHeaders: [From, To, Cc, Subject,
> List-Unsubscribe, Content-Type])`, grouping the list response by `threadId` to
> supply `threadLength`. Feed each result through `toInboxMessage` then
> `rankInbox`. Needs a `provider_token`, so it waits on Tasks 9-10 — and it is
> now the only unwritten part.
>
> **Not yet done and it is the point of the task:** judging the picks against
> Jordan's real inbox on three different days. The heuristic is untested against
> real mail; treat the weights as a first guess, not a finished answer.

**Description:** Fetch recent inbox messages via the Gmail API and score them with the
deterministic heuristic from decision D4 — direct-address vs. list, thread age,
unanswered question, small known-sender list, calendar invites excluded. Output is the
top two plus a generated one-line "why it matters" string. **No UI in this task**: log
the ranking to the console and judge it against the real inbox first. Prioritisation
reads the inbox standalone — no cross-referencing tasks, contacts or calendar (spec §2).

**Acceptance criteria:**
- [ ] Returns exactly two ranked messages with a sender, subject and a one-line reason
- [ ] Scoring is pure and separated from fetching, so D4 can later be swapped for a model call without touching the panel
- [ ] Run against the live inbox on three different days picks emails Jordan agrees matter

**Verification:**
- [ ] Console-log the ranked top five with scores; compare against a manual read of the inbox
- [ ] Confirm no unread counts or badges anywhere — explicitly rejected in the spec
- [ ] Confirm the code reads no task, contact or calendar state

**Dependencies:** Task 10
**Files likely touched:** `index.html`
**Estimated scope:** M

---

## Task 13: Email triage panel — 🟡 SHELL BUILT v1.2.0, not wired

**Description:** Render the two emails as the third panel: sender, subject, the "why it
matters" line, and a tap-out link to the message in Gmail. Surfacing and explaining
only — no reading, replying, archiving or sending in-app, and no message content is
stored anywhere (spec §1).

**Acceptance criteria:**
- [ ] Two emails render with their reason lines in the existing design language
- [ ] Each opens the right Gmail thread on Mac and on iPhone
- [ ] Empty inbox and Gmail-fetch failure are distinct, labelled states

**Verification:**
- [ ] Manual check: both links open the correct threads on both devices
- [ ] Force a fetch failure and confirm the labelled state
- [ ] Confirm nothing from the message body is written to Supabase or `localStorage`

> `EmailPanel` exists with loading / not-connected / empty / two-picks / error
> states. Remaining work is the fetch and ranking, mapped to
> `{ id, from, subject, why, age, url }`.

**Dependencies:** Task 12
**Files likely touched:** `index.html`
**Estimated scope:** M

---

## Task 14: Rename Atelier → LifeOS — ✅ DONE 2026-08-26 (pulled forward)

**Description:** The build still identifies as "Life Dashboard" / "Atelier" in the
`<title>`, `manifest.json` and `apple-mobile-web-app-title` (`index.html:20`). Rename to
LifeOS, bump `VERSION` (`index.html:459`), and bump the service worker cache key in
`sw.js` so the phone actually picks up the new build.

**Acceptance criteria:**
- [ ] Title, manifest name and iOS home-screen title all read LifeOS
- [ ] `VERSION` bumped and visible in the UI
- [ ] Re-adding to the iPhone home screen shows the new name

**Verification:**
- [ ] Hard-reload the deployed app; confirm the new version string renders
- [ ] Confirm the home-screen icon label updated on the phone

**Dependencies:** ~~Task 13~~ — none in practice; pulled forward out of order
**Files likely touched:** `index.html`, `manifest.json`, `sw.js`
**Estimated scope:** XS

---

## Checkpoint D — v1 complete
- [ ] Three panels: tasks, merged calendar, two emails with reasons
- [ ] Nothing readable or writable with the anon key alone
- [ ] Works on Mac and phone
- [ ] Success test is behavioural, not technical: opened every morning without deciding to,
      and the separate Atelier / Circle / calendar checks have stopped
