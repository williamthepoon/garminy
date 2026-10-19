# Tasks

## 1. Fitting and font helpers

- [x] 1.1 Move `chord` from `Look` (`AgentsCard.mc`) into `Layout`, and update its callers. Verify that `scripts/build.sh` succeeds
- [x] 1.2 Add `Ui.fonts(maxPx, minFont)`:
  - Order: vector RobotoCondensedBold from `maxPx` down to 42 px, then LARGE, MEDIUM, SMALL, plus TINY only if `minFont` allows it.
  - Vector fonts are created lazily and cached; built-in fonts only when `Ui.USE_VECTOR` is false or `getVectorFont` returns null.
  - Verify with a `(:test)` that checks the ladder is in descending order and never contains XTINY.
- [x] 1.3 Add `Ui.wrapRound` (wrap each line to the chord, never split a word) and `Ui.fitLine`.
  - Rewrite `Ui.drawFitted(dc, l, text, top, bottom, color, minFont)` on top of them, with the 8-entry fit cache.
  - Verify with `(:test)`s:
    - a short string picks a font taller than SMALL;
    - an unbreakable over-long word returns no fit;
    - every wrapped line fits `chord(y)`;
    - a cache hit returns the same lines.
- [x] 1.4 Delete `drawTitle`. Move the content box up to just below the header and its bottom to 0.84 h.
  - Keep the `boxInsideCircle` test (the taller box still fits inside the circle) and extend it to check that `chord` is positive across the box.
  - Make `drawMessage` call the new `drawFitted`, so no-data messages get bigger.
  - Verify that `scripts/test.sh` passes.

## 2. Weather and sky cards

- [x] 2.1 Umbrella:
  - The verdict uses `fitLine` from vector 64 px with a LARGE fallback.
  - The detail is MEDIUM white, still "60% at 15:00".
  - The stale note is SMALL.
  - Verify by simulator screenshot: YES, MAYBE and NO, plus a stale state.
- [x] 2.2 Weather:
  - Current temperature in NUMBER_MILD.
  - High/low as "72/55" in MEDIUM; the formatter has a `(:test)` for "72/55" and "--/--".
  - Day labels in SMALL ("Tmrw" fallback).
  - Verify by simulator screenshot in °C and °F with a negative temperature.
- [x] 2.3 Daylight:
  - The day text becomes "Xh Ym left", with a `(:test)` on the line builder for both day and night text.
  - Sunrise and sunset in SMALL white.
  - The line uses `fitLine`, and the arc moves up.
  - Verify by simulator screenshot during the day and at night: the line is not clipped, and the polar messages are still readable.
- [x] 2.4 Moon:
  - The phase name uses `fitLine` from MEDIUM.
  - Illumination % in NUMBER_MILD.
  - "Full Fri 24" in SMALL, with a `(:test)` for the date string.
  - Verify by simulator screenshot for "Waxing Crescent" (the longest name) and "Full Moon".

## 3. World clock and daily content

- [x] 3.1 World clock:
  - Add `TimeZones.CODES`, parallel to `NAMES`, with a `(:test)` that checks the list has the same length, every code is three uppercase letters, and no two codes match.
  - Rows a third of the box tall; codes SMALL white; "+1" SMALL accent; icons scaled to the row.
  - Times in NUMBER_MILD with am/pm in SMALL, plus a whole-card MEDIUM fallback.
  - Verify by simulator screenshots in 24-hour and 12-hour mode with SFO, JNB and SIN: nothing clipped.
- [x] 3.2 `scripts/build_content.py` writes only the quote text to `resources/jsonData/quotes*.json`, and still requires an author in `content/quotes.json`. `Daily.quote` returns a `String`. Verify that `scripts/build.sh` passes and that the generated quote chunks contain no authors. Update the quote `(:test)`s.
- [x] 3.3 Fortune, Quote and On this day:
  - `drawFitted` with a TINY minimum.
  - Quote: no added quote marks and no attribution line.
  - On this day: the year in NUMBER_MILD accent at the top.
  - Verify by simulator screenshots with the longest and shortest entry of each set: every word is visible, nothing is below TINY, and short fortunes render taller than SMALL.

## 4. Agents card and alert overlay

- [x] 4.1 Agents card:
  - `ROWS = 2`.
  - The label in MEDIUM, cut with `truncate` to the chord.
  - "waiting · 3m" in SMALL, in the state colour, with `STATE_WORDS` = busy, waiting, done, error.
  - A dot of radius 6.
  - The "+n" count is SMALL and counts every session beyond 2 (`moreSessions` plus unshown); a `(:test)` covers 1, 2, 4 and 4+2-hidden sessions.
  - Verify by simulator screenshots with 1, 2 and 4 sessions, and with "Mac offline".
- [x] 4.2 Alert overlay:
  - The kind word uses `fitLine` from vector 44 px.
  - The label uses `drawFitted` with a SMALL minimum.
  - The detail is SMALL white.
  - The footer is SMALL in `DIM` when connected, or accent when offline.
  - Verify by simulator screenshots for needs-you with "+2", done, failed, and Mac offline.
- [x] 4.3 Mac: `StopFailure` detail "Error". `PermissionRequest` detail from a new `Format.allow(tool)` (strip `mcp__<server>__`, "Allow X" within 20 UTF-8 bytes, "…" when shortened).
  - Update `TrackerTests`, the `WireTests` sample and `mac/Tests/vectors.md` from "Permission: Bash" to "Allow Bash", and keep `tests/CompanionTests.mc` in step with the vector.
  - Add tests for a long MCP tool name and a missing tool.
  - Verify that `swift test --package-path mac` and `scripts/test.sh` pass.

- [x] 4.4 Umbrella icon: `WeatherIcons.drawUmbrella` draws above the verdict in its colour, and also above the no-weather message. Verify by simulator screenshot of YES, MAYBE and NO with no data, then sideload and confirm with the user

## 5. Integration checks

- [x] 5.1 `grep -n FONT_XTINY source/` shows only the exit hint, and `grep -n drawTitle source/` returns nothing
- [x] 5.2 Sideload with `scripts/sideload.sh` and look at every card from desk distance (about 65 cm) with the backlight off. Record whether the vector text is crisp enough and whether redraws lag. If it fails, set `USE_VECTOR = false` and re-check, and note the outcome in design.md.
- [ ] 5.3 Rebuild the companion with `scripts/bundle-mac.sh`, trigger a permission prompt for an MCP tool and a stop failure, and check that the watch shows "Allow …" and "Error" in full
- [x] 5.4 Update the README screenshots or card descriptions if they mention card titles or the 3-row Agents card, and verify that the README matches the new behaviour

## Workflow follow-up

- Run `openspec validate bigger-desk-text --strict`, then `/opsx:archive` once 5.2 and 5.3 are confirmed on the watch.
- Follow-up change: rewrite long fortunes, quotes and on-this-day entries so they fit at SMALL, with a pixel-width build check; and resize the header clock.
