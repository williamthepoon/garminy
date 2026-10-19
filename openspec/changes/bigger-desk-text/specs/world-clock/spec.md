# Spec Delta

## MODIFIED Requirements

### Requirement: City times
The World clock card SHALL list each configured city with its current local time, in the device's 12/24-hour format. Each city SHALL be shown by a fixed three-letter code, such as SFO for San Francisco, MTL for Montreal or SIN for Singapore. The settings SHALL keep using full city names. The card SHALL also show the day offset when that city's date differs from the device's date.

#### Scenario: Three cities
- **WHEN** San Francisco, Singapore and Montreal are configured (the defaults)
- **THEN** the card lists SFO, SIN and MTL with their current times

#### Scenario: Different date
- **WHEN** it is 23:00 on Monday on the device and Singapore is already on Tuesday
- **THEN** Singapore's entry shows a "+1" day marker

#### Scenario: Unique codes
- **WHEN** every bundled city's code is compared
- **THEN** each code is exactly three letters and no two cities share a code
