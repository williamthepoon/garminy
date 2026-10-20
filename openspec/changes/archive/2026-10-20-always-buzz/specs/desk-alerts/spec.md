## MODIFIED Requirements

### Requirement: Presence-aware buzzing
The Mac SHALL decide whether a new alert buzzes from the Buzz on Claude alerts setting and the user's presence. Always: buzz once when raised. Not at terminal: no buzz while the user is active (input within 2 minutes, screen unlocked) with the source's terminal frontmost, otherwise buzz once. Smart: in that same case, buzz once after 20 seconds if the alert is still pending, whether or not the user is still active, otherwise buzz right away. A late Smart buzz SHALL count as the alert's buzz for repeats. If the watch is disconnected when it comes due, the watch SHALL buzz once when it next receives the alert.

#### Scenario: Watching the terminal
- **WHEN** Buzz on Claude alerts is Always and a done alert is raised while the user is typing in the terminal running that session
- **THEN** the watch buzzes once

#### Scenario: Watching the terminal, Not at terminal
- **WHEN** Buzz on Claude alerts is Not at terminal and a done alert is raised while the user is typing in the terminal running that session
- **THEN** the alert is shown on the watch without a buzz

#### Scenario: Smart, looking at another machine
- **WHEN** Buzz on Claude alerts is Smart, a needs-you alert is raised while the session's terminal is frontmost and the user typed 30 seconds ago, and the user doesn't touch the Mac
- **THEN** the alert is shown at once and the watch buzzes for it 20 seconds later

#### Scenario: Smart, switching to the tab
- **WHEN** Buzz on Claude alerts is Smart, a done alert is raised while the session's terminal is frontmost and the user is active, and the user clicks into that session's tab within 20 seconds
- **THEN** the alert clears and the watch never buzzes for it

#### Scenario: Working in another app
- **WHEN** a done alert is raised while the user is active in a browser, whatever the setting
- **THEN** the watch buzzes once right away

#### Scenario: Away from the desk
- **WHEN** a needs-you alert is raised while the screen is locked, whatever the setting
- **THEN** the watch buzzes

#### Scenario: Smart, user idle at the Mac
- **WHEN** Buzz on Claude alerts is Smart, a done alert is raised while the session's terminal is frontmost and the user typed 1 second ago, and the user then leaves the Mac untouched for 30 seconds
- **THEN** the watch buzzes for it about 20 seconds after it was raised

#### Scenario: Smart buzz due while disconnected
- **WHEN** a Smart alert's 20 seconds pass while the watch is disconnected, and the watch reconnects later with the alert still pending
- **THEN** the watch buzzes once for it on reconnect, not twice

#### Scenario: Late buzz then away
- **WHEN** a needs-you alert buzzed late in Smart mode and the user then stays away from the Mac
- **THEN** it repeats under the needs-you repeat rule, as an alert that buzzed when raised would
