# Proposal

## Why

When a Claude Code session needs the user, the watch shows a needs-you alert with the project name. With several sessions open, the user still has to find the right terminal window and tab themselves. Tapping the alert should take them straight there.

## What Changes

- `garminy-hook` records where each Claude Code session runs: the app hosting it (`__CFBundleIdentifier`), the iTerm2 session ID (`ITERM_SESSION_ID`) and the controlling TTY. These stay on the Mac and never cross the link.
- Tapping any Claude Code alert (needs you, done or failed) on the watch while connected acknowledges it and asks the Mac to open that session. The Mac brings the session's app to the front and, for iTerm2 and Terminal, selects its window and tab.
- Alerts carry an "openable" flag, set for Claude sessions with a known host app (a spare bit in the ALERTS buzz byte). Openable alerts read "Tap to open" while connected; shell-command alerts still read "Tap to dismiss".
- When the user is active in a session's own tab (iTerm2 or Terminal) or its host app (others), the companion clears that session's alerts within 3 seconds, so working at the Mac removes the alert without touching the watch.
- New watch-to-Mac message `OPEN` (0x44, alert id). It acknowledges like `ACK` and also opens the session. Offline taps still queue a plain `ACK`, so a tap made while disconnected never moves focus later.
- The companion asks for macOS Automation permission for iTerm2 or Terminal the first time it opens a tab there. This is a new privacy prompt.
- Dismissing from the Mac menu does not open anything.

## Capabilities

### New Capabilities
- `open-agent-session`: tracking where each Claude Code session runs on the Mac, bringing it to the front when the user taps its alert on the watch, and clearing its alerts when the user is already in it.

### Modified Capabilities
- `desk-alerts`: "Acknowledge on the watch" changes. Tapping an openable alert while connected also opens the session, and the footer changes.
- `mac-companion-app`: "Presence signals" currently says the only privacy prompts are Bluetooth and Location. Automation for iTerm2 or Terminal is added, asked only on first use.

## Out of scope

- Tapping the Agents card. Tap still pins the card; opening the top waiting session from the card can come later.
- Shell-command alerts. Tapping them still only dismisses.
- Changing when done alerts are raised (still turns of 30 seconds or more).
- Selecting the exact tab in hosts other than iTerm2 and Terminal (VS Code, Cursor, Ghostty, Warp, the Claude desktop app). For those, only the app is brought forward.
- Sessions inside tmux or screen, or over SSH. The best case is bringing the host app forward.
- Answering the prompt from the watch (permission relay).
- Unlocking the Mac. If the screen is locked, the window is ready behind the lock screen.

## Impact

- Mac: `garminy-hook` (`main.swift`), `HookEvent`, `SessionTracker`, `AlertQueue` (alerts link to their session), `Wire` (decode `OPEN`), `AppModel`, a new `SessionOpener` in `GarminyCompanion`, `scripts/bundle-mac.sh` (Apple Events entitlement and `NSAppleEventsUsageDescription`).
- Watch: `Proto.mc` (`OPEN` encoder), `Companion.acknowledge`, `AlertOverlay` footer.
- `mac/Tests/vectors.md` gains an `OPEN` vector, shared by `WireTests.swift` and `tests/CompanionTests.mc`.
- The watch and Mac must be updated together. An older companion ignores `OPEN`, so the alert would not be cleared on that Mac.
