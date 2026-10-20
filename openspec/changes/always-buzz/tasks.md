# Tasks

## 1. Buzz policy (GarminyCore)

- [ ] 1.1 Add `BuzzMode`, `BuzzDecision`, `buzzOnRaise(term:presence:mode:)`, `Alert.buzzAt` and `PresencePolicy.delayedDue(_:now:)` in `AlertQueue.swift`. In `TrackerTests.swift`, replace `buzzByPresence` with a table that checks all three modes against typing in iTerm2, a browser, the screen locked, idle 150 s and `term: nil`. Add tests that `delayedDue` fires at 20 s but not at 19 s, not once `buzzes == 1`, and that an alert raised silently in Not at terminal mode never repeats. Verify that `swift test --package-path mac` passes.

## 2. Companion app

- [ ] 2.1 In `AppModel`, add a `buzzMode` stored in UserDefaults (default Always). Apply the decision on raise, and send due delayed buzzes from the 2 s `focusTick`, logging `buzz <id> (mode)` for every buzz decision. Add a "Buzz on Claude alerts" Picker to the menu in `CompanionApp.swift`. Verify that `scripts/bundle-mac.sh` succeeds and that the menu shows Always on a fresh preference.
- [ ] 2.2 Verify live, with this terminal frontmost. Always: the end of a Claude turn buzzes, or beeps on the charger. Smart: the alert buzzes about 20 s later if you leave the Mac alone, and doesn't buzz if you click into the tab. Not at terminal: no buzz. Check the companion log for each decision.
