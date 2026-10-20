# Tasks

## 1. Buzz policy (GarminyCore)

- [x] 1.1 Add `BuzzMode`, `BuzzDecision`, `buzzOnRaise(term:presence:mode:)`, `Alert.buzzAt` and `PresencePolicy.delayedDue(_:now:)` in `AlertQueue.swift`. In `TrackerTests.swift`, replace `buzzByPresence` with a table that checks all three modes against typing in iTerm2, a browser, the screen locked, idle 150 s and `term: nil`. Add tests that `delayedDue` fires at 20 s but not at 19 s, not once `buzzes == 1`, and that an alert raised silently in Not at terminal mode never repeats. Keep the `term: nil` and idle-150 s rows for all three modes, and add a row for a Ghostty source, which clears via `inFront`. Add tests that a late Smart buzz makes a needs-you alert eligible for `repeatDue`, that the delayed step fires while the user is idle (no input for 30 s), which `hostToCheck`'s 3 s guard would skip, and that it is skipped while a tab check for the session is in flight. Verify that `swift test --package-path mac` passes.

- [x] 1.2 In `SessionTracker`, raise a done alert on every working → done and needs-you → done transition (drop `minWorkForDone`). Update `quickTurnNoAlert` into `quickTurnAlerts`, and add a test for a turn that ends after a question. Run `swift test --package-path mac` and make sure it passes.
- [x] 1.3 Fix alerts that don't buzz after a companion restart. The watch's `_seen` keeps every id for the whole run, and the Mac reuses ids from 1 after a restart (and after 255). The watch remembers only ids still in the latest ALERTS list (`Companion.toBuzz`). The Mac clears `buzzOnShow` once an ALERTS carrying it has been sent while connected, so the flag can't buzz twice. Add a `(:test)` for a reused id, and run `swift test`, `scripts/build.sh` and `scripts/test.sh`.

## 2. Companion app

- [x] 2.1 In `AppModel`, add a `buzzMode` stored in UserDefaults (default Always). Apply the decision on raise, and send due delayed buzzes from the 2 s `focusTick`, logging `buzz <id> (mode)` for every buzz decision. The delayed step runs before `clearFocused()`, not inside it, and a buzz that comes due while disconnected is kept in `buzzOnReconnect` and sent as `BUZZ(id)` after the ALERTS in the next snapshot. Add a "Buzz on Claude alerts" Picker to the menu in `CompanionApp.swift`. Verify that `scripts/bundle-mac.sh` succeeds and that the menu shows Always on a fresh preference.
- [x] 2.2 (Always verified live on the watch 2026-10-20, including after a companion restart; Smart and Not at terminal waived by the user) Verify live, with this terminal frontmost. Always: the end of a Claude turn buzzes, or beeps on the charger. Smart: the alert buzzes about 20 s later if you leave the Mac alone, and doesn't buzz if you click into the tab. Not at terminal: no buzz. Check the companion log for each decision.
- [x] 2.3 (Waived by the user 2026-10-20) Verify the edge cases. Pick Smart, quit and relaunch the companion, and check the menu still shows Smart. In Smart mode, raise an alert with the terminal frontmost, turn the watch's companion setting off (or move it out of range) for 30 s, then reconnect: the watch buzzes once. In Smart mode, raise an alert, then don't touch the Mac: it buzzes at about 20 s.

## 3. Validation

- [x] 3.1 Run `openspec validate always-buzz --strict`
