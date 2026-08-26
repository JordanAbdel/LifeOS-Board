# Start here — new chat primer

Open a fresh chat in `LifeOS_Board/`. `CLAUDE.md` loads automatically and points
at the rest; paste the block at the bottom to pick up where this left off.

---

## State as of 2026-08-26 — v1.3.0, committed on `main`, not yet pushed

Verified against the live Supabase project, not read off notes.

| | |
|---|---|
| Supabase | Active. `tasks` and `research` exist, RLS on — the anon key returns `[]` |
| Auth | Single account exists; sign-in gate shipped |
| `work_events` | **Does not exist.** `docs/work_events.sql` has never been run |
| Tasks panel | Working |
| Calendar panel | Code complete, showing "not connected" until the table exists |
| Email panel | Shell only — needs Google OAuth (Task 9) first |
| Name | Renamed to LifeOS everywhere (Task 14, pulled forward) |

**Done:** Tasks 1, 2, 3, 4, 8, 14.
**Blocked on Jordan:** Tasks 5, 6, 7, 9.

---

## What Jordan needs to do, in order

Each needs his credentials, his phone or his Google account, so an agent cannot
do them.

1. **Run `docs/work_events.sql`** in the Supabase SQL editor. One paste. This is
   the single blocker for the entire calendar phase — the panel is already built
   and starts working the moment the table exists. Task 5.
2. **Build the iOS Shortcut** per `docs/work-calendar-shortcut.md`, including the
   password-grant auth step. Task 6. Then schedule it at 07:00 / 12:00 / 17:00
   with "Ask Before Running" off. Task 7.
3. **Create the Google OAuth client** and enable the Supabase Google provider.
   Task 9. No upstream dependency — can be done any time, including before 1.

Steps 1 and 3 are independent of each other and both unblock a whole phase.

---

## What an agent can do next, unblocked

- **Task 12** — the email ranking heuristic is a pure scoring function over
  message metadata. It can be written and unit-checked against fabricated
  messages without Gmail; only the fetch needs Task 9.
- Nothing else meaningful. Tasks 10, 11 and 13 all need a real `provider_token`.

If Jordan does step 1, Task 8's remaining manual verification (real rows, real
order, forced staleness) is a ten-minute job.

---

## Paste this into the new chat

> Continuing LifeOS. Read `CLAUDE.md` first, then `NEXT-CHAT.md` for state.
>
> Before proposing anything, check the live Supabase project rather than trusting
> the docs — `curl` the REST endpoint for `tasks` and `work_events` with the
> publishable key at `index.html:545`. The docs have drifted from reality once
> already.
>
> Then tell me what is genuinely unblocked and what is waiting on me.
