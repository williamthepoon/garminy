# Spec Delta

## MODIFIED Requirements

### Requirement: Unknown location
The Daylight card SHALL use, in order, the device's last known location, the location of Garmin weather, and the last location sent by the Mac companion. When none of these has ever been available, the card SHALL say so instead of guessing.

#### Scenario: No location fix
- **WHEN** the device has no last known location, Garmin weather has no location, and no companion location was received
- **THEN** the card reads "Location unknown - get a GPS fix or run the Mac companion"

#### Scenario: Phone-less watch with companion
- **WHEN** the watch has no GPS fix and no Garmin weather, and the Mac sent its location in Montreal
- **THEN** the card shows sunrise and sunset for Montreal
