# Tasks

## 1. Watch settings

- [x] 1.1 Add `quietHours` (bool, true), `quietStart` (18) and `quietEnd` (9) to `resources/settings/properties.xml`. In `settings.xml`, add a toggle and two 24-entry hour lists after Backlight, with their strings in `strings.xml`. Verify that `scripts/build.sh` succeeds.
- [x] 1.2 Add the pure function `Settings.isQuiet(enabled, start, end, hour)` and `Settings.quietNow()`. Add `(:test)` cases for the default install, the overnight window at 02:30, the end hour at 09:00, a same-day window, equal hours, and Off. Verify that `scripts/test.sh` passes.

## 2. Backlight and alerts

- [x] 2.1 In `CarouselView`, add a `_quiet` edge state: send `setBacklight(false)` once when quiet hours begin or the app opens during them, whatever the Backlight setting, and skip the hold while they're active. Verify in the simulator using a temporary preview build that sets the start hour one minute ahead: the backlight hold stops at the start hour and comes back at the end hour. Don't commit the preview hook.
- [x] 2.2 Add a `quiet` parameter to `Buzz.plan` that clears the light flag, and pass `Settings.quietNow()` from `Buzz.play`. Add `(:test)` cases for "Beep and light" while quiet (beep only) and Light while not quiet. Verify that `scripts/test.sh` passes.

## 3. Wire protocol

- [x] 3.1 In `mac/Tests/vectors.md`, extend the SETTINGS table row and vector with quiet on, start and end, and add a 15-byte legacy vector that decodes to 1/18/9. Verify that the hex in the vectors matches by hand-encoding it.
- [x] 3.2 In `Proto.mc`, encode the 18-byte SETTINGS payload and decode the three bytes with `optU8` defaults. Add `quiet*` to `Settings.snapshot` and `applyRemote`. Update `tests/CompanionTests.mc` to round-trip the new vector and the 15-byte legacy vector. Verify that `scripts/test.sh` passes.
- [x] 3.3 In `Wire.swift`, add `quietHours`, `quietStart` and `quietEnd` to `WireSettings` with init defaults, and to the encode and decode code with `?? default` fallbacks. Update `WireTests.swift` for both vectors. Verify that `swift test --package-path mac` passes.

## 4. Mac companion

- [ ] 4.1 In `AppModel`, persist the three fields with defaults of 1/18/9 when keys are missing. In `SettingsView`, add the Quiet hours toggle and the From/Until hour pickers after Backlight, disabled while the toggle is off. Verify that `scripts/bundle-mac.sh` succeeds and that the Watch settings window shows the controls with 18:00 and 09:00 on a fresh install.

## 5. Integration

- [ ] 5.1 Verify live with Backlight Off: at 19:52 the light goes off within 2 s of opening garminy.
- [ ] 5.2 Verify live on the fēnix 7 after `scripts/sideload.sh`, with Backlight set to High. Set quiet hours from the Mac to start at the next hour, then confirm that the light goes off at that hour and that a charger alert with "Beep and light" beeps without lighting the screen.
- [x] 5.3 Run `openspec validate quiet-hours --strict` and verify that it passes.

## Workflow follow-up

- Archive `charger-alert-signal` before archiving this change, because both modify "Edit watch settings from the Mac".
