# Design

## Context

This is a greenfield repo; it contains only OpenSpec, `CLAUDE.md` and the toolchain setup. The toolchain is Connect IQ SDK 9.2.0 with JDK 21, using the Monkey C language. The primary device is the fenix7: API 5.2, a 260×260 round MIP screen with 64 colours, and about 768 KB of app memory. v1 targets only the fenix7 (decided 2026-10-17), so its 768 KB app and 64 KB glance limits are the ones that matter. Requirements are in `specs/`, and motivation is in `proposal.md`.

## Goals / Non-Goals

**Goals:**
- Layout scaled from the screen size rather than hard-coded pixels, so other devices can be added later without rewriting.
- Pure, unit-testable logic for selection, astronomy, time zones and the umbrella rule, kept separate from drawing code.
- Modest memory use: content is loaded in small chunks.

**Non-Goals:**
- Background services and glance data sharing beyond a static summary.
- Animations. The display redraws on a card change, on a minute tick, or when settings change.

## Decisions

### D1. App type: device app with glance (not a widget or watch face)
- Widgets time out back to the watch face, and watch faces cannot take input.
- A device app with `(:glance)` stays open indefinitely, gets touch and key events, and can be launched by tapping the glance, which the broken START button requires.
- *Alternatives considered:*
  - A widget, which times out.
  - A watch face plus a separate app, which would mean two products for one experience.

### D2. Card architecture
- Each card is a class implementing a small `Card` interface:
  - `id()`
  - `isAvailable()`
  - `draw(dc, layout)`
  - `refresh()`, which is called on show and on each minute tick.
- A single `CarouselView` owns the list of enabled cards, the index, the pin state and one `Timer`.
- `CarouselDelegate` (a `BehaviorDelegate` plus key overrides) maps inputs to carousel actions.
- *Alternative considered:* one `WatchUi.View` per card with `switchToView`. Rejected because it gives slower transitions, uses more memory, and keeps less state.

### D3. Rotation timer
- A single repeating `Timer.Timer` runs at 1 s.
- On each tick it:
  - increments the elapsed time on the current card;
  - advances the card when the configured interval is reached and the card isn't pinned;
  - calls `requestUpdate()` only when the card or the minute has changed.
- One timer avoids the device's limit on concurrent timers. Because the screen redraws only on change, the cost on MIP is negligible.

### D4. Guarded exit
- `onKeyPressed(KEY_ESC)` records the press time.
- `onKeyReleased` exits if the key was held for 1 s or longer; otherwise it shows the hint.
- `onBack()` returns `true` to swallow the default exit.
- *Risk:* some firmware handles a long BACK press at the system level. *Fallback:* if the release event never arrives, the next timer tick checks whether BACK is still held and exits after 1 s.

### D5. Daily selection
- The entry index is `daysSinceEpoch(localDate) mod N`.
- Consecutive days therefore always differ, and the full set cycles before repeating, which satisfies the "varied selection" requirement.
- Fortunes and quotes each use a set of N ≥ 120 entries.

### D6. Bundled content and memory
- Content is stored as JSON string arrays under `resources/jsonData/`.
- To keep memory low, On-this-day is split into 12 monthly resources, and only the current month is loaded.
- Fortunes and quotes are split into chunks of 40, and only the chunk containing today's index is loaded.
- `WatchUi.loadResource` is called on refresh, and the result is dropped after today's string is copied out.
- *Alternative considered:* one big array per file. Rejected because loading all content at once wastes memory for no benefit.

### D7. Content sourcing and licence
- All bundled text is original writing, or public-domain quotes with attribution.
- On-this-day entries are short original one-line summaries of verifiable historical events, each carrying a year.
- The content is MIT-licensed together with the code.
- Each entry is capped at 90 characters so it fits the screen.

### D8. Weather access
- The cards use these `Toybox.Weather` calls (API 3.2):
  - `getCurrentConditions()`
  - `getHourlyForecast()`
  - `getDailyForecast()`
- The umbrella rule is a pure function that takes a list of `(time, precipChance)` pairs. It finds the highest chance within the next 12 hours, falling back to the current conditions if there are none, and maps it to YES (≥ 50%), MAYBE (30–49%) or NO (< 30%).
- A three-way verdict replaces a configurable threshold: MAYBE covers the borderline cases where a single cut-off misleads, and it avoids adding another setting.
- Staleness comes from `CurrentConditions.observationTime`.
- Condition codes are mapped to about 8 icon groups: clear, partly cloudy, cloudy, rain, snow, storm, fog, wind.

### D9. Sun times
- Sunrise and sunset use the NOAA solar-position algorithm, implemented in floating point (Double) in `SunCalc`.
- The algorithm works on all API levels, whereas `Weather.getSunrise` needs 3.3. Its accuracy is about 1 minute at most latitudes.
- Location comes from `Position.getInfo()` (the last known position). If that's missing, it falls back to `CurrentConditions.observationLocationPosition`.
- The last good location is cached in `Application.Storage`.

### D10. Moon phase
- The phase is the age within a 29.530588-day synodic month, measured from the reference new moon of 2000-01-06 18:14 UTC.
- Illumination is `(1 − cos(2π·age/P)) / 2`.
- The next full moon is found by stepping to age P/2. This is accurate to about ±0.5 day, within the one-day requirement.
- The moon is drawn as a disc plus a terminator ellipse built from `fillPolygon` points. This keeps memory low and needs no bitmaps.

### D11. World clock time zones
- A bundled table holds about 40 cities, each with a name, a standard UTC offset in minutes, and a DST rule:
  - EU: last Sunday of March → last Sunday of October, at 01:00 UTC.
  - US: second Sunday of March → first Sunday of November, at 02:00 local time.
  - AUS/NZ: first Sunday of April → first Sunday of October, reversed for the southern hemisphere.
  - NONE.
- The settings list stores the city index.
- City time is `UTC now + offset + dst`, computed with `Gregorian.utcInfo`.
- *Alternative considered:* a full tz database. Rejected as too large and unnecessary for a curated list.

### D12. Layout
- A `Layout` helper computes the following from `dc.getWidth()` and `getHeight()`:
  - header band: the top 18%, holding the clock and pin dot;
  - a safe content box inscribed in the circle;
  - font choices.
- Text wrapping uses `Graphics.fitTextToArea` (API 3.1+).
- Colours are limited to MIP-safe palette values: black, white and the 0x55/0xAA/0xFF channel steps. The design uses a dark background with a light foreground.

### D13. Settings
- Settings are `properties.xml` entries with a matching `settings.xml`:
  - 8 boolean card toggles;
  - an `interval` list;
  - `city1` to `city3` lists, each including "None";
  - a `units` list.
- `onSettingsChanged()` rebuilds the enabled-card list and resets the index, preserving the current card if it is still enabled.

### D14. Tests
- Unit tests use the Connect IQ test framework (`(:test)` functions, run with `monkeydo … -t` in the simulator).
- They cover:
  - daily selection;
  - the umbrella rule;
  - SunCalc against reference values (London, Sydney and Tromsø on a solstice);
  - MoonCalc against known 2026 full moons;
  - DST transitions;
  - content-length limits.

## Risks / Trade-offs

- [The fenix7 device files are not yet installed, because only vivoactive devices were downloaded] → Install `fenix7` with SDK Manager before running the build tasks.
- [The long-press BACK behaviour may vary by firmware] → Use the timer-poll fallback (D4) and verify on real hardware.
- [The app may be killed if the user leaves to the watch face] → Document "open from glance, leave running" in the README.
- [Weather data is only as fresh as the phone's syncs] → Show a staleness note (spec) rather than hiding the data.
- [Bundled historical facts may contain errors] → Keep entries short and well known, and add a task to spot-check a sample against sources.
- [Memory use grows as content is added] → Use chunked resources (D6), and check peak memory in the fenix7 simulator.
- [The touchscreen can be disabled in system settings] → Buttons cover all actions except pinning; this is documented.

## Open Questions

- Whether to support more devices is left to a later change. v1 builds only for fenix7.
