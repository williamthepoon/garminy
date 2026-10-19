# Design

## Context

- `garminy-hook claude` runs as a child of the Claude Code process, so it inherits that session's environment and controlling terminal. Today it forwards only `TERM_PROGRAM`, as `HookEvent.term`.
- Alerts carry `source` (`claude:<session>`), so the companion can map an alert id to a session. The watch sends `ACK` (0x42, alert id) on tap, or queues it in `pendingAcks` while offline and flushes the queue after `HELLO`.
- The companion is an `LSUIElement` app signed with the hardened runtime. On macOS 14+, cooperative activation means a background app can't reliably call `NSRunningApplication.activate` on another app.
- Only needs-you alerts come from Claude sessions. Shell commands raise only done and failed alerts.

## Goals / Non-Goals

**Goals:**
- One tap on the watch, and the right terminal tab is frontmost on the Mac.
- No new Accessibility or Screen Recording permission.

**Non-Goals:**
- Raising a minimised window in hosts other than iTerm2 and Terminal.
- Changes to the hook's 190 ms budget.

## Decisions

### 1. The hook captures three locators, all optional
New `HookEvent` fields:
- `app`: the `__CFBundleIdentifier` environment variable. Launch Services sets it to the GUI app that launched the shell, e.g. `com.googlecode.iterm2`, `com.apple.Terminal`, `com.microsoft.VSCode`. This works for any host app, unlike mapping `TERM_PROGRAM` (VS Code and Cursor both report `vscode`).
- `itermSession`: the UUID after the `:` in `ITERM_SESSION_ID`, which matches iTerm2's AppleScript `unique id` of a session.
- `tty`: the controlling terminal of the hook process, e.g. `/dev/ttys004`. It comes from `sysctl(KERN_PROC_PID)` `e_tdev` and `devname`, without spawning `ps`. Terminal's AppleScript exposes `tty` per tab.

`SessionTracker.Session` stores them, using the latest non-nil value. They are never added to any `Wire` type, which is how the privacy requirement is met.

*Alternative:* resolve the terminal on the Mac when the tap arrives, by walking from the Claude PID. Hooks don't give the Claude PID, and walking process trees from the companion is fragile.

### 2. A new `OPEN` message, not a flag on `ACK`
The watch sends `OPEN` (0x44, payload: alert id u8) instead of `ACK` when the tapped alert is needs-you and the link is up. Offline taps keep queuing `ACK`. The companion treats `OPEN` as acknowledge plus open, so it looks up the alert's source *before* removing it.
- This keeps the "only a live tap opens" rule a property of the protocol. No Mac-side timing heuristic is needed to tell flushed acks from live ones.
- `ACK`'s payload and vectors stay unchanged.

*Alternative:* bump `protocolVersion` so a mismatched pair shows "Update garminy". This is rejected because both sides ship from this repo and are installed together, and a version bump would hide all companion content during a half-updated state. The risk of an older companion ignoring `OPEN` is noted in the proposal.

### 3. `SessionOpener` in `GarminyCompanion`
It takes a session's `(app, itermSession, tty)`:
1. If `app` is nil or not running (`NSRunningApplication.runningApplications(withBundleIdentifier:)`), log and return.
2. iTerm2 with `itermSession`: run AppleScript that iterates `windows → tabs → sessions`, and on `unique id` match does `select` on the window, tab and session, then `activate`.
3. Terminal with `tty`: iterate `windows → tabs`, and on `tty` match set `selected of tab` to true, set the window's `index` to 1, then `activate`.
4. Otherwise, or when step 2 or 3 found nothing or failed: `NSWorkspace.shared.openApplication(at:configuration:)` with `activates = true`. Launch Services activation works from a background app, where `activate()` may not.

AppleScript runs through `NSAppleScript` on a background serial queue, so a slow or blocked Automation prompt never stalls BLE handling. Error `-1743` (not authorised) is logged as "Automation permission needed for <app>", and the code falls through to step 4. Ids are passed into the script as validated strings: the UUID must match `[0-9A-F-]+` and the tty must match `/dev/ttys[0-9]+`, so nothing from the hook can inject script.

*Alternatives:*
- `osascript` subprocess: slower, and attributes permission to `osascript`.
- The Accessibility API to raise windows: needs Accessibility, which the spec forbids.

### 4. Signing
`scripts/bundle-mac.sh` adds the `com.apple.security.automation.apple-events` entitlement and the `NSAppleEventsUsageDescription` key ("garminy brings the Claude Code session you tapped on your watch to the front."). Without the entitlement, the hardened runtime fails Apple Events silently, the same failure seen with Location.

### 5. Openable flag and watch UI
The ALERTS buzz byte becomes a flags byte: bit 0 buzz, bit 1 openable. The Mac sets openable for alerts whose source is a Claude session with a known `app`. Only the watch reads the byte, and both sides ship together, so no version bump is needed. The watch must now test bit 0 instead of `== 1`.

`Companion.acknowledge()` sends `Proto.open` instead of `Proto.ack` when the alert is openable and the watch is connected. The `AlertOverlay` footer picks "Tap to open" in that case. No layout change is needed: the string is shorter than "Tap to dismiss" plus the "+N · " prefix.

On the Mac, `.open` opens any alert with a Claude source (needs you or done), not only needs-you.

### 6. Clearing alerts when the user is in the session
A 2-second timer runs in `AppModel` only while at least one alert has a Claude source. Each tick:
1. Skip unless the user is active (`idleSeconds < 3`) and the screen is unlocked.
2. Find the frontmost app's bundle ID. For each alerting session whose `app` matches:
   - iTerm2 or Terminal: ask `SessionOpener` (same serial queue) for the selected session's `unique id` (iTerm2: `current session of current window`) or the selected tab's `tty` (Terminal: `selected tab of front window`). Compare it with the session's location.
   - Other apps: the app being frontmost is enough.
3. On a match, `queue.resolve(source:)` and publish.

Before scripting, `AEDeterminePermissionToAutomateTarget(..., askUserIfNeeded: false)` checks for permission. If it isn't granted, the tick does nothing for that app, so polling never raises the prompt. The prompt still comes only from a tap.

*Alternatives:*
- Clearing on the frontmost app alone for iTerm2: wrong with several sessions in one app, which is the main case.
- Accessibility window titles: forbidden by the spec.
- Waiting for the next `UserPromptSubmit`: already happens, but it misses "I looked at it and went back to other work".

## Risks / Trade-offs

- [The poll runs AppleScript every 2 s while the user works in a terminal with alerts outstanding] → It runs only while an alert exists and the user is active with the host app frontmost. Each call takes a few ms, and the first match clears the alert, which stops the poll.
- [A done alert raised while the user is already watching that tab is cleared within about 2 s] → Intended: they've seen it. It also isn't buzzed, as today.

- [Automation prompt appears on the Mac when the user tapped from across the room] → It's expected once per host app. The tab still comes forward via step 4, and the next tap works fully after the user allows it.
- [`__CFBundleIdentifier` missing, e.g. Claude launched from an SSH session or a LaunchAgent] → `app` is nil, so the tap only acknowledges, as the spec allows.
- [tmux in iTerm2: `ITERM_SESSION_ID` is inherited from the tmux server and may point to a stale tab] → The tab isn't found, so the app is still brought forward. tmux is out of scope.
- [Older companion with a newer watch: `OPEN` is ignored and the alert stays on the Mac] → It re-sends on the next publish. Install both together, and note this in the README.
- [Screen locked] → Activation happens behind the lock screen. No unlock is attempted.

## Migration Plan

Rebuild and install the companion (`scripts/bundle-mac.sh`), then sideload the watch app. Running Claude sessions pick up the new locators on their next hook event, because the hook binary is replaced in place. Rollback: reinstall the previous builds. `ACK` behaviour is unchanged.
