# Design

## Context

`CarouselView.onTick` calls `Attention.backlight(level)` every second while the Backlight setting is above Off. That repeated call is what beats the device timeout (`source/CarouselView.mc:119`). `Buzz.play` turns the light on for charger alerts by calling `Buzz.plan(charging, signal)`, which returns `[vibrate, beep, light]` (`source/companion/Companion.mc`). Settings live in `Application.Properties` and travel to the Mac in the SETTINGS payload. That payload already uses optional trailing bytes (`optU8` on the watch, `u8() ?? default` on the Mac), so newer fields can be added without breaking older peers.

## Goals / Non-Goals

**Goals:**
- Keep the quiet-hours check a pure, unit-testable function of (enabled, start, end, hour).
- Don't add a timer. The existing 1 s tick catches the start and end of quiet hours.

**Non-Goals:**
- Running when the app is closed. Quiet hours only affect what garminy does while it's open.

## Decisions

1. **Store whole hours (0–23) as three properties: `quietHours` (bool, default true), `quietStart` (number, default 18) and `quietEnd` (number, default 9).** A list of 24 hours is easy to pick from in Garmin Connect, and the user asked for hour-level control. Minutes would need 96 list entries or free text, which Garmin Connect validates poorly.
   - Considered: a single "preset" list (Evenings, Nights, …). Rejected because it's too rigid.

2. **Add `Settings.isQuiet(enabled, start, end, hour)` as a pure function, plus `Settings.quietNow()`, which reads the properties and `System.getClockTime().hour`.** The rules are: start == end means never quiet, start < end means `start <= h < end`, and start > end means `h >= start || h < end`. The unit tests cover the spec scenarios directly.

3. **Carousel: work out an effective level each tick, `quietNow() ? 0.0 : _backlight`, and keep `_quiet` from the previous tick.** On the tick where quiet hours begin, call `setBacklight(false)` once, then stop calling. This happens whatever the Backlight setting is: on the live watch, Backlight was Off and the light was still lit at 19:52, so leaving the light to the device whenever Backlight is Off didn't meet the goal. When they end, the existing hold resumes on the next tick. Calling `setBacklight(false)` only on that change means the app doesn't fight a touch-triggered light during quiet hours, which the spec requires. `reload()` leaves `_quiet` alone because the next tick re-evaluates quiet hours from the new settings anyway, and resetting it would switch off a light the user just turned on with a touch.
   - Considered: a separate timer scheduled for the start and end times. Rejected because the 1 s tick already exists and a second timer would have to handle clock and time-zone changes.
   - Opening the app during quiet hours: `_quiet` starts false, so the first tick sends one `backlight(false)`. That turns off the light from the tap that opened the app, which is what we want for a desk display at night.

4. **`Buzz.plan(charging, signal, quiet)` clears the light flag when `quiet` is true.** `Buzz.play` passes `Settings.quietNow()`. This keeps the decision in the already-tested pure function.

5. **Wire: add `quiet on u8, start u8, end u8` to the end of SETTINGS, taking it from 15 to 18 bytes.** Decoding uses `optU8(1)`, `optU8(18)` and `optU8(9)` on the watch, and `u8() ?? …` on the Mac. The protocol version stays the same, following the precedent set when chargerSignal and beepSound were added. The payload is already split across frames, so the 20-byte frame limit isn't affected.

6. **Mac UI: a Toggle "Quiet hours" plus two hour Pickers ("From", "Until") in the Watch settings form, placed right after Backlight.** The pickers are disabled when the toggle is off. `AppModel.loadSettings` falls back to 1/18/9 for missing keys, and `SettingsModel.defaults` / `Weather.swift` use the `WireSettings` init defaults.

## Risks / Trade-offs

- [Default On changes behaviour for existing users who set Backlight on and expect it lit all night] → This is acceptable because the backlight setting is labelled "use on a charger" and the user asked for these defaults. The toggle switches it off.
- [Sync conflicts: a 15-byte payload from an older Mac build would reset quiet hours to the defaults on the watch] → This only happens while one side is out of date. Both sides ship from this repo, so update the Mac app and the watch together.
- [`backlight(false)` might throw on some devices] → The existing `setBacklight` try/catch already handles that.
