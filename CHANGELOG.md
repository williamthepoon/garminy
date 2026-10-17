# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- First version for the fēnix 7. Eight rotating cards: Fortune, Motivational quote, Umbrella? (YES/MAYBE/NO), Weather (today and tomorrow), Daylight, Moon phase, World clock and On this day.
- Glance launch. Tap to pin a card, UP/DOWN or swipe to navigate, hold BACK to exit. START is never needed.
- Settings in Garmin Connect: choose cards, rotation interval, three world-clock cities, temperature units and backlight (Off/Low/Medium/High).
- Bundled content: 120 fortunes, 120 public-domain quotes and 366 on-this-day facts.
- `scripts/sideload.sh`: one-command install onto a USB-connected fēnix 7 (macOS).
- 27 unit tests covering sun and moon maths, daylight saving, the umbrella rule, the carousel, settings and text fit.
- Optional Mac companion (`mac/`), connected to the watch over Bluetooth:
  - **Agents card** listing Claude Code sessions.
  - **Full-screen alerts** with three buzz patterns for "needs you", "failed" and "done", and for long terminal commands. Tap to dismiss them on both the watch and the Mac.
  - **Presence-aware buzzing**, and keeping the Mac awake while work runs.
  - **For a watch without a phone:** Open-Meteo weather for the Mac's location, and a Watch settings window.
  - **Claude Code plugin** (`claude-plugin/`) and a zsh snippet for terminal alerts.
  - **Install:** `scripts/bundle-mac.sh` and `scripts/mac-signing-identity.sh`.
- New "Mac companion" setting on the watch (default On). The manifest now requests the Bluetooth Low Energy permission.
