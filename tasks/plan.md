# Implementation Plan: LifeOS v1

Input: [`PLAN.md`](../PLAN.md) (spec, 2026-08-18). Tasks: [`tasks/todo.md`](todo.md).
No external tracker configured for this repo, so the checklist lives in `tasks/todo.md`.

## Overview

Three panels — tasks (exists), today's merged calendar (Google + work Outlook via
the phone bridge), email triage (two emails with a "why it matters" line) — on top
of the existing single-file React/Supabase app, with auth and RLS added before any
employer data lands in the database.

14 tasks in 4 phases. Phase order is forced by the spec's §6 dependency argument
and is unchanged: auth → work calendar → Google → email.

## Architecture decisions

Four decisions the spec left open (§5), plus three this pass surfaced. Each has a
recommendation; the ones marked **needs your call** change what gets built.

### D1 — Auth + RLS (spec §5.1). Recommended: yes, and first.
Supabase Auth, single account, RLS on every table. **No `owner` column and no
`auth.uid()` predicate** — policies are `TO authenticated USING (true)`. Multi-user
is explicitly out of scope, so an ownership column is speculative flexibility
(CLAUDE.md §2). The anon key stays embedded in the public HTML and becomes inert.

Sequencing note: the auth gate ships *before* RLS is enabled (Task 3 then Task 4).
The reverse order breaks the deployed app the moment the migration runs.

### D2 — Work calendar write path. **Decided: A.**
The Shortcut doc writes with `apikey: ANON_KEY`. Once D1 lands, that write is
rejected — RLS has no policy for `anon`. Chosen: the Shortcut calls
`POST /auth/v1/token?grant_type=password` with the single account's credentials and
uses the returned JWT as `Bearer` on the DELETE and the POST.

Why over the alternative (a Vercel function holding the service-role key): it adds
zero code and zero deploy surface, and keeps the spec's "plain web app plus one
bridge" shape intact. The cost is the account password living in a Shortcut on your
own phone, which is a credential you already control on a device you already trust.
If the password ever changes the sync stops silently — but that is exactly the
failure `work_events_freshness` was built to make visible, so it surfaces in the
panel rather than rotting unnoticed.

### D3 — Google OAuth (spec §5.3). **Decided: fold into Supabase Auth, no refresh tokens.**
Use Supabase's Google provider with `calendar.readonly` + `gmail.readonly` scopes and
read `session.provider_token` to call Google's APIs directly from the client. This
collapses D1 and D3 into one sign-in and avoids a second identity system. The
email/password account from Task 2 stays as the Shortcut's credential (D2).

The restricted-scope problem, and the way around it: `gmail.readonly` is a *restricted*
scope, so the app stays in Google's "Testing" publishing status (moving to Production
triggers a verification review that is absurd for a one-person app). In Testing,
**refresh tokens expire after 7 days** — which is why the earlier draft of this plan
predicted a weekly re-login.

So v1 does not use refresh tokens at all. No `access_type=offline`. When
`provider_token` is missing or a Google call returns 401, the app re-runs
`signInWithOAuth`; because the account has already granted consent, Google redirects
straight back without a consent screen. The user-visible cost is a sub-second redirect
bounce on app open, not a login. The 7-day expiry becomes irrelevant rather than
tolerated, and the token-refresh code never gets written.

### D4 — Email "why it matters" (spec §5.2). **Decided: heuristics.**
Deterministic scoring only — direct-address vs. list, thread age, unanswered question,
sender in a small known-sender list, calendar-invite/reply detection. No model call.

This is the lower-friction option by a wide margin, and not only on cost. An Anthropic
API key cannot be embedded in publicly deployed client HTML the way the Supabase anon
key is, so "just add a model call" actually means standing up a server-side proxy to
hold the key — the exact serverless component D2 just avoided — plus a new API key,
plus a recurring bill on top of an existing Claude subscription. Heuristics need none
of that and run entirely in the page.

Task 12 keeps scoring pure and separate from fetching, so if the heuristic picks badly
against a real inbox, swapping in a model call later touches one function and no UI.

### D5 — Sync cadence (spec §5.4). Recommended: ship 07:00/12:00/17:00, measure.
Do not add the on-app-open sync in v1. The freshness banner (Task 8) is what tells
you whether the gap actually hurts; add the fourth trigger only if it does.

### D6 — Single-file `index.html`. Recommended: keep for v1.
It is 1315 lines today and three panels will push it past ~2000. Splitting means
adding a build step, which trades away the thing that makes this app cheap to
deploy. Keep it, and treat "I can't find anything in here" as the v1.1 trigger.

### D7 — Verification. There is no test runner and no build in this repo.
Not adding one for v1. Every task below verifies by `curl` against Supabase (data
layer) and the browser preview + console (UI layer). Verification steps name the
actual command rather than a fictional `npm test`.

## Task list

### Phase 1 — Auth and RLS (blocks everything)
- [ ] Task 1: Resume the paused Supabase project and confirm data survived
- [ ] Task 2: Create the single Supabase Auth account
- [ ] Task 3: Add the sign-in gate to `index.html`
- [ ] Task 4: Enable RLS on `tasks` and `research`

**Checkpoint A** — app works signed in, anon key is inert. This closes spec §6.1
and §6.4 (the tasks panel is now on the auth model).

### Phase 2 — Work calendar (proven spike → working panel)
- [ ] Task 5: Create `work_events` with RLS on from the start
- [ ] Task 6: Build the iOS Shortcut and land real events
- [ ] Task 7: Schedule the three daily automations
- [ ] Task 8: Render the work calendar panel with the staleness banner

**Checkpoint B** — the riskiest data path is end-to-end and visible.

### Phase 3 — Google Calendar
- [ ] Task 9: Create the Google OAuth client and wire the Supabase Google provider
- [ ] Task 10: Sign in with Google and hold `provider_token`
- [ ] Task 11: Merge Google events into the calendar panel, sports feeds off

**Checkpoint C** — two panels of three, both calendars merged.

### Phase 4 — Email triage and rename
- [ ] Task 12: Gmail fetch + heuristic ranking (headless, logged not rendered)
- [ ] Task 13: Email triage panel
- [ ] Task 14: Rename Atelier → LifeOS

**Checkpoint D** — v1 complete.

## Parallelization

Mostly sequential; the graph is a chain. Two exceptions:

- **Task 9 (Google Cloud console config) can start any time** — it is browser
  configuration with no code dependency. Doing it during Phase 2 removes the only
  idle wait in the plan.
- **Task 6 and Task 7 are phone work.** If you are at the Mac, Task 8 can be built
  against hand-inserted rows and reconciled when the real sync lands.

Everything else must be sequential: Task 4 changes shared database state, and Tasks
10–13 form a token → fetch → rank → render chain.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| RLS migration locks you out of your own app | High | Task 3 ships the gate before Task 4 enables RLS; keep the SQL to re-disable RLS to hand during Task 4 |
| Shortcut can't authenticate post-RLS (D2) | High | Decided before Task 5 is written, not discovered at Task 6 |
| `gmail.readonly` restricted-scope friction (D3) | Low | Designed out: no refresh tokens, silent re-consent redirect on 401 |
| Heuristic picks the wrong two emails | Medium | Task 12 is headless — the ranking is logged and judged against a real inbox before any UI is built on it |
| Shortcut silently stops firing | Medium | Already mitigated by design: zero-event abort + `work_events_freshness`; Task 8 makes it visible |
| `index.html` becomes unnavigable (D6) | Low | Accepted for v1; revisit at v1.1 |
| Supabase free tier re-pauses after inactivity | Low | Daily use is the whole point of the app; if it pauses again the habit failed first |

## Open questions

None blocking. All four spec decisions and the three surfaced during this pass are
resolved above; D2, D3 and D4 were delegated back and decided on 2026-08-18.

The one thing to watch rather than decide up front is **D4's hit rate**. Task 12 is
deliberately headless so the ranking gets judged against three real days of inbox
before any pixels are built on it. If it picks badly there, that is the moment to
reconsider a model call — with evidence, and with the proxy cost priced in.
