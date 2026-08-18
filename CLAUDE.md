# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

---

# Project: LifeOS

Personal single-user dashboard — tasks, today's merged calendar, email triage.
Deployed on Vercel, used daily on Mac and iPhone.

**Current phase: v1 implementation.** Read in this order and only as far as you need:

| File | What it is | When to read |
|---|---|---|
| [`tasks/todo.md`](tasks/todo.md) | 14 tasks, acceptance criteria, verification commands | Every implementation session — find your task, read only it |
| [`tasks/plan.md`](tasks/plan.md) | Decisions D1–D7 with rationale, risks | When a task's *why* is unclear, or before deviating |
| [`PLAN.md`](PLAN.md) | v1 spec: intent, scope, out-of-scope | When scope is in question |
| [`docs/work-calendar-shortcut.md`](docs/work-calendar-shortcut.md) | iOS Shortcut bridge design | Only for Tasks 5–8 |

Do not load all four. One task's slice is the right amount of context.

## Stack

Single-file app, no build step, no package.json. Everything is CDN + one HTML file.

- `index.html` — the entire app: CSS custom properties, React 18.3.1 + ReactDOM UMD,
  Babel standalone 7.29.0 (`<script type="text/babel">`), supabase-js v2 UMD
- `sw.js` service worker (network-first), `manifest.json`, `vercel.json` (no-cache headers)
- `schema.sql`, `docs/work_events.sql` — run by hand in the Supabase SQL editor
- Supabase project `eefycklvsmuqhdckymmw`, timezone **Australia/Sydney**

## Commands

```
npx serve -p 3000 .          # local preview (also .claude/launch.json → "life-dashboard")
```

There is no test runner, no linter and no build — by decision (D7). Verify with the
browser preview plus console for UI, and `curl` against Supabase REST for data. Every
task in `tasks/todo.md` names its own verification command; use that one.

## Where things live in `index.html`

Line numbers drift — search by name. Rough top-to-bottom order:

- `:root` design tokens, then `[data-theme="light"]` overrides — **all colour goes
  through these variables**, never a literal hex in a component
- `VERSION`, `SUPABASE_URL`, `SUPABASE_KEY`, `THEME_KEY`, `WORK_TAGS` constants
- `toTask` / `toResearch` — snake_case row → camelCase object. Every read goes through
  these; every write converts back inline in the op function
- Icon components (`IconPlus`, `IconMoon`, …), then leaf components (`Check`,
  `TaskRow`, `TaskCol`, `ResearchCard`), then views (`TodayView`, `ResearchView`)
- `Dashboard` — all state and every Supabase call. Components are presentational and
  take callbacks; they do not talk to the database
- `App` → `ReactDOM.createRoot`, then service worker registration

## Conventions

- Mutations are optimistic: update React state, call Supabase, roll the state back and
  `showErr()` on failure. Follow `toggleTaskDone` as the reference implementation
- New panels belong in `TodayView` alongside the task columns, not as new views
- Match the existing design language — the user likes it and it is carried forward
  deliberately. Reuse existing classes before writing new CSS
- Shipping a change means bumping `VERSION` **and** the `CACHE` constant in `sw.js`,
  or the phone keeps serving the old build

## Boundaries

- **Never disable RLS or add a table without a policy.** `work_events` holds employer
  meeting titles. The old `DISABLE ROW LEVEL SECURITY` pattern in `schema.sql` is being
  removed, not copied
- **Never commit a key that is not publicly safe.** The Supabase publishable key is
  intentionally in the HTML; a service-role key, Google client secret or API key never is
- **Ship the auth gate before enabling RLS** (Task 3 before Task 4) or the deployed app
  locks the user out of itself
- **Do not add a build step, bundler or package.json** without raising it first — the
  no-build property is what makes this app cheap to deploy (D6)
- **Do not reintroduce anything in PLAN.md §1 "out of scope"**: no reading/replying to
  mail in-app, no sending, no storing message content, no timeline view, no multi-user
- Ask before running SQL against Supabase; the user runs migrations by hand

## Known gotchas

- Babel standalone compiles in the browser, so a syntax error is a blank page with a
  console error, not a build failure. Check the console after every edit
- The CDN pulls React's **development** build. Left as-is for now; do not "fix" it as a
  drive-by, but it is a legitimate future task
- Supabase free tier pauses on inactivity — DNS goes NXDOMAIN and the project looks
  deleted when it is only paused
- The work calendar exists **only** on the iPhone. A silent sync failure is the most
  likely real fault, which is why `work_events_freshness` and the staleness banner are
  load-bearing, not polish

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
