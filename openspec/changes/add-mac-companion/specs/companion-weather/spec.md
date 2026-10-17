# Spec Delta

## Purpose

Lets the Mac companion supply weather and location to the watch, so the weather and daylight cards work on a watch that is not paired with a phone.

## ADDED Requirements

### Requirement: Forecast location
The companion SHALL fetch weather for this Mac's location from macOS Location Services. There SHALL be no manual city entry. Until a location is known, it SHALL fetch no weather and SHALL say why in the app.

#### Scenario: Location allowed
- **WHEN** the user allows Location access and the Mac is in Montreal
- **THEN** the companion fetches weather for Montreal

#### Scenario: Location denied
- **WHEN** the user denies Location access
- **THEN** no weather request is made and the app says Location access is needed, with a link to the right System Settings pane

### Requirement: Keyless forecast source
The companion SHALL get weather from a public forecast service that needs no account or API key, over HTTPS. It SHALL refresh about every 30 minutes, and again soon after the Mac wakes or the location changes.

#### Scenario: Normal refresh
- **WHEN** the companion has been running for 2 hours with Location allowed and the network up
- **THEN** it has fetched a new forecast at least 3 times

#### Scenario: Network down
- **WHEN** a fetch fails
- **THEN** the companion keeps the last forecast, retries within 5 minutes and shows the failure in the app

### Requirement: Weather sent to the watch
The companion SHALL send the watch: current temperature and condition, today's and tomorrow's high, low and condition, hourly precipitation chances for the next 12 hours, and the observation time. It SHALL resend after each refresh and on every new connection.

#### Scenario: Watch connects
- **WHEN** the watch connects and a forecast is available
- **THEN** the watch receives the full forecast as part of the initial snapshot

### Requirement: Location sent to the watch
The companion SHALL send the forecast location to the watch, rounded to 2 decimal places, for sunrise and sunset calculations. It MUST NOT send a more precise location.

#### Scenario: Precise Mac location
- **WHEN** Location Services reports the Mac's position to many decimal places
- **THEN** the latitude and longitude sent to the watch have no more than 2 decimal places

### Requirement: Watch keeps the last Mac forecast
The watch SHALL save the last forecast and location it received from the Mac, so they survive restarts and are available to the glance.

#### Scenario: App restarted while Mac is asleep
- **WHEN** garminy is reopened while the Mac is asleep
- **THEN** the weather cards show the saved Mac forecast with its age
