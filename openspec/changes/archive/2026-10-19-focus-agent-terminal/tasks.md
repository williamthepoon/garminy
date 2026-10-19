# Tasks

## 1. Protocol

- [x] 1.1 Add the `OPEN` (0x44, alert id) vector and table row to `mac/Tests/vectors.md`
- [x] 1.2 `Wire.swift`: add the `watchOpen` kind, `WatchMessage.open(id)` encode and decode, and a `WireTests` vector test
- [x] 1.3 `Proto.mc`: add `OPEN` and `Proto.open(msgId, alertId)`, with a `CompanionTests.mc` vector test

## 2. Hook locators

- [x] 2.1 `HookEvent`: add optional `app`, `itermSession` and `tty`. `fromClaudeHook` takes them from the passed environment and tty, and validates the UUID and `/dev/ttys[0-9]+` formats
- [x] 2.2 `garminy-hook`: read `__CFBundleIdentifier` and `ITERM_SESSION_ID`, and get the controlling tty via `sysctl` and `devname` (no subprocess). Keep it within the 190 ms budget
- [x] 2.3 `SessionTracker`: store the locators per session (latest non-nil wins), and add a lookup from alert source to locators. Add `TrackerTests` for capture, update, and that no locator reaches `wire()`

## 3. Opening on the Mac

- [x] 3.1 `SessionOpener`: iTerm2 AppleScript select-by-unique-id, Terminal select-by-tty, and `NSWorkspace.openApplication` fallback. It runs on a background queue and logs `-1743` as missing Automation permission
- [x] 3.2 `AppModel.handle(.open(id))`: look up the alert's source and session, acknowledge, publish, then open if it is a needs-you Claude alert. `.ack` and menu Dismiss stay acknowledge-only
- [x] 3.3 `scripts/bundle-mac.sh`: add the `com.apple.security.automation.apple-events` entitlement and `NSAppleEventsUsageDescription`
- [x] 3.4 `swift test --package-path mac` passes

## 4. Watch

- [x] 4.1 `Companion.acknowledge()`: send `OPEN` for a needs-you alert while connected, otherwise `ACK` (or queue `ACK` when offline)
- [x] 4.2 `AlertOverlay`: the footer reads "Tap to open" for a connected needs-you alert, otherwise "Tap to dismiss"
- [x] 4.3 `scripts/build.sh` and `scripts/test.sh` pass
- [x] 4.4 Simulator: a preview build that injects a needs-you alert and a done alert. Screenshot both footers, then restore the sources

## 5. Live verification

- [x] 5.1 Install with `scripts/bundle-mac.sh` and `scripts/sideload.sh`
- [x] 5.2 iTerm2: with two Claude sessions in different tabs and another app frontmost, a permission prompt in the background tab plus a tap on the watch brings that tab forward. Allow the Automation prompt once
- [ ] 5.3 Terminal: the same check with a session in a Terminal tab (waived by the user on 2026-10-19)
- [ ] 5.4 A tap while the Mac is offline (Bluetooth off), then reconnecting: the alert clears and focus doesn't move (waived by the user on 2026-10-19)
- [x] 5.5 Link audit with `debugFrames`: no bundle ID, UUID or tty appears in any frame

## 6. Docs

- [x] 6.1 README and CLAUDE.md: tap to open, the Automation prompt, and that watch and companion must be updated together

## 7. Open done alerts and clear on focus

- [x] 7.1 Wire: the ALERTS buzz byte becomes flags (bit 0 buzz, bit 1 openable) in `Wire.swift`, `Proto.mc` and `vectors.md`, with a vector test on both sides
- [x] 7.2 Mac: set openable for Claude-sourced alerts with a known host app. `.open` opens any Claude alert, including done. Add tests
- [x] 7.3 Watch: `opensOnTap` uses the openable flag, and buzz tests bit 0. Update `CompanionTests`
- [x] 7.4 `SessionOpener`: a frontmost-session query (iTerm2 current session id, Terminal selected tab tty), gated by `AEDeterminePermissionToAutomateTarget` without asking
- [x] 7.5 `AppModel`: a 2 s focus poll while Claude alerts exist that resolves a session's alerts when the user is active in it. Put the matching logic in GarminyCore with tests
- [x] 7.6 Simulator: screenshot an openable done alert ("Tap to open") and a shell done alert ("Tap to dismiss")
- [x] 7.7 Live: tap a done alert to open its tab, and click into a session's tab to clear its alert from the watch
- [x] 7.8 Update the README and CLAUDE.md notes

## Workflow follow-up

- Archive with `/opsx:archive` once verified
