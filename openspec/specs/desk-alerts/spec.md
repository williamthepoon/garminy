# desk-alerts Specification

## Purpose
Turns events from the Mac into alerts on the watch: one queue ordered by urgency, a full-screen alert, a small vocabulary of vibration patterns, and acknowledgement that stays in sync between watch and Mac.

## Requirements

### Requirement: Alert priorities
Alerts SHALL have one of three kinds, in priority order: needs you, failed, done. The watch SHALL always show the highest-priority unacknowledged alert first, and the oldest first within the same kind.

#### Scenario: Mixed queue
- **WHEN** a done alert arrives, then a needs-you alert
- **THEN** the needs-you alert is shown first and the done alert is shown after it is acknowledged

### Requirement: Full-screen alert
While any unacknowledged alert exists, the watch SHALL show it over the current card. The alert SHALL show its kind, a source label of at most 24 characters (such as a project or command name), a detail line, and how many more alerts are waiting. Card rotation SHALL pause while an alert is showing.

#### Scenario: Claude needs input
- **WHEN** a needs-you alert for project "garminy" arrives
- **THEN** the watch shows a needs-you alert reading "garminy" over the current card, with the clock header still visible

#### Scenario: More waiting
- **WHEN** three alerts are queued
- **THEN** the alert shows "+2"

### Requirement: Buzz vocabulary
Each alert kind SHALL have its own fixed vibration pattern: done is one short pulse, failed is two sharp pulses, needs you is three pulses. The watch SHALL vibrate only when the Mac asks it to for that alert. While the watch is charging, when it cannot vibrate, it SHALL instead use the On the charger signal for that alert. The beep uses the chosen Beep sound for that kind. The light turns the backlight on.

#### Scenario: Done with buzz
- **WHEN** a done alert arrives with a buzz request and the watch is on battery
- **THEN** the watch vibrates once briefly

#### Scenario: Alert without buzz
- **WHEN** an alert arrives without a buzz request
- **THEN** the alert is shown silently, whether or not the watch is charging

#### Scenario: Needs you on the charger
- **WHEN** a needs-you alert arrives with a buzz request, the watch is charging, and On the charger is Beep
- **THEN** the watch plays the needs-you beep in the chosen Beep sound

#### Scenario: Light on the charger
- **WHEN** a done alert arrives with a buzz request, the watch is charging, and On the charger is Light
- **THEN** the backlight comes on and no tone plays

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

### Requirement: Resolve on the Mac
When the Mac learns that an alert no longer needs attention, it SHALL withdraw that alert from the watch. For example, the user replies in the Claude Code session that needed input, or a new prompt starts in that session.

#### Scenario: Answered in the terminal
- **WHEN** a needs-you alert is showing and the user answers that session in the terminal
- **THEN** the alert disappears from the watch within 5 seconds without a tap

### Requirement: Presence-aware buzzing
The Mac SHALL decide whether a new alert buzzes from the Buzz on Claude alerts setting and the user's presence. Always: buzz once when raised. Not at terminal: no buzz while the user is active (input within 2 minutes, screen unlocked) with the source's terminal frontmost, otherwise buzz once. Smart: in that same case, buzz once after 20 seconds if the alert is still pending, whether or not the user is still active, otherwise buzz right away.

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

### Requirement: Late Smart buzz
A Smart buzz sent after the 20-second wait SHALL count as the alert's buzz for repeats. If the watch is disconnected when it comes due, the watch SHALL buzz once when it next receives the alert.

#### Scenario: Smart buzz due while disconnected
- **WHEN** a Smart alert's 20 seconds pass while the watch is disconnected, and the watch reconnects later with the alert still pending
- **THEN** the watch buzzes once for it on reconnect, not twice

#### Scenario: Late buzz then away
- **WHEN** a needs-you alert buzzed late in Smart mode and the user then stays away from the Mac
- **THEN** it repeats under the needs-you repeat rule, as an alert that buzzed when raised would

### Requirement: Repeat needs-you while away
While the user is away and a needs-you alert is unacknowledged, the Mac SHALL ask the watch to buzz it again every 5 minutes, at most 3 more times.

#### Scenario: Still away
- **WHEN** a needs-you alert stays unacknowledged for 16 minutes with the screen locked
- **THEN** the watch has buzzed for it 4 times in total and then stops buzzing

#### Scenario: User returns
- **WHEN** the user unlocks the Mac while a needs-you alert is pending
- **THEN** no further repeat buzzes are sent for it

### Requirement: Alerts expire
The Mac SHALL withdraw done and failed alerts that have not been acknowledged after 2 hours. Needs-you alerts SHALL stay until acknowledged or resolved.

#### Scenario: Old done alert
- **WHEN** a done alert has been unacknowledged for 2 hours
- **THEN** it is removed from the watch

### Requirement: Queue follows the Mac
The Mac SHALL own the alert queue. On every new connection, the watch SHALL replace its queue with the Mac's snapshot. While the link is down, the watch SHALL keep showing queued alerts marked "Mac offline", and taps SHALL be sent once the link returns.

#### Scenario: Alert acknowledged on the Mac while disconnected
- **WHEN** an alert is resolved on the Mac while the link is down and the link then returns
- **THEN** the alert disappears from the watch after the snapshot arrives

#### Scenario: Tap while offline
- **WHEN** the user taps an alert while the link is down
- **THEN** the alert disappears from the watch and the Mac marks it acknowledged after the link returns

### Requirement: No alert light during quiet hours
During quiet hours, an alert SHALL NOT turn on the backlight, even when On the charger includes Light. The alert SHALL still be shown, and a beep SHALL still play when On the charger includes Beep.

#### Scenario: Beep and light at night
- **WHEN** quiet hours are active, the watch is charging, On the charger is Beep and light, and a needs-you alert arrives with a buzz request
- **THEN** the watch beeps and shows the alert, and the backlight stays off

#### Scenario: Light outside quiet hours
- **WHEN** quiet hours are not active, the watch is charging, On the charger is Light, and a done alert arrives with a buzz request
- **THEN** the backlight comes on
