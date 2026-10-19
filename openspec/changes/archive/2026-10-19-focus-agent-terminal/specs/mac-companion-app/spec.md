## MODIFIED Requirements

### Requirement: Presence signals
The companion SHALL track user input idle time, screen lock and unlock, Mac sleep and wake, and the frontmost app, for alert routing. It SHALL do this without Accessibility, Screen Recording or Full Disk Access permissions. The only privacy prompts SHALL be Bluetooth, Location, and Automation for iTerm2 or Terminal. The Automation prompt SHALL appear only the first time the user opens a session in that app from the watch.

#### Scenario: Permissions requested
- **WHEN** the companion is installed and run with all features on, and no session has been opened from the watch
- **THEN** the only privacy prompts are Bluetooth and Location

#### Scenario: First open in iTerm2
- **WHEN** the user first taps a needs-you alert for a session running in iTerm2
- **THEN** macOS asks once whether garminy Companion may control iTerm2, and never asks for Accessibility
