# mac-companion-app Specification

## Purpose
The Mac side of garminy: a local menu-bar app and the command-line helper that collect desk events, decide when to alert, supply weather and settings, and talk to the watch.

## Requirements

### Requirement: Menu-bar app
The companion SHALL run as a menu-bar app with no Dock icon on macOS 14 or later. Its menu SHALL show the watch connection state, the current agent sessions and pending alerts, and SHALL give access to settings and Quit.

#### Scenario: Watch connected
- **WHEN** the watch is connected
- **THEN** the menu shows "Watch connected" and the list of sessions

#### Scenario: Bluetooth denied
- **WHEN** the user has denied Bluetooth access
- **THEN** the menu says Bluetooth access is needed and links to the right System Settings pane

### Requirement: Launch at login
The companion SHALL offer a "Launch at login" option, off by default.

#### Scenario: Enabled
- **WHEN** the user turns on Launch at login and restarts the Mac
- **THEN** the companion is running after login

### Requirement: Local event intake
The companion SHALL accept events only through a Unix socket that only the current user can access. It SHALL NOT listen on any network port.

#### Scenario: Port audit
- **WHEN** the companion is running
- **THEN** it has no listening TCP or UDP socket

### Requirement: Hook helper never blocks
The `garminy-hook` helper SHALL read the event, send it to the socket, and exit with status 0 within 200 ms whether or not the companion is running. It SHALL print nothing on success.

#### Scenario: Companion not running
- **WHEN** a Claude Code hook calls `garminy-hook` while the companion is quit
- **THEN** it exits 0 within 200 ms and Claude Code shows no hook error

### Requirement: Claude Code plugin
The repository SHALL provide a Claude Code plugin that registers the hooks the companion needs. Installing it SHALL NOT modify or remove the user's existing hooks.

#### Scenario: Existing hooks
- **WHEN** a user who already has their own Claude Code hooks installs the plugin
- **THEN** their hooks still run and the companion also receives events

### Requirement: Shell snippet
The companion SHALL provide a zsh snippet the user can add to their shell config, plus a menu action that copies the line to add.

#### Scenario: Copy setup line
- **WHEN** the user chooses "Set up terminal alerts" in the menu
- **THEN** the line to add to `~/.zshrc` is copied to the clipboard and the instructions are shown

### Requirement: Presence signals
The companion SHALL track user input idle time, screen lock and unlock, Mac sleep and wake, and the frontmost app, for alert routing. It SHALL do this without Accessibility, Screen Recording or Full Disk Access permissions. The only privacy prompts SHALL be Bluetooth, Location, and Automation for iTerm2 or Terminal. The Automation prompt SHALL appear only the first time the user opens a session in that app from the watch.

#### Scenario: Permissions requested
- **WHEN** the companion is installed and run with all features on, and no session has been opened from the watch
- **THEN** the only privacy prompts are Bluetooth and Location

#### Scenario: First open in iTerm2
- **WHEN** the user first taps a needs-you alert for a session running in iTerm2
- **THEN** macOS asks once whether garminy Companion may control iTerm2, and never asks for Accessibility

### Requirement: Keep awake while work runs
While any agent session is working, or a long command is running, the companion SHALL prevent idle sleep. When no work is running, it SHALL release this within 1 minute. The user SHALL be able to turn this off.

#### Scenario: Agent running overnight
- **WHEN** an agent works for 2 hours with no user input
- **THEN** the Mac does not idle-sleep during that time

#### Scenario: Work finished
- **WHEN** the last working session finishes
- **THEN** the Mac's normal idle-sleep behaviour returns within 1 minute

### Requirement: Edit watch settings from the Mac
The app SHALL offer every garminy setting the Garmin Connect app offers: card toggles, rotation interval, world clock cities, temperature units, backlight, Quiet hours with its start and end hours, On the charger, Beep sound and the Mac companion toggle. It SHALL send changes to the watch when connected, or on the next connection.

#### Scenario: Change interval offline
- **WHEN** the user sets the interval to 30 seconds while the watch is disconnected
- **THEN** the watch uses 30 seconds after it next connects

#### Scenario: Choose the charger signal
- **WHEN** the user sets On the charger to "Beep and light" in the Watch settings window while the watch is connected
- **THEN** the next alert that would buzz on the charging watch beeps and turns on the backlight

#### Scenario: Change quiet hours
- **WHEN** the user sets quiet hours to 20:00–07:00 in the Watch settings window while the watch is connected
- **THEN** the watch keeps the backlight off from 20:00 to 07:00

### Requirement: Build from source
The repository SHALL contain a script that builds the companion app and `garminy-hook` from source with Apple's free developer tools, and signs them with a stable local identity so that macOS permissions survive rebuilds.

#### Scenario: Rebuild keeps permissions
- **WHEN** the user rebuilds and reinstalls the app with the script
- **THEN** macOS does not ask for Bluetooth permission again

### Requirement: Test the alert signal
The Watch settings window SHALL have a Test on watch button. While the watch is connected, it SHALL make the watch play a needs-you signal right away, using the current settings: a vibration on battery, or the On the charger signal while charging. It SHALL be disabled while the watch is disconnected.

#### Scenario: Try a beep sound
- **WHEN** the watch is charging and connected, the user picks Chime, and clicks Test on watch
- **THEN** the watch plays the needs-you chime within 2 seconds

#### Scenario: Watch disconnected
- **WHEN** the watch is not connected
- **THEN** Test on watch is disabled
