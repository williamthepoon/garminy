## MODIFIED Requirements

### Requirement: Edit watch settings from the Mac
The app SHALL offer every garminy setting the Garmin Connect app offers: card toggles, rotation interval, world clock cities, temperature units, backlight, On the charger, Beep sound and the Mac companion toggle. It SHALL send changes to the watch when connected, or on the next connection.

#### Scenario: Change interval offline
- **WHEN** the user sets the interval to 30 seconds while the watch is disconnected
- **THEN** the watch uses 30 seconds after it next connects

#### Scenario: Choose the charger signal
- **WHEN** the user sets On the charger to "Beep and light" in the Watch settings window while the watch is connected
- **THEN** the next alert that would buzz on the charging watch beeps and turns on the backlight

## ADDED Requirements

### Requirement: Test the alert signal
The Watch settings window SHALL have a Test on watch button. While the watch is connected, it SHALL make the watch play a needs-you signal right away, using the current settings: a vibration on battery, or the On the charger signal while charging. It SHALL be disabled while the watch is disconnected.

#### Scenario: Try a beep sound
- **WHEN** the watch is charging and connected, the user picks Chime, and clicks Test on watch
- **THEN** the watch plays the needs-you chime within 2 seconds

#### Scenario: Watch disconnected
- **WHEN** the watch is not connected
- **THEN** Test on watch is disabled
