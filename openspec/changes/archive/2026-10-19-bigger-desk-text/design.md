# Design

## Context

For the motivation, see proposal.md (Why). The facts below were measured on fēnix 7 with SDK 9.2.0. They come from the device's `simulator.json`, the `.cft` font headers, and a throwaway probe app in the simulator.

| Font | Line height | Caps |
|---|---|---|
| XTINY | 19 | 11.5 |
| TINY | 29 | 17 |
| SMALL | 32 | 19 |
| MEDIUM | 37 | 22.5 |
| LARGE | 40 | 24 |
| NUMBER_MILD / MEDIUM / HOT | 60 / 73 / 100 | 44 / 53 / 73 |

- **NUMBER fonts have a limited character set.** They contain only space, `# % + - . / 0-9 :` and `°`.
- **Vector fonts are available.** fēnix 7 has `Graphics.getVectorFont` (API 4.2.1+). RobotoCondensedBold loads, and `:size => N` gives exactly `getFontHeight == N`. `drawText`, `getTextWidthInPixels` and `fitTextToArea` all accept vector fonts. Each font handle costs about 150 B; the app limit is 768 KB.
- **The fitter today.** `Ui.drawFitted` tries `[MEDIUM, SMALL, TINY, XTINY]` with `fitTextToArea` inside `Layout`'s 182×146 rectangle, and never tries LARGE.
- **Existing chord helper.** `Look.chord` in `AgentsCard.mc` already computes the circle's width at a given y.
- **Wire limits.** `Wire.maxSessions` is 4, so the watch already receives more sessions than it will show. The 20-byte detail limit (`Wire.maxAlertDetail`) cuts silently on a character boundary.

## Goals / Non-Goals

**Goals:**
- One fitting helper that every card uses.
- Built-in fonts remain a complete fallback, so the change works even if vector fonts are dropped.
- No change to the wire format, the frame layouts or the `Proto.mc`/`Wire.swift` vectors other than the detail strings.

**Non-Goals:**
- A theme system or per-user font settings.
- Changing the fonts of the glance or the exit hint.

## Decisions

### 1. Font ladder in `Ui`, with vector sizes first
- `Ui.fonts(maxPx, minFont)` returns a descending list of candidates:
  - vector RobotoCondensedBold from `maxPx` down to 42 px, in 2 px steps (42 is the first size above LARGE's 40 px line, so the ladder stays strictly descending);
  - then LARGE, MEDIUM, SMALL;
  - and TINY only when `minFont` allows it (daily content).
- Vector handles are created lazily and kept in a small dictionary by size.
- If `Graphics has :getVectorFont` is false, or a face returns null, the ladder is built-in fonts only.
- A single constant `Ui.USE_VECTOR` lets the on-watch check switch vector fonts off without other edits.
- Alternatives considered:
  - **Custom BMFont bitmaps:** crisp, but each size needs an exported asset and a licence check. Kept as plan B if vector fonts look bad on the watch.
  - **Built-ins only:** the largest text font is LARGE at 40 px, and MEDIUM and LARGE are only 3 px apart, so there is not enough range for headline words.

### 2. Chord-aware wrapping replaces `fitTextToArea`
- `Ui.wrapRound(dc, l, text, font, top, bottom, margin)` greedily wraps words into lines.
- Each line's maximum width is `chord(y) - 2*margin`, measured at that line's vertical centre. The block is assumed to be centred between `top` and `bottom`.
- It tries line counts k = 1… until the greedy wrap uses exactly k lines and k × lineHeight fits. That avoids the problem that line widths depend on where the block is centred.
- A word wider than its line fails that font, so the ladder moves to the next size and never splits a word.
- `Ui.drawFitted(dc, l, text, top, bottom, color, minFont)` walks the ladder and draws the first fit line by line.
- `Ui.fitLine(dc, l, text, y, fonts)` picks the largest font in which a single line fits the chord at y. It is used for the daylight line, the moon line and the alert kind word.
- Rationale: on a round screen a rectangle wastes about 20% of the width in the middle rows. `fitTextToArea` cannot wrap to varying widths.
- `chord` moves from `Look` to `Layout` so that every card can use it.

### 3. Cache fitted results
- The result of `drawFitted` (font plus lines) is cached in a dictionary keyed on `text|top|bottom|minFont`, and cleared when there are more than 8 entries.
- Text changes at most once a minute, but `onUpdate` also runs on rotations and taps, and each fit costs many `getTextWidthInPixels` calls with vector fonts.

### 4. Layout after removing titles
- `drawTitle` is deleted.
- The content box top moves up to just below the header (about 0.18 h instead of 0.24 h), and its bottom moves to 0.84 h. `boxInsideCircle` no longer applies to a box taller than its inscribed rectangle, so that test changes to check that every drawn line is inside the circle.
- Cards position their content from `boxY`/`boxH` as today.

### 5. Card-by-card choices
- **Umbrella:**
  - An umbrella icon is drawn above the verdict in the verdict's colour (`WeatherIcons.drawUmbrella`). It is built from shapes because the watch fonts have no emoji: a filled half-disc canopy with a scalloped edge, a shaft and a hook. The user asked for it after the on-watch check, because without the title the card gave no sign of what it was about.
  - Verdict uses `fitLine` starting at vector 64 px; LARGE is the fallback.
  - Detail is in MEDIUM white. The text stays "60% at 15:00", because the spec scenario needs it.
  - The stale note uses SMALL.
- **Weather:**
  - Current temperature in NUMBER_MILD.
  - High/low "72/55" in MEDIUM.
  - Day labels "Today"/"Tomorrow" in SMALL, falling back to "Tmrw" if the column is too narrow.
  - The divider stays in grey.
- **Daylight:**
  - Sunrise and sunset in SMALL white.
  - The remaining-time line ("10h 21m left" / "Sunrise in 5h 3m") uses `fitLine` from MEDIUM. The arc moves up into the space the title used.
- **Moon:**
  - The phase name stays the full name (the spec needs "Waxing Crescent" and "Full Moon") and uses `fitLine` from MEDIUM down to SMALL.
  - Illumination is drawn separately in NUMBER_MILD ("76%").
  - The next full moon reads "Full Fri 24" in SMALL. The month is omitted because the next full moon is always less than 30 days away.
- **World clock:**
  - `TimeZones.CODES` is a new list of three-letter codes, parallel to `NAMES` (append-only, like the other lists). The codes are IATA city or airport codes where they read naturally (SFO, LAX, SEA, YVR, DEN, PHX, CHI, MEX, TOR, MTL, NYC, BOS, YHZ, SAO, BUE, REK, LON, DUB, LIS, PAR, BER, MAD, AMS, STO, ROM, ATH, HEL, JNB, IST, MOW, DXB, BOM, BKK, SIN, HKG, SHA, PER, TYO, SEL, BNE, SYD, MEL, AKL, HNL, ANC). Toronto and Montreal use TOR and MTL instead of YYZ and YUL, because few people recognise those. Settings keep the full names.
  - Rows are a third of the content box tall. Codes are SMALL white, "+1" is SMALL accent, and the icons scale with the row height.
  - Times use NUMBER_MILD. In 12-hour mode the digits are NUMBER_MILD and "am/pm" is drawn in SMALL beside them, because the NUMBER fonts have no letters. With a 3-letter code, every row fits at the narrowest row's chord (about 40 + 110 + 25 px against about 200 px). A whole-card MEDIUM fallback stays as a guard but is not expected to trigger.
  - Alternative considered: keeping full names. "San Francisco" plus a 12-hour time does not fit at NUMBER_MILD, so the times would fall back to MEDIUM.

- **Fortune, Quote, On this day:**
  - `drawFitted` with `minFont = TINY`.
  - Quote: the text has no added quote marks and no attribution, so it fills the whole box.
  - On this day: the year is a NUMBER_MILD accent line at the top, and the fact fills the remaining space.
  - Attribution is dropped. `content/quotes.json` keeps `[text, author]`, and the build script still requires an author so the public-domain source stays recorded. It writes only the text to the generated chunks, and `Daily.quote` returns a `String`. This saves resource memory and removes the 26 px line.
- **Agents:**
  - `ROWS = 2`, with two lines per row:
    - the label in MEDIUM, with `Look.truncate` to the chord;
    - "waiting · 3m" in SMALL, in the state colour.
  - The state dot has a radius of 6.
  - "+n" in SMALL counts sessions beyond 2, including those the Mac sent but the card did not show.
  - `STATE_WORDS` becomes `["busy", "waiting", "done", "error"]`.
- **Alert overlay:**
  - The kind word uses `fitLine` from vector 44 px.
  - The label uses `drawFitted` with a SMALL minimum.
  - The detail is SMALL white.
  - The footer is SMALL in grey `DIM` when connected, or accent when the Mac is offline. The kind ring colour already signals the state.

### 6. Companion detail strings
- In `SessionTracker`:
  - `StopFailure` sends "Error".
  - `PermissionRequest` sends `Format.allow(tool)`.
- `Format.allow(tool)`:
  - strips a leading `mcp__<server>__`;
  - returns "Allow X" if it fits in 20 UTF-8 bytes;
  - otherwise shortens X to fit "Allow " + X + "…" in 20 bytes;
  - and returns "Allow tool" when there is no tool name.
- No watch change is needed, because the watch shows whatever detail it receives.

## Risks / Trade-offs

- **Jagged vector text on MIP without anti-aliasing.** Mitigation: an on-watch sideload check before archiving. `USE_VECTOR = false` falls back to built-in fonts, which keeps every other improvement.
- **Vector draw or measure speed on the watch.** Mitigation: the fit cache, plus vector fonts only from 42 px up, where few lines are involved. Plan B if redraws visibly lag: limit vector fonts to single-line hero words.
- **Some daily entries still render at TINY.** This is accepted until the content-rewrite follow-up. The spec floor for daily content is TINY.
- **Agents card now shows 2 rows instead of 3.** The third session becomes "+n". The user chose this to get larger rows.
- **NUMBER_MILD glyph metrics include a lot of empty space** (60 px line, 44 px caps). Vertical centring can look low. Mitigation: centre on the cap height in the simulator check, and adjust the offset per font if needed.

## Migration Plan

This is a watch build plus a companion rebuild (`scripts/bundle-mac.sh`), with no data migration. An older companion keeps sending the old detail strings, and those still display, just cut short as before. Rollback is reverting the commit.

## On-watch check (2026-10-19)

The user sideloaded the build to the fēnix 7 and reviewed every card from the desk with the backlight off. Vector text looked good, and they reported no lag. `USE_VECTOR` stays true.

## Open Questions

- The exact vector size steps (2 px vs 4 px). Choose after measuring draw time on the watch.
