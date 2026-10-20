# Proposal

## Why

Fortune, Quote and On this day each pick one bundled entry per day. With nine cards at 10 s, the same fortune and quote come back about every 90 seconds, about 900 times a day each. Now that the Mac companion can push text to the watch (`mac-content-feeds`), these cards can show fresh content and move on every time they come round.

## What Changes

- **All three cards show the next item each time they come round,** by rotation or UP/DOWN, instead of one item all day. This applies to Mac content and to the bundled fallback alike.
- **Fortune becomes "Did you know" plus jokes:**
  - Each day the Mac sends up to 12 items: that day's Wikipedia "Did you know…" facts (keyless Wikimedia feed, CC BY-SA, shown with "Wikipedia" as the source) mixed with a few dad jokes from icanhazdadjoke (keyless).
  - The card's settings name becomes "Fortunes & facts".
- **Quote comes from a large pool on the Mac:**
  - The companion app bundles at least 400 public-domain or original quotes and sends 12 a day.
  - It sends no quote again within 30 days.
  - There's no network dependency and still no attribution line.
- **On this day comes from Wikipedia:** the Mac sends up to 12 of the day's selected events from the Wikimedia on-this-day feed. The year shows above the event, as today.
- **Offline fallback:** with no Mac set newer than 36 hours, each card uses the bundled watch content as today. Fortune and Quote still move on each showing.
- The `mac-content-feeds` channels 1 (quote), 2 (fortune) and 3 (on this day) come into use.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `daily-content`:
  - The once-per-day selection becomes per-showing rotation.
  - Fortune gains Mac-fed facts and jokes; Quote gains a Mac pool with a 30-day no-repeat window; On this day gains Wikipedia events.
  - New requirements cover the Mac providers and the offline fallback.

## Out of scope

- Desk extras the user didn't choose: spacing text cards apart, tap to show the next item, a new-item dot, glance text.
- User-configurable content sources for these cards, and category or content filters.
- Word of the day, Hacker News and other channels. The pipeline allows them later.
- Changing the bundled watch content. It stays as the offline fallback.

## Dependencies

This change depends on `mac-content-feeds`, which provides the `FEED` message, staging, storage, the low-priority lane and `FeedCard`, so apply that change first.

## Impact

- Mac:
  - new `GarminyCore/DailyFeeds.swift` (Wikimedia featured-feed parsing, joke parsing, the quote picker with history)
  - a bundled `quotes.json` resource with each source recorded
  - new `GarminyCompanion/DailyService.swift` (fetches at local midnight, on wake and at launch)
  - `AppModel.swift`, plus tests and fixtures
- Watch:
  - `source/DailyContent.mc` (`TextCard` → `FeedCard` with the bundled fallback, per-showing cursor)
  - `resources/settings/strings.xml` (card name)
  - `tests/`
- Network:
  - one Wikimedia request a day (`api.wikimedia.org/feed/v1/wikipedia/en/featured/YYYY/MM/DD`), which also contains on-this-day
  - a few icanhazdadjoke requests a day
  - both with a descriptive User-Agent; no personal data
