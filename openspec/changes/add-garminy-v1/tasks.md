# Tasks

## 1. Project scaffolding

- [x] 1.1 Install the `fenix7` device files with SdkManager, then verify `~/Library/Application Support/Garmin/ConnectIQ/Devices/fenix7/` exists
- [x] 1.2 Create `manifest.xml` (device app, min API 3.2.0, fenix7 product only, Positioning permission only), `monkey.jungle`, and a `.gitignore` covering `bin/`, `*.der`, `*.pem`; verify that `monkeyc -d fenix7 -f monkey.jungle -o bin/garminy.prg -y ~/.garmin/developer_key.der` builds an empty app
- [x] 1.3 Add an MIT `LICENSE` and verify it is present at the repo root

## 2. Carousel core (card-carousel)

- [x] 2.1 Implement the `Layout` helper (header band, circular safe box, font picks) and verify a unit test shows the safe box fits inside the circle for 218, 240, 260 and 280 px screens
- [x] 2.2 Implement the `Card` interface, `CarouselView` (single 1 s timer, index, pin, elapsed time, minute-change redraw) and the persistent clock header; verify in the simulator that two placeholder cards rotate at 10 s and the header clock updates
- [x] 2.3 Implement `CarouselDelegate` (UP/DOWN and swipe navigation with timer reset, tap pin/unpin with indicator, navigation clears the pin); verify each scenario in the card-carousel spec in the fenix7 simulator
- [x] 2.4 Implement the guarded exit (short BACK shows the hint, holding for 1 s or more exits, timer-poll fallback); verify both scenarios in the simulator
- [x] 2.5 Implement the glance view (app name plus a one-line summary) and launch-to-first-card; verify in the simulator's glance mode that tapping opens the carousel
- [x] 2.6 Implement the "Enable cards in Garmin Connect" empty state; verify it appears with every card disabled

## 3. Settings (app-settings)

- [x] 3.1 Add `properties.xml` and `settings.xml` (8 card toggles, interval 5/10/20/30/60 with a 10 default, city1–3 with "None", units C/F/Follow device); verify the defaults in the simulator's App Settings editor
- [x] 3.2 Implement a settings reader and `onSettingsChanged()` live rebuild that keeps the current card when it is still enabled; verify that changing the interval and disabling a card in the simulator take effect without a restart

- [x] 3.3 Add the Backlight setting (Off/Low/Medium/High, default Off) and hold the backlight on from the carousel timer; verify a unit test covers the level mapping and the Off transition, and verify in the simulator that the backlight stays on at Medium with no input

## 4. Daily content (daily-content)

- [x] 4.1 Implement daily selection (`daysSinceEpoch mod N`) plus chunked resource loading; verify unit tests confirm same-day stability, that consecutive days differ, and the full cycle before repeat
- [x] 4.2 Write at least 120 original fortunes (≤ 90 characters each) as chunked JSON resources; verify with a test that every entry is ≤ 90 characters
- [x] 4.3 Write at least 120 motivational quotes that are public domain or original (≤ 90 characters, with attribution) as chunked JSON; verify with a test for length and that each has a non-empty attribution
- [x] 4.4 Write 366 On-this-day entries (≤ 90 characters, with year) as 12 monthly JSON resources; verify with a test that every date including 29 Feb has exactly one entry, and spot-check 20 random entries against sources
- [x] 4.5 Implement the Fortune, Quote and On-this-day cards with `fitTextToArea` wrapping; verify in the fenix7 simulator that the longest entry of each card is fully visible
- [x] 4.6 Simulator check: verify that the Fortune, Quote and On-this-day cards change when the simulator date is advanced by one day

## 5. Weather cards (weather-cards)

- [x] 5.1 Implement the pure umbrella rule (12 h window, YES ≥ 50% / MAYBE 30–49% / NO < 30%, peak hour, current-conditions fallback) and staleness formatting; verify unit tests cover all umbrella scenarios and "Updated Xh ago"
- [x] 5.2 Implement the condition-code→icon mapping (8 groups) and draw the icons with primitives; verify each group renders in the simulator
- [x] 5.3 Implement the Umbrella? card; verify in the simulator with weather data set to rainy, borderline, dry and none
- [x] 5.4 Implement the Weather card (today and tomorrow, current temperature, unit setting); verify in the simulator in both °C and °F and in the no-data state
- [x] 5.5 Verify there is no `makeWebRequest` or Communications permission by running `grep -r makeWebRequest source/` (expect no matches) and inspecting the manifest

## 6. Sky cards (sky-cards)

- [x] 6.1 Implement `SunCalc` (NOAA algorithm, polar day/night flags); verify unit tests match reference sunrise/sunset within 5 min for London, Sydney and Tromsø
- [x] 6.2 Implement the location source (Position last known → weather location → cached Storage); verify a unit or simulator test of the fallback order and the "Location unknown" state
- [x] 6.3 Implement the Daylight card (arc, marker, remaining daylight or time to sunrise, polar messages); verify in the simulator at morning, afternoon and night times, and at a polar location
- [x] 6.4 Implement `MoonCalc` (age, illumination, phase name, next full moon); verify unit tests against at least 3 known 2026 full-moon dates within ±1 day
- [x] 6.5 Implement the Moon phase card (disc plus terminator polygon); verify in the simulator that new, waxing crescent, first quarter, full and waning shapes look correct

## 7. World clock (world-clock)

- [x] 7.1 Implement the bundled city table (about 40 cities) and DST rules (EU, US, AUS/NZ, NONE); verify unit tests for San Francisco in July (UTC−7), Montreal in July (UTC−4), Singapore all year (UTC+8), London in January (UTC+0), Sydney in January (UTC+11), and the transition-day edges
- [x] 7.2 Implement the World clock card (up to 3 rows, +1/−1 day marker, sun/moon icon, 12/24 h); verify in the simulator with 1, 2 and 3 cities and with a different simulator time zone

## 8. Integration and docs

- [x] 8.1 Verify a full-carousel run in the fenix7 simulator with all 8 cards enabled: correct order and rotation, and no errors in the console for 10 minutes
- [x] 8.2 Verify memory on fenix7 by checking peak memory in the simulator's memory view (stays well below the 768 KB limit while cycling every card)
- [x] 8.3 Write `README.md` (what it is, card list, settings, build command, sideload via OpenMTP to `GARMIN/APPS`, open from the glance, use a power-only charger); verify the documented build command runs as written
- [ ] 8.4 Sideload to the real Fenix 7, run it on the desk overnight, and verify the next morning that it is still rotating with a correct clock

## Workflow follow-up

- Run `openspec validate add-garminy-v1 --strict` and archive the change once it has been verified on the device.
- Make a separate change for Connect IQ Store publishing.
