# weather-cards Specification

## Purpose
Shows local weather using only the watch's built-in Garmin weather data. Users get rain and temperature information with no API keys or web requests.

## Requirements

### Requirement: Umbrella verdict
The Umbrella? card SHALL show a large verdict based on the highest hourly precipitation chance in the next 12 hours. The verdict SHALL be YES at 50% or more, MAYBE from 30% to 49%, and NO below 30%. The card SHALL also show that highest chance and the hour it occurs.

#### Scenario: Rain expected
- **WHEN** the highest hourly precipitation chance in the next 12 hours is 60%, at 15:00
- **THEN** the card shows YES and "60% at 15:00"

#### Scenario: Borderline
- **WHEN** the highest hourly chance in the next 12 hours is 35%
- **THEN** the card shows MAYBE and "35%"

#### Scenario: Dry day
- **WHEN** every hourly chance in the next 12 hours is below 30%
- **THEN** the card shows NO and the highest chance found

#### Scenario: No hourly forecast available
- **WHEN** hourly forecast data is unavailable but current conditions are available
- **THEN** the verdict uses the current conditions' precipitation chance with the same thresholds

### Requirement: Today and tomorrow forecast
The Weather card SHALL show today and tomorrow side by side. Each day SHALL show a condition icon, the high and low temperature, and a day label. Today SHALL also show the current temperature.

#### Scenario: Forecast available
- **WHEN** daily forecast data for today and tomorrow is available
- **THEN** the card shows both days with icons and high/low temperatures in the configured units

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

### Requirement: No direct network access
The weather cards MUST NOT make web requests. They SHALL use only weather data the device already provides.

#### Scenario: Network audit
- **WHEN** the app's source and manifest are inspected
- **THEN** there is no web-request usage and no Communications permission

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
