# open-agent-session Specification

## Purpose
Lets a tap on a Claude alert on the watch bring the matching terminal tab to the front on the Mac, and clears alerts once the user is active in that session.

## Requirements

### Requirement: Record where each session runs
For each Claude Code session, the companion SHALL record the app hosting the session, the iTerm2 session ID when there is one, and the session's controlling terminal device when there is one. It SHALL update them from the latest event that carries them. These values MUST stay on the Mac and MUST NOT be sent to the watch.

#### Scenario: Session in iTerm2
- **WHEN** a Claude Code session starts in an iTerm2 tab
- **THEN** the companion knows that session's host app is iTerm2 and knows its iTerm2 session ID

#### Scenario: Location stays on the Mac
- **WHEN** every frame sent to the watch during a session is captured
- **THEN** no frame contains a bundle ID, iTerm2 session ID or terminal device path

### Requirement: Open the session from the watch
When the watch asks to open an alert raised by a Claude Code session, the companion SHALL acknowledge the alert and bring that session's host app to the front. In iTerm2 it SHALL also select the window, tab and pane holding the session. In Terminal it SHALL also select the window and tab with the session's terminal device.

#### Scenario: Tap opens the iTerm2 tab
- **WHEN** session "garminy" in the second tab of an iTerm2 window needs the user, another app is frontmost, and the user taps the alert on the watch
- **THEN** iTerm2 comes to the front with that window's second tab selected, within 2 seconds

#### Scenario: Tap opens the Terminal tab
- **WHEN** a session running in a Terminal tab needs the user and the user taps its alert on the watch
- **THEN** Terminal comes to the front with that tab selected

#### Scenario: Tap a done alert
- **WHEN** a session finishes a long turn, its done alert is showing, and the user taps it on the watch
- **THEN** that session's terminal tab comes to the front, as for a needs-you alert

#### Scenario: Other host app
- **WHEN** a session running in VS Code's integrated terminal needs the user and the user taps its alert
- **THEN** VS Code comes to the front

### Requirement: Open falls back gracefully
If the session's tab cannot be found or cannot be selected, the companion SHALL still bring the host app to the front. If the host app is unknown or no longer running, it SHALL only acknowledge the alert.

#### Scenario: Tab closed
- **WHEN** the iTerm2 tab of a waiting session was closed and the user taps its alert
- **THEN** iTerm2 comes to the front and the alert is acknowledged

#### Scenario: Automation permission denied
- **WHEN** the user has denied the companion Automation access to iTerm2 and taps an alert for a session there
- **THEN** iTerm2 is still brought to the front, the alert is acknowledged, and the companion logs that permission is missing

#### Scenario: Host app not running
- **WHEN** the host app of a waiting session has quit and the user taps its alert
- **THEN** the alert is acknowledged and focus does not change

### Requirement: Only a live tap opens a session
The companion SHALL open a session only for an open request sent while the watch was connected. A tap made while disconnected SHALL only acknowledge the alert when the link returns, and SHALL NOT move focus on the Mac. Dismissing an alert from the Mac menu SHALL NOT open anything.

#### Scenario: Tap while the Mac is offline
- **WHEN** the user taps a needs-you alert while the watch is disconnected, and the link returns 10 minutes later
- **THEN** the alert is acknowledged on the Mac and no window is brought forward

#### Scenario: Dismiss from the menu
- **WHEN** the user chooses Dismiss on a needs-you alert in the menu-bar menu
- **THEN** the alert is acknowledged and focus does not change

### Requirement: Mark alerts that can be opened
Each alert sent to the watch SHALL say whether tapping it can open a session. Alerts raised by a Claude Code session whose host app is known SHALL be openable. Alerts from shell commands SHALL NOT be.

#### Scenario: Shell command finishes
- **WHEN** a long `cargo build` finishes and its done alert is shown
- **THEN** the alert is not openable, and tapping it only dismisses it

#### Scenario: Claude turn finishes
- **WHEN** a Claude Code session running in iTerm2 finishes a long turn
- **THEN** its done alert is openable

### Requirement: Clear alerts when the user is in the session
When the user is active at the Mac (any input in the last 3 seconds) and a Claude Code session with alerts is in front, the companion SHALL withdraw that session's alerts within 3 seconds. In iTerm2 and Terminal, in front means its tab is selected in the frontmost window; in other host apps, the host app is frontmost.

#### Scenario: Switch to the tab yourself
- **WHEN** a done alert for session "garminy" is on the watch, and the user clicks into that session's iTerm2 tab
- **THEN** the alert disappears from the watch within 3 seconds, without a tap

#### Scenario: Another tab in the same app
- **WHEN** a needs-you alert for session "garminy" is on the watch, and the user types in a different iTerm2 tab
- **THEN** the alert stays

#### Scenario: Away from the keyboard
- **WHEN** the session's tab is frontmost but the user has not touched the Mac for 5 minutes, and a done alert is raised
- **THEN** the alert stays until the user interacts with the Mac or taps the watch

### Requirement: Focus checks never prompt
Checking which tab is selected MUST NOT trigger a permission prompt. If Automation for that app is not granted, the companion SHALL leave that app's alerts alone.

#### Scenario: No Automation permission
- **WHEN** the user has not granted Automation for Terminal and is typing in the Terminal tab of a session with an alert
- **THEN** no permission prompt appears and the alert stays
