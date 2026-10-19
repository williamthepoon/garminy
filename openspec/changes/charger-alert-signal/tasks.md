# Tasks

## 1. Protocol and settings plumbing

- [x] 1.1 `vectors.md`: SETTINGS gains `chargerSignal` u8 and `beepSound` u8, and add the `TEST_SIGNAL` (0x0A) row and vector. Update the SETTINGS vector and table row, and add a 13-byte legacy vector that decodes with the default
- [x] 1.2 `Wire.swift`: add `WireSettings.chargerSignal` (default 1) and `beepSound` (default 0), encode them, and decode them as optional; add `MacMessage.testSignal(kind)`. Add `WireTests` for both vectors
- [x] 1.3 `Proto.mc`: encode and decode `:chargerSignal` and `:beepSound` as optional, and decode `TEST_SIGNAL`. Add `CompanionTests` for both vectors
- [x] 1.4 Watch settings: add `chargerSignal` (default 1) and `beepSound` (default 0) properties, list settings ("On the charger (needs Alert Tones on)": Nothing, Beep, Light, Beep and light; "Beep sound": Soft, Chime, Standard), and `Settings.mc` read, `toDict` and `apply`

## 2. Behaviour

- [x] 2.1 `Buzz.play`: when `System.getSystemStats().charging`, play the kind's beep in the chosen sound (Soft, Chime or Standard `ToneProfile`s) and/or turn on the backlight per the setting, instead of vibrating. `TEST_SIGNAL` calls the same path. Add a test for the choice logic with the charging state passed in
- [x] 2.2 Mac `SettingsModel` load, save and adopt, with "On the charger" and "Beep sound" pickers in `SettingsView`, plus a Test on watch button (disabled when disconnected) that sends the settings, then `TEST_SIGNAL` needs-you
- [x] 2.3 `swift test --package-path mac`, `scripts/build.sh` and `scripts/test.sh` pass

## 3. Verify

- [x] 3.1 Simulator: the Garmin Connect settings preview shows the new list, and the default reads Beep
- [ ] 3.2 Live, charging: use Test on watch for each beep sound and signal. Beep gives the chosen sound, Light lights the screen, and Nothing stays silent. Tune the Soft and Chime values with the user until Soft is acceptably quiet (partly done on 2026-10-19: Soft played 3 quiet clicks on the charger; Chime, Standard, Light and Nothing are not yet tried)
- [ ] 3.3 Live, on battery: it still vibrates and doesn't beep (not yet tried live; the plan() unit test covers it)
- [x] 3.4 README: add On the charger to the settings section, plus the Alert Tones note
