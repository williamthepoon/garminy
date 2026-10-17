# sky-cards Specification

## Purpose
Provides the Daylight and Moon phase cards. They are computed on the watch from the time, date and last known location, so they need no network.

## Requirements

### Requirement: Daylight times
The Daylight card SHALL show today's local sunrise and sunset times for the device's last known location. Each time SHALL be accurate to within 5 minutes.

#### Scenario: Location known
- **WHEN** the device has a last known location
- **THEN** the card shows sunrise and sunset in local time, using the device's 12/24-hour format

### Requirement: Sun progress arc
The Daylight card SHALL draw an arc from sunrise to sunset with a sun marker at the current position. During the day it SHALL show the daylight remaining; at night it SHALL show the time until the next sunrise.

#### Scenario: Afternoon
- **WHEN** the current time is between sunrise and sunset
- **THEN** the marker sits on the arc in proportion to elapsed daylight, and the text reads "Xh Ym of daylight left"

#### Scenario: Night
- **WHEN** the current time is after sunset
- **THEN** the text reads "Sunrise in Xh Ym"

### Requirement: Polar day and night
The Daylight card SHALL handle locations where the sun does not rise or set on the current date.

#### Scenario: Midnight sun
- **WHEN** the sun stays above the horizon all day at the current location
- **THEN** the card reads "Sun up all day"

#### Scenario: Polar night
- **WHEN** the sun stays below the horizon all day
- **THEN** the card reads "No sunrise today"

### Requirement: Unknown location
The Daylight card SHALL use, in order, the device's last known location, the location of Garmin weather, and the last location sent by the Mac companion. When none of these has ever been available, the card SHALL say so instead of guessing.

#### Scenario: No location fix
- **WHEN** the device has no last known location, Garmin weather has no location, and no companion location was received
- **THEN** the card reads "Location unknown - get a GPS fix or run the Mac companion"

#### Scenario: Phone-less watch with companion
- **WHEN** the watch has no GPS fix and no Garmin weather, and the Mac sent its location in Montreal
- **THEN** the card shows sunrise and sunset for Montreal

### Requirement: Moon phase
The Moon phase card SHALL draw the moon's current illuminated shape for the northern-hemisphere view. It SHALL show the phase name, the illumination percentage, and the date of the next full moon. The next full moon SHALL be accurate to within one day.

#### Scenario: Known full moon
- **WHEN** the date is a known full-moon date
- **THEN** the card shows "Full Moon", an illumination of at least 98%, and a fully lit disc

#### Scenario: Waxing crescent
- **WHEN** the moon is about 3 days past new
- **THEN** a thin crescent is drawn lit on the right, and the phase name is "Waxing Crescent"
