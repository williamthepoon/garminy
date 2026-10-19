# Proposal

## Why

From the desk (50–80 cm away) much of the watch is unreadable. Most supporting text is hard-coded to `FONT_XTINY` (19 px line, 11.5 px caps): card titles, high/low temperatures, sunrise and sunset, city names, the moon date, agent state lines and the alert footer. The text-fitting helper also falls back to `FONT_XTINY` for about half the quotes and 45% of on-this-day entries, because it wraps into a 182 px rectangle. Separately, the Mac companion cuts two alert details at the 20-byte wire limit, so the watch shows "Stopped with an erro" and "Permission: NotebookEd".

## What Changes

- **Remove card titles.** Each card's icon, arc, moon or layout already says what it is, and dropping the title gives every card about 25 px more height.
- **Minimum text size.** Text read from the desk uses `FONT_SMALL` (32 px line) or larger. `FONT_XTINY` is no longer used on any carousel card or on the alert overlay. Data is drawn in white, and grey is kept for text you can miss.
- **Bigger fitted text.** `Ui.drawFitted` picks the largest vector RobotoCondensedBold size that fits, falling back to the built-in LARGE, MEDIUM and SMALL fonts. It wraps each line to the round screen's width at that height, not a fixed rectangle, and caches the result. Bundled daily content may still drop to `FONT_TINY` as a last resort, until a later change rewrites the long entries.
- **Large numerals and hero words.** `FONT_NUMBER_MILD` is used for values that are only digits: world-clock times when they fit, the current temperature and the moon illumination %. A large vector font is used for the Umbrella verdict and the alert kind word.
- **Shorter copy:**
  - Daylight: "10h 21m left".
  - Moon: "Full Fri 24".
  - Weather high/low: "72/55".
  - Quotes: no literal quote marks, and **no attribution line**. The quote gets the whole card.
  - On this day: the year moves to the top of the card.
- **World clock shows three-letter city codes** (SFO, MTL, SIN…) instead of full names, so the times fit in large numerals. Settings still list full names.
- **Agents card shows 2 sessions instead of 3**, with the label in MEDIUM and a one-word state (busy, waiting, done, error) plus the time in SMALL. Further sessions are counted as "+n".
- **Mac companion alert details always fit the 20-byte wire limit:**
  - Failed alerts say "Error".
  - Permission alerts say "Allow <tool>". MCP prefixes are dropped, and long names are shortened with "…".

## Capabilities

### New Capabilities
- `desk-legibility`: app-wide rules for on-screen text read from the desk. These cover the minimum font size, no card titles, data colour, fitting text to the round screen, and the large-numeral and hero tiers.

### Modified Capabilities
- `weather-cards`: the Umbrella? card gains an umbrella icon, because it no longer has a title.
- `sky-cards`: the daytime Daylight line becomes "Xh Ym left".
- `daily-content`: the Motivational quote card no longer shows an attribution. "Text fits the screen" now requires wrapping to the round display, with a floor of TINY in place of any smaller font. The On-this-day year is shown above the fact.
- `world-clock`: cities are shown by a fixed three-letter code.
- `agent-status`: the Agents card lists up to 2 sessions with one-word states and a "+n" overflow count. Agent alert details must fit the wire limit without being cut.

## Impact

- **Watch:**
  - `source/Ui.mc`: fitter, fonts, chord wrap.
  - `source/Layout.mc`: content box and the chord helper.
  - `source/Card.mc`: drop `drawTitle`.
  - `source/WeatherCards.mc`, `source/SkyCards.mc`, `source/WorldClockCard.mc` and `source/TimeZones.mc` (codes), `source/DailyContent.mc`, `source/companion/AgentsCard.mc`.
- **Content:** `content/quotes.json` keeps its authors as the public-domain source record. `scripts/build_content.py` stops copying them into the generated `resources/jsonData/`.
- **Mac:** `mac/Sources/GarminyCore/SessionTracker.swift` detail strings, plus `TrackerTests.swift`, `WireTests.swift` and `mac/Tests/vectors.md` where they use "Permission: Bash". `Proto.mc` and `Wire.swift` layouts are unchanged.
- **Tests:** `tests/*.mc` cases for the fitter, the daylight line and the agent row selection.
- **Risk:** vector fonts on a MIP display without anti-aliasing may look rough, and their drawing speed on the watch is unknown. Built-in fonts remain as the fallback, and an on-watch check is required before archiving.

## Out of scope

- The header clock size. The spec calls it a "small header", so changing it is a separate change.
- Rewriting fortunes, quote text and on-this-day entries to fit at SMALL (follow-up change, with a build-time fit check).
- Glance text and the "Hold BACK to exit" hint. These are read only with a hand on the watch.
- New devices, custom bitmap fonts, or changes to the wire format or frame layouts.
