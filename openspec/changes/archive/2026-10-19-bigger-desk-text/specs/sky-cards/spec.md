# Spec Delta

## MODIFIED Requirements

### Requirement: Sun progress arc
The Daylight card SHALL draw an arc from sunrise to sunset with a sun marker at the current position. During the day it SHALL show the daylight remaining; at night it SHALL show the time until the next sunrise.

#### Scenario: Afternoon
- **WHEN** the current time is between sunrise and sunset
- **THEN** the marker sits on the arc in proportion to elapsed daylight, and the text reads "Xh Ym left"

#### Scenario: Night
- **WHEN** the current time is after sunset
- **THEN** the text reads "Sunrise in Xh Ym"
