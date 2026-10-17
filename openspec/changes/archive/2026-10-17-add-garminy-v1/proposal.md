# Proposal

## Why

Retired Garmin watches end up in drawers, even though their always-on, sunlight-readable MIP screens make good little desk displays. garminy turns one into a 24/7 desk companion that rotates through glanceable "cards". It is open source and installable from the Connect IQ Store by anyone, with no accounts, API keys or personal data. The first device is a Fenix 7 whose START button is broken, so the app must not depend on START.

## What Changes

- New Connect IQ device app, **garminy**, with a glance view so it can be launched without the START button.
- A card carousel that auto-advances on a configurable interval. UP/DOWN and swipes move between cards manually, a tap pins or unpins the current card, a small clock is always visible, and exiting requires holding BACK.
- Eight cards:
  - **Fortune**: one per day, bundled.
  - **Motivational quote**: one per day, bundled.
  - **Umbrella?**: YES/NO with rain chance.
  - **Weather**: today and tomorrow, icon plus high/low.
  - **Daylight**: sun arc, sunrise/sunset and daylight remaining.
  - **Moon phase**: drawn moon, illumination and next full moon.
  - **World clock**: up to 3 chosen cities.
  - **On this day**: one fact per calendar date, bundled.
- Weather data comes only from the watch's built-in Garmin weather, which is synced by Garmin Connect on the phone. All other data is bundled or computed on the watch. The app makes no other network calls.
- User settings in the Garmin Connect app: which cards are enabled, the rotation interval, world-clock cities and temperature units.
- Open-source repository setup: MIT licence, README with build and sideload instructions, and the developer key kept out of the repo.

### Out of scope (v1)

- Any device other than the fēnix 7 (product `fenix7`). v1 targets only that watch. Layout code still scales from screen size, so more devices can be added later.
- Any web requests, companion phone/Mac app, Bluetooth peripherals, or notifications.
- Non-English content and localisation.
- Publishing to the Connect IQ Store. That will be a follow-up change once v1 has been verified on the device.
- The Claude Code and developer-tool cards from earlier brainstorming. These are deferred.

## Capabilities

### New Capabilities
- `card-carousel`: rotating card display, navigation, pinning, the persistent clock, exit behaviour, and launching from the glance.
- `app-settings`: user-configurable options and how changes take effect.
- `daily-content`: the Fortune, Motivational quote and On-this-day cards, with deterministic per-day selection from bundled content.
- `weather-cards`: the Umbrella? and Today/Tomorrow weather cards, including behaviour when no weather data is available.
- `sky-cards`: the Daylight and Moon phase cards, computed on the watch.
- `world-clock`: the World clock card with daylight-saving-aware city times.

### Modified Capabilities
- None (greenfield project).

## Impact

- New Monkey C project in the repo root: `manifest.xml`, `monkey.jungle`, `source/`, `resources/`, and unit tests.
- Toolchain: Connect IQ SDK 9.2.0 and JDK 21. Device files are needed for each target device; only `fenix7` is needed.
- Permissions: Positioning (for location used in sunrise/sunset). Weather access needs no permission.
- New repo files: `LICENSE` (MIT), `README.md`, and a `.gitignore` covering `bin/` and keys.
