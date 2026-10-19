# Proposal

## Why

The fēnix 7 doesn't vibrate while it's charging. Tests on 2026-10-19: the same buzz request vibrated on battery and did nothing on the charger. garminy's main use is a watch sitting on its charger, so every buzz is lost there. The watch can still beep while charging, as long as the watch's Alert Tones setting is on, and it can turn on its backlight.

## What Changes

- New setting, **On the charger**: what an alert that would buzz does while the watch is charging. Options: Nothing, Beep (default), Light, or Beep and light.
- New setting, **Beep sound**: Soft (default), Chime, or Standard. Connect IQ has no volume control, so softness comes from the tone itself:
  - **Soft:** short, low clicks in the buzz pattern (3 for needs you, 2 for failed, 1 for done).
  - **Chime:** a quiet two- or three-note melody per kind.
  - **Standard:** Garmin's built-in alert, failure and success tones (loud).
- While charging, the watch uses the On the charger signal in place of the vibration. On battery, nothing changes: it vibrates as today.
- A **Test on watch** button in the companion's Watch settings window plays the current charger signal and beep sound on the watch, so the user can hear the choice. It uses a new Mac → watch message `TEST_SIGNAL` (0x0A, kind u8).
- The signal follows the same rule as the buzz. It plays only when the Mac asks for a buzz, so presence rules still apply, and the needs-you repeat while you're away also beeps.
- The setting appears in Garmin Connect and in the companion's Watch settings window, and syncs both ways like the other settings.
- **BREAKING (link):** the SETTINGS payload grows by two bytes. A side that receives the old 13-byte payload uses the defaults for the new fields, so mixed versions keep working.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `app-settings`: adds the On the charger and Beep sound settings.
- `desk-alerts`: the buzz vocabulary gains a charging fallback.
- `mac-companion-app`: "Edit watch settings from the Mac" lists the new settings and adds Test on watch.

## Out of scope

- Turning on the watch's Alert Tones system setting. An app can't change it, so the README tells the user to.
- Volume control: Connect IQ has no tone volume API.
- User-composed melodies. Only the three fixed beep sounds are offered.
- Detecting whether the watch is on a stand or on a wrist.

## Impact

- Watch: `resources/settings/*` (property, list setting, strings), `Settings.mc` (read, `toDict` and `apply`), `Proto.mc` (SETTINGS encode and decode), `Companion.mc` (`Buzz.play` checks `System.getSystemStats().charging`).
- Mac: `WireSettings` and its `settings()` encode and decode, `SettingsModel` (load, save, adopt), `SettingsView` picker.
- `mac/Tests/vectors.md` SETTINGS vector, with tests on both sides.
