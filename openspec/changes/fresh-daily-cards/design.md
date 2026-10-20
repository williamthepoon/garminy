# Design

## Context

`mac-content-feeds` provides:
- the `FEED` message, with channel, batch, index, count, stamp, source and text
- whole-set staging and per-channel storage (`Feeds`)
- the Mac's low-priority lane
- the `FeedCard` base, with a per-channel cursor and the `shown()`/`tick()` hooks

Today `Daily` picks `days % 120` for fortunes and quotes, and on-this-day picks one entry per date. `TextCard.refresh()` reloads only when the date changes, and draws with `Ui.drawFitted(..., FONT_TINY)`.

On 2026-10-20 the Wikimedia featured feed (`/feed/v1/wikipedia/en/featured/YYYY/MM/DD`) returned `dyk` (about 6–9 items of 80–155 chars, starting "... that"), `onthisday` (about 17 items, each with `year` and `text`), plus `tfa`, `mostread`, `news` and `image`. `dyk` was present only for the current date. `icanhazdadjoke.com` returns `{joke}` for `Accept: application/json`.

## Goals / Non-Goals

**Goals:**
- One Wikimedia request a day feeds both Fortune facts and On this day.
- The quotes need no network at all.
- The watch-side change is mostly moving the three text cards onto `FeedCard` with a bundled fallback.

**Non-Goals:**
- Changing the bundled watch content files.

## Decisions

### Channels and sets
| channel | built | items | source | stamp |
|---|---|---|---|---|
| 1 quote | local midnight, at launch if missing | 12 from the Mac pool | empty | 0 |
| 2 fortune | local midnight, at launch or wake if missing | today's DYK facts, then jokes to make 12 | "Wikipedia" or empty | 0 |
| 3 on-this-day | with the fortune set (same Wikimedia response) | first 12 `onthisday` events | "Wikipedia" | year (as i32; BC years are negative) |

The batch is the Mac time at the set's local start of day plus one hour, so the watch can recover the set's date with `Dates` even across a time-zone offset of up to an hour. On-this-day is used only when that date is today.

### `DailyService` on the Mac
- It owns the day's three sets, keyed by local date and persisted in `Application Support/garminy/daily.json`, so a relaunch resends the same day's sets rather than new ones.
- It schedules a build at local midnight, plus 30 s after wake and at launch when the stored date isn't today.
- If Wikimedia fails, it builds the fortune set from jokes only and retries Wikimedia every 30 min, at most 4 Wikimedia requests a day.
- Jokes are fetched one per request (up to 12), and duplicate joke ids are dropped.

### DYK text
- Strip any HTML tags and decode entities.
- Replace the leading `"... that "` with `"Did you know that "`, and keep the trailing `?`.
- Trim to 140 bytes at a word boundary, ending in `…?`.
- Skip items that would still exceed the limit after trimming meaningfully: under 40 % of the text kept means skip.

### Quote pool and no-repeat history
- `mac/Sources/GarminyCompanion/Resources/quotes.json` holds `[text, author, work]`.
- The author and work give the recorded source, which is never sent.
- The curation rule is that the author died before 1955 or the text is original; this is checked in a unit test against an allow-list file of authors.
- `QuotePicker` (in `GarminyCore`, pure) takes the pool, a history of `[id: lastSent]` and a seeded RNG, and returns 12 ids not sent in the last 30 days.
- History lives in `UserDefaults` and is pruned after 30 days.
- With 1,000 quotes and 12 a day, the window uses 360, so it never runs dry.

### Watch: `TextCard` becomes `FeedCard` with fallback
- `FortuneCard`, `QuoteCard` and `OnThisDayCard` extend `FeedCard(channel, minFont = FONT_TINY)`.
- `FeedCard.items()` returns the saved Mac set when it is fresh enough. For channels 1 and 2 that means `receivedAt` is within 36 h; for channel 3 the set's date must be today.
- Otherwise it returns a fallback provider:
  - Fortune and Quote: a virtual list over the bundled 120 entries, with the cursor seeded to `days % 120` on the first showing of each day.
  - On this day: a one-item list holding the date's bundled fact.
- Bundled entries are loaded one chunk at a time, as today, so memory stays flat.
- The meta line is drawn only when the item has a source (for example "Wikipedia"), at SMALL. The quote has none. On this day keeps its year above the text, from `stamp`.

### Settings name
`cardFortuneTitle` becomes "Fortunes & facts" in `resources/settings/strings.xml` and in the Mac's card table. The property key stays `cardFortune`, so existing toggles are kept.

## Risks / Trade-offs

- [Wikimedia changes the featured-feed shape] → Parse defensively. A missing `dyk` means a jokes-only fortune set; a missing `onthisday` means no channel-3 set, so the watch uses the bundled fact.
- [A joke turns out offensive] → icanhazdadjoke is curated for clean jokes. Keep a small blocklist of joke ids in `GarminyCore` for reported ones.
- [Building a 1,000-quote public-domain pool is real curation work] → Task 2.1 starts from the 120 existing watch quotes and their recorded authors, then extends from public-domain collections. The unit test enforces the author allow-list.
- [CC BY-SA attribution for Wikipedia text] → The meta line shows "Wikipedia" on every Wikipedia item, and the README credits Wikimedia.

## Migration Plan

No migration is needed. Without the Mac, users see the same bundled content, now moving on each showing. The bundled data and the storage keys are unchanged.
