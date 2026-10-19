## MODIFIED Requirements

### Requirement: Acknowledge on the watch
Tapping the screen while an alert is showing SHALL acknowledge that alert, remove it from the watch and tell the Mac. If the alert is openable and the watch is connected, the tap SHALL also ask the Mac to open the session that raised it. While connected, an openable alert's footer SHALL read "Tap to open", and other alerts SHALL read "Tap to dismiss". Swiping or pressing UP or DOWN SHALL NOT acknowledge it.

#### Scenario: Tap to acknowledge
- **WHEN** an alert is showing and the user taps the screen
- **THEN** the alert disappears, the next queued alert or the card is shown, and the Mac marks it acknowledged

#### Scenario: Tap an openable alert
- **WHEN** an openable alert from a Claude Code session is showing, the watch is connected, and the user taps the screen
- **THEN** the alert disappears and the Mac is asked to open the session that raised it

#### Scenario: Tap a shell command alert
- **WHEN** a done alert for a shell command is showing and the user taps the screen
- **THEN** the alert is acknowledged and the Mac is not asked to open anything

#### Scenario: Footer wording
- **WHEN** an openable alert is showing and the watch is connected
- **THEN** the footer reads "Tap to open"

#### Scenario: Swipe does not dismiss
- **WHEN** an alert is showing and the user swipes up
- **THEN** the alert stays on screen
