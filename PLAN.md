# LifeOS — v1 Specification

Status: intent confirmed, riskiest assumption spiked and passed, **broken into tasks
on 2026-08-18**. **This document is the input to task breakdown, not a task list.**
The task list is [`tasks/todo.md`](tasks/todo.md); the decisions below are resolved in
[`tasks/plan.md`](tasks/plan.md).

Written 2026-08-18. Supersedes the "Atelier" framing — same project, new name and
much wider scope.

---

## 1. Confirmed intent

- **Outcome** — One app, on Mac and phone, answering "what needs me today" in a
  glance: panels for tasks, today's calendar, the two emails that matter with
  *why* they matter, and (v2) people you're overdue with.
- **User** — Jordan, alone. Single-user, personal, no sharing, no multi-tenancy.
- **Why now** — Several single-purpose PWAs were built and none earned a
  permanent slot, so none became a habit. Email and calendar are the pull that
  makes one worth opening daily.
- **Success** — Opened every morning without deciding to, and the separate
  Atelier / Circle / calendar checks stop happening.
- **Constraint** — Source data is siloed by device. See §3.

### Explicitly out of scope for v1

These were considered and ruled out. Do not reintroduce them during planning.

- Reading, replying to, or archiving mail in-app. The app **surfaces and
  explains**; the user taps out to Gmail to act.
- Hour-by-hour timeline as the main screen. **Panels**, deliberately — the
  existing Atelier "Today" list is a revealed preference, and a timeline is
  mostly empty hours on a two-meeting day.
- Sending messages of any kind.
- Storing message *content*. v2 stores contact name + last-talked timestamp only.
- Sports calendars visible by default (F1 / Seahawks / Nuggets — see §3).
- Multi-user anything.

### Deferred to v2

- **Circle / people panel** in its entirety. Cut from v1 deliberately: the
  auto-fill *was* the feature. A hand-maintained people panel becomes a stale
  panel, and one dead panel teaches you to ignore all the panels.
- **Message-driven touchpoints** — iMessage + WhatsApp → `last talked` timestamps.

---

## 2. v1 scope

Three panels:

1. **Tasks** — carried forward from the existing Atelier implementation
   (personal/work, priority, due, tags, blocked). Already built and working; see
   `index.html` and `schema.sql`.
2. **Calendar (today)** — merged view of Google Calendar + the work Outlook
   calendar. Must visibly distinguish a stale sync from a genuinely free day.
3. **Email triage** — the two highest-priority emails, each with a short
   statement of *what it is and why it matters*. Judged on inbox content alone.

### Email triage: settled details

- **Not** a badge or unread count — the user rejected that explicitly.
- **Not** a mail client.
- Prioritisation reads the inbox **standalone**. It does not cross-reference
  contacts, tasks, or calendar. This was asked directly and ruled out: the
  user's close contacts are reached over iMessage/WhatsApp, not email, so
  cross-referencing would fire almost never.
- Open question on *what generates* the "why it matters" text — see §5.

---

## 3. Data sources — verified

Each fact below was checked on the user's machine on 2026-08-18, not assumed.

| Source | Where it lives | Status | Reaches phone? |
|---|---|---|---|
| Google Calendar | Google API | ✅ 6 calendars confirmed | yes |
| Gmail | Google API | ✅ account confirmed | yes |
| Work Outlook calendar | **iPhone only** | ✅ spike passed | via Shortcut bridge |
| Tasks / research | Supabase | ⏸ project paused, recoverable | yes |
| iMessage | **Mac only** | ⚠️ blocked, needs Full Disk Access | no — v2 |
| WhatsApp | **Mac only** | ⚠️ file readable, query unverified | no — v2 |

### Google Calendar — the six calendars

`Jordan Abdel Trident Calendar` (personal), `Family Calendar`, `Holidays in
Australia`, `Formula 1`, `Seattle Seahawks`, `Denver Nuggets`. Timezone
**Australia/Sydney**.

Half the calendar volume is sports feeds. The user's actual activities live
mostly on **Family Calendar**. Default the three sports feeds **off**, with a
toggle. A naive "show all calendars" today-view is mostly game times.

### Work Outlook calendar — the critical path

Managed corporate account. Cannot be shared, cannot sync to the Mac, does not
exist anywhere except the iPhone's Calendar app. It is also **the calendar the
user relies on most** — v1 fails without it.

**Spike result: PASSED.** iOS Shortcuts can see and read this calendar. This was
the single assumption capable of sinking the design.

Bridge design is written up in [`docs/work-calendar-shortcut.md`](docs/work-calendar-shortcut.md),
receiving schema in [`docs/work_events.sql`](docs/work_events.sql). Two design
decisions embedded there, both deliberate:

- **Delete-then-insert, not upsert.** Upsert leaves cancelled meetings in the
  mirror permanently. A meeting on screen that isn't happening is worse than an
  empty panel.
- **Abort the sync if zero events are returned.** Otherwise a failed fetch wipes
  the table, and a broken sync becomes indistinguishable from a free day.

The `work_events_freshness` view exists so the UI can render "last synced 6
hours ago" instead of a confidently empty day. **This is not optional polish** —
the phone is the sole source, so silent sync failure is the most likely
real-world fault.

### Supabase

Project ref `eefycklvsmuqhdckymmw` — **paused, not deleted.** Tasks and research
data survive. Resume it rather than starting clean. (DNS returns NXDOMAIN while
paused, which is why it initially looked deleted.)

---

## 4. Architecture notes

v1 is a **plain web app plus one bridge**. Dropping Circle auto-fill to v2
removed the Mac-only silo entirely, so v1 needs no local process on the Mac, no
Full Disk Access, and no WhatsApp DB access. Everything is a web API except the
work calendar, which arrives via the phone Shortcut on a timer.

Existing stack (worth keeping unless planning finds a reason not to): single-file
`index.html`, React 18 + Babel standalone via CDN, Supabase JS, deployed on
Vercel. The design language in the current build is good and the user likes it —
carry it forward rather than restarting.

---

## 5. Open decisions — **all resolved 2026-08-18**

Resolved during task breakdown. Full rationale for each lives in
[`tasks/plan.md`](tasks/plan.md) under the matching D-number; the original framing is
kept below because the reasoning that produced each question still explains the shape
of the answer.

1. **RLS / auth — do this first.** The current schema and Atelier's existing
   pattern run with RLS disabled and the Supabase key embedded in publicly
   deployed client HTML. Anyone viewing source gets read/write. Tolerable for
   personal todos; **not** tolerable for work meeting titles, which are employer
   data. v1 should use Supabase Auth with a single account and RLS keyed to
   `auth.uid()`. Roughly an hour, and far cheaper now than after three tables
   exist on the loose pattern. Flagged to the user; not yet explicitly agreed.

   → **Resolved (D1): yes, and first.** Supabase Auth, one account, RLS on every
   table. Policies are `TO authenticated USING (true)` — no owner column and no
   `auth.uid()` predicate, since multi-user is explicitly out of scope and an
   ownership column would be speculative flexibility. One ordering correction: the
   auth gate ships *before* the RLS migration runs, or the deployed app locks you out
   of itself. Tasks 2–4.

2. **What generates email "why it matters".** Needs either a model call (cost,
   API key — note the user is on a Claude *subscription*, no API key, so this is
   a new expense) or deterministic heuristics (sender, thread age, direct
   address, question marks, known-sender list). Not yet discussed. Heuristics
   are the cheaper opening move and may be sufficient.

   → **Resolved (D4): heuristics.** The cost is larger than the bill: an Anthropic key
   cannot sit in publicly deployed client HTML the way the Supabase anon key does, so a
   model call also requires a server-side proxy to hold it. Scoring is kept pure and
   separate from fetching so it can be swapped later without touching the panel.
   Tasks 12–13.

3. **Gmail + Google Calendar OAuth in the app itself.** MCP connectors exist in
   the user's Claude session, but those are Claude's access, not the app's. The
   deployed app needs its own Google OAuth client. Standard work, not yet done.

   → **Resolved (D3): fold into Supabase Auth, and use no refresh tokens.** Supabase's
   Google provider with `calendar.readonly` + `gmail.readonly`, calling Google directly
   with `session.provider_token`. `gmail.readonly` is a restricted scope, so the app
   stays in Google's "Testing" status, where refresh tokens expire after 7 days — which
   is why v1 does not use them. On a missing or rejected token the app silently re-runs
   the OAuth redirect; consent is already granted, so it bounces straight back. The
   expiry becomes irrelevant rather than tolerated. Tasks 9–10.

4. **Sync cadence** for the work calendar. Spec proposes 07:00 / 12:00 / 17:00
   plus optionally on-app-open. Validate against real staleness pain.

   → **Resolved (D5): ship the three timed runs, skip on-app-open.** The freshness
   banner is the instrument that will show whether the gap actually hurts; add the
   fourth trigger only if it does. Task 7.

### Surfaced during breakdown, not in the original list

5. **The Shortcut breaks the moment RLS goes on.**
   [`docs/work-calendar-shortcut.md`](docs/work-calendar-shortcut.md) writes with the
   anon key, and decision 1 leaves `anon` with no policy.
   → **Resolved (D2):** the Shortcut takes a password-grant JWT from Supabase Auth and
   writes with that. Zero new code, zero deploy surface, and the "plain web app plus one
   bridge" shape survives. Task 6.

6. **`index.html` growth.** 1315 lines today; three panels push it past ~2000.
   → **Resolved (D6): keep the single file for v1.** Splitting means adding a build
   step, which trades away what makes this app cheap to deploy. "I can't find anything
   in here" is the v1.1 trigger.

7. **No test runner and no build step exist in this repo.**
   → **Resolved (D7): not adding one for v1.** Every task verifies by `curl` against
   Supabase for the data layer and the browser preview plus console for the UI.

## 6. Suggested first slice

Not a task list — that was the next chat's job, now done in
[`tasks/todo.md`](tasks/todo.md), which follows this order exactly across 14 tasks in
four phases. The dependency order is fairly forced:

1. Resume Supabase; settle decision #1 (auth + RLS) before any table is created.
2. Create `work_events`; build and schedule the Shortcut; confirm real events
   land, and confirm freshness reporting works.
3. Google OAuth; render today's merged calendar panel with sports feeds off.
4. Port the existing tasks panel onto the new auth model.
5. Email triage last — it has the most unresolved design (decision #2).

Order rationale: the work calendar is the piece that already passed its risk
test and has no upstream dependency beyond auth, so it converts a proven spike
into a working panel early. Email is last because it is the only panel whose
core mechanism is still undecided.
