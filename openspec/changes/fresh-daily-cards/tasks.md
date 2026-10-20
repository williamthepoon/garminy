# Tasks

## 1. Mac: parsing and picking (GarminyCore)

- [x] 1.1 Add `GarminyCore/DailyFeeds.swift`:
  - featured-feed parsing: `dyk` → "Did you know that …?" text, and `onthisday` → year and text
  - joke parsing
  - the 140-byte word-boundary trim and the skip rule
- [x] 1.2 Add a `QuotePicker`: from the pool, a `[id: lastSent]` history and a seeded RNG, pick 12 ids not sent within 30 days; prune the history
- [x] 1.3 Save fixtures: today's Wikimedia featured response, a response with no `dyk`, and two joke responses. Add `DailyFeedsTests` for DYK rewriting, HTML and entity stripping, trimming, a year of on-this-day events (including BC), and joke dedupe
- [x] 1.4 Add `QuotePickerTests`: 30 days of sets never repeat, the pool never runs dry, and pruning works

## 2. Mac: content and service

- [x] 2.1 Curate at least 400 quotes into `mac/Sources/GarminyCore/QuotePool.swift` as `[text, author, work]`: authors who died before 1955, or traditional proverbs, and non-English authors only in pre-1929 translations. Add an author allow-list with death years, and a test that every author is on it and every text is ≤ 140 bytes and unique
- [x] 2.2 Add `GarminyCompanion/DailyService.swift`:
  - builds the quote, fortune and on-this-day sets per local date, and persists them in `daily.json`
  - builds at midnight, at launch, and 30 s after wake when the date is stale
  - Wikimedia retries every 30 min, capped at 4 a day; jokes capped at 20 a day
  - a User-Agent naming garminy and its repository
- [x] 2.3 Wire `DailyService` into `AppModel`: queue the sets on the low lane after `.snapshotEnd`, and send each set when it is built. Show the status in the Watch settings window
- [x] 2.4 Rename the card in the Mac table to "Fortunes & facts"
- [x] 2.5 Run `swift test --package-path mac` and make sure it passes

## 3. Watch

- [ ] 3.1 Move `FortuneCard`, `QuoteCard` and `OnThisDayCard` onto `FeedCard` (channels 2, 1 and 3, `minFont` FONT_TINY), with bundled fallback providers. Seed the Fortune and Quote fallback cursor from `days % 120` on each day's first showing. On this day keeps the year above the text, from `stamp`
- [ ] 3.2 Make freshness rules per channel: channels 1 and 2 use the set while `receivedAt` is within 36 h; channel 3 only when the set's date (from `batch`) is today
- [ ] 3.3 Show the meta line only for items with a source ("Wikipedia")
- [ ] 3.4 Rename `cardFortuneTitle` to "Fortunes & facts" in `resources/settings/strings.xml`
- [ ] 3.5 Add `(:test)` cases: the fallback advances per showing and seeds by date; channel 3 is ignored on another date; a 37 h-old set falls back; a 12-item cycle shows each item once
- [ ] 3.6 Run `scripts/build.sh` and `scripts/test.sh` and make sure they pass

## 4. Verification

- [ ] 4.1 Simulator, Fortune card: inject (a) a long DYK fact, (b) a short joke and (c) the bundled fallback. Screenshot each and check the fit and the "Wikipedia" meta line, then restore the sources
- [ ] 4.2 Simulator, Quote card: inject the longest pool quote and a short one. Check there's no attribution and the fit is right, and that two showings give two quotes
- [ ] 4.3 Simulator, On this day card: inject a Mac event set (including a BC year) and a set for yesterday's date, which must fall back to the bundled fact. Screenshot each
- [ ] 4.4 Device: run the companion and check fresh facts, jokes, quotes and events within a minute of connecting. The cards change each time they come round. Quitting the companion keeps the content cycling
- [ ] 4.5 Run `openspec validate fresh-daily-cards --strict`
