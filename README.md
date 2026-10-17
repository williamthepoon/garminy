# garminy

[![CI](https://github.com/williamthepoon/garminy/actions/workflows/ci.yml/badge.svg)](https://github.com/williamthepoon/garminy/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Device: fēnix 7](https://img.shields.io/badge/device-f%C4%93nix%207-orange)

garminy turns a retired Garmin fēnix 7 into a desk display. It sits on a stand on the charger and rotates through glanceable cards.

![garminy cards in the fēnix 7 simulator](docs/screenshots.png)

> **Status:** v1 works in the Connect IQ simulator and all unit tests pass. It has not yet been tested on a real watch, and it is not on the Connect IQ Store yet; install it by sideloading (see below).

## Cards

| Card | Shows |
|---|---|
| Fortune | One fortune per day |
| Motivational quote | One public-domain quote per day |
| Umbrella? | **YES / MAYBE / NO** from the highest hourly rain chance in the next 12 h (YES ≥ 50%, MAYBE 30–49%, NO < 30%) |
| Weather | Today and tomorrow: icon, high/low, current temperature |
| Daylight | Sun arc, sunrise/sunset, daylight left or time until sunrise |
| Moon phase | Drawn moon, phase name, illumination, next full moon |
| World clock | Up to 3 cities (default San Francisco, Singapore, Montreal), DST-aware |
| On this day | A historical event for every date of the year |

It needs no accounts, API keys or servers. Weather comes from the watch's built-in Garmin weather, which the Garmin Connect phone app keeps up to date. Everything else is bundled with the app or calculated on the watch.

## Controls

garminy never uses the START button, so a watch with a broken START button works fine.

| Input | Action |
|---|---|
| DOWN / swipe up | Next card |
| UP / swipe down | Previous card |
| Tap | Pin or unpin the current card (an orange dot means pinned) |
| Hold BACK for 1 s | Exit (a short press only shows a hint) |

**Opening it:** from the watch face, press UP or DOWN to scroll through the glances, then tap the **GARMINY** glance.

## Settings

In the Garmin Connect app on your phone, go to **Devices → fēnix 7 → Activities & Apps → garminy → Settings**:

- Turn each card on or off
- Seconds per card: 5, 10, 20, 30 or 60
- World clock cities 1–3, chosen from 45 cities, or None
- Temperature units: follow device, °C or °F

## Build

Requirements:
- A JDK, for example `brew install openjdk@21`.
- The [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/), installed with SDK Manager, plus the **fēnix 7** device.
- A developer key:

```sh
mkdir -p ~/.garmin
openssl genrsa -out ~/.garmin/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in ~/.garmin/developer_key.pem -out ~/.garmin/developer_key.der -nocrypt
```

Then build and test:

```sh
scripts/build.sh      # builds bin/garminy-fenix7.prg
scripts/test.sh       # runs the unit tests in the simulator
```

Edit text content in `content/*.json`. The build checks it (maximum 90 characters per entry, every date covered) and generates `resources/jsonData/`.

## Install on the watch (sideload)

1. Connect the watch to your computer with its USB cable. On macOS, use [OpenMTP](https://openmtp.ganeshrvel.com/) and fully quit Garmin Express first.
2. Copy `bin/garminy-fenix7.prg` into `GARMIN/APPS/` on the watch.
3. Unplug the watch. garminy appears in the glance loop.

## Desk tips

- **Use a power-only charger** (a wall adapter), not a computer port. When the watch is connected to a computer, it switches to USB mode and stops apps.
- **Leave garminy open.** Going back to the watch face can close it. Reopen it from the glance.
- **Disable Sleep Mode or schedule it around your desk hours** (System → Sleep Mode) so the watch keeps showing cards.
- **Protect the battery from being held at 100% for months.** A smart plug on a schedule can keep it roughly between 40% and 80%.

## Contributing

Issues and PRs are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. In short: fēnix 7 only, no API keys or servers, and never rely on the START button.

The project uses [OpenSpec](https://openspec.dev/) for spec-driven development. Specs are in `openspec/specs/`, and in-progress changes are in `openspec/changes/`. Release notes are in [CHANGELOG.md](CHANGELOG.md).

## Licence

MIT. Fortunes and on-this-day text are original. Quotes are public domain or proverbs.
