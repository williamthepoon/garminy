## MODIFIED Requirements

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
