# Spec Delta

## Purpose

Shows the current time in up to three user-chosen cities, using bundled time-zone rules. It needs no network.

## ADDED Requirements

### Requirement: City times
The World clock card SHALL list each configured city with its current local time, in the device's 12/24-hour format. It SHALL also show the day offset when that city's date differs from the device's date.

#### Scenario: Three cities
- **WHEN** San Francisco, Singapore and Montreal are configured (the defaults)
- **THEN** the card lists all three with their current times

#### Scenario: Different date
- **WHEN** it is 23:00 on Monday on the device and Singapore is already on Tuesday
- **THEN** Singapore's entry shows a "+1" day marker

### Requirement: Daylight saving time
City times SHALL account for daylight saving time using each city's bundled rule. The supported rule families are EU, US/Canada, Southern Hemisphere (Australia and New Zealand), and no-DST.

#### Scenario: US summer
- **WHEN** the date is 1 July and San Francisco and Montreal are configured
- **THEN** San Francisco is shown at UTC−7 and Montreal at UTC−4

#### Scenario: No-DST city
- **WHEN** the date is either 15 January or 1 July and Singapore is configured
- **THEN** Singapore is shown at UTC+8

#### Scenario: EU winter
- **WHEN** the date is 15 January and London is configured
- **THEN** London is shown at UTC+0

### Requirement: Day/night hint
Each city entry SHALL show a sun icon between 06:00 and 18:00 city time, and a moon icon otherwise.

#### Scenario: Night in Singapore
- **WHEN** it is 02:00 in Singapore
- **THEN** Singapore's entry shows a moon icon

### Requirement: Correct UTC basis
City times SHALL be calculated from UTC, so they stay correct whatever the device's own time zone is.

#### Scenario: Device moved time zones
- **WHEN** the device's local time zone changes
- **THEN** each city still shows its correct local time
