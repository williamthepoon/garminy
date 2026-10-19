# Proposal

## Why

With Backlight set to Low, Medium or High, garminy holds the light on 24/7. On a desk or bedside stand that lights up the room all night, and in an empty office it wastes light no one sees. Users need the light to switch off on its own outside working hours.

## What Changes

- New **Quiet hours** settings: an On/Off toggle plus a start hour and an end hour. The defaults are On, 18:00 to 09:00.
- During quiet hours the app stops holding the backlight on and turns it off once when quiet hours begin. When they end, it holds the light at the chosen Backlight level again.
- During quiet hours the backlight part of a charger alert is suppressed. Alerts still show, and beeps still play when On the charger includes Beep.
- The Mac companion's Watch settings window offers the same three settings, and the SETTINGS wire payload grows by three optional trailing bytes. Older 13- or 15-byte payloads decode with the defaults, so this is not a breaking change.

## Out of scope

- Dimming instead of switching off during quiet hours, and different times on different days.
- Minute-level start and end times. Hours only.
- Blanking or changing what the screen draws. The MIP display stays readable in room light.
- Stopping the system from lighting the screen when someone touches it or presses LIGHT. The watch still uses its own timeout for that.
- Muting beeps or vibration during quiet hours.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-settings`: adds the Quiet hours settings and their defaults.
- `card-carousel`: Keep backlight on now gives way to quiet hours.
- `desk-alerts`: no backlight alert signal during quiet hours.
- `mac-companion-app`: Edit watch settings from the Mac includes Quiet hours.

## Impact

- Watch: `resources/settings/` (properties, settings, strings), `source/Settings.mc`, `source/CarouselView.mc` (backlight hold in `onTick`), `source/companion/Companion.mc` (`Buzz.plan` / `Buzz.play`), `source/companion/Proto.mc` (SETTINGS encode/decode), and tests in `tests/`.
- Mac: `mac/Sources/GarminyCore/Wire.swift` (`WireSettings`, encode/decode), `mac/Sources/GarminyCompanion/AppModel.swift` (persist), `SettingsView.swift` (UI), `Weather.swift` defaults, `mac/Tests/vectors.md`, and `WireTests.swift`.
- Depends on `charger-alert-signal`, which isn't archived yet. Archive it first, because this change modifies the `mac-companion-app` requirement that it rewrites.
