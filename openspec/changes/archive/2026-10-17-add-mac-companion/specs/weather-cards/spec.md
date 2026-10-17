# Spec Delta

## ADDED Requirements

### Requirement: Weather source order
The weather cards SHALL use the watch's Garmin weather when it is less than 3 hours old. Otherwise they SHALL use the newest of Garmin weather and the last forecast from the Mac companion.

#### Scenario: Phone-less watch with companion
- **WHEN** the watch has no Garmin weather and the Mac sent a forecast 20 minutes ago
- **THEN** the Umbrella and Weather cards show the Mac forecast

#### Scenario: Both sources fresh
- **WHEN** Garmin weather is 1 hour old and the Mac forecast is 10 minutes old
- **THEN** the cards show Garmin weather

#### Scenario: Garmin weather stale
- **WHEN** Garmin weather is 6 hours old and the Mac forecast is 30 minutes old
- **THEN** the cards show the Mac forecast

## MODIFIED Requirements

### Requirement: Missing weather data
When the watch has no weather data, the weather cards SHALL show a clear message instead of stale or empty values.

#### Scenario: Never synced
- **WHEN** the watch has no Garmin weather and no forecast from the Mac
- **THEN** both weather cards read "No weather - pair a phone or run the Mac companion"

### Requirement: Stale weather indicator
The weather cards SHALL show how old the data is when the latest observation from the source in use is more than 3 hours old.

#### Scenario: Phone out of range all day
- **WHEN** the latest weather observation is 5 hours old
- **THEN** the cards show the data with an "Updated 5h ago" note

#### Scenario: Mac asleep overnight
- **WHEN** the only forecast is one from the Mac received 9 hours ago
- **THEN** the cards show it with an "Updated 9h ago" note
