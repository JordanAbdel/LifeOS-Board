# Work calendar bridge — iOS Shortcut → Supabase

The managed Outlook calendar exists only on the phone. This Shortcut is the only
path that data has into the app. Everything else in v1 reads a Google API.

Substitute before building:
- `PROJECT` — Supabase project ref (the subdomain)
- `KEY` — the publishable/anon key

## Why delete-then-insert rather than upsert

A cancelled meeting still exists in the mirror if you only upsert — the row was
written yesterday and nothing removes it. You'd see a meeting that isn't
happening, which is worse than seeing nothing. So each run clears today-forward
and rewrites it.

## Actions, in order

1. **Find Calendar Events**
   - Filter: `Calendar` is *(your work calendar)*
   - Filter: `Start Date` is `today` — or `is within the next 7 days` if the
     panel should show the week
   - Sort by `Start Date`, ascending

2. **Count** → `Items in Find Calendar Events`
   - Add an **If** immediately after: `If Count is 0, Stop This Shortcut`
   - Without this, an empty result wipes the table and the panel shows a blank
     day that looks identical to a successful sync of a free day.

3. **Format Date** (inside a later step, see 5) — Shortcuts emits localised date
   strings by default, which Postgres rejects. ISO 8601 is required.

4. **Get Contents of URL** — the clear
   - URL: `https://PROJECT.supabase.co/rest/v1/work_events?starts_at=gte.{{TodayISO}}`
   - Method: `DELETE`
   - Headers:
     - `apikey`: `KEY`
     - `Authorization`: `Bearer KEY`
   - For `{{TodayISO}}`: a **Format Date** action on `Current Date`, custom
     format `yyyy-MM-dd`, taken at start of day.

5. **Repeat with Each** over the events from step 1
   - Inside, **Dictionary**:
     - `ext_id`     → Repeat Item → `Calendar Event` → `ID`
     - `title`      → Repeat Item → `Title`
     - `starts_at`  → Format Date(Repeat Item → Start Date), ISO 8601
     - `ends_at`    → Format Date(Repeat Item → End Date), ISO 8601
     - `all_day`    → Repeat Item → `Is All Day`
     - `location`   → Repeat Item → `Location`
   - **Add to Variable**: `payload`

6. **Get Contents of URL** — the write
   - URL: `https://PROJECT.supabase.co/rest/v1/work_events`
   - Method: `POST`
   - Headers:
     - `apikey`: `KEY`
     - `Authorization`: `Bearer KEY`
     - `Content-Type`: `application/json`
     - `Prefer`: `return=minimal`
   - Request Body: `JSON` → the `payload` variable

## Automation

Shortcuts app → Automation → Time of Day. Three runs: 07:00, 12:00, 17:00.
Turn **Ask Before Running** off, or it never fires unattended.

Meetings booked at 3pm won't appear until the 5pm run. If that gap turns out to
matter, add a "When I open <app>" automation as well so a manual open forces a
sync — but start with the timed runs and see whether the staleness actually
bites.

## Verify

After the first manual run:

```bash
curl -s "https://PROJECT.supabase.co/rest/v1/work_events?select=title,starts_at&order=starts_at" -H "apikey: KEY"
```

Then check `work_events_freshness` returns an `age` under a minute.
