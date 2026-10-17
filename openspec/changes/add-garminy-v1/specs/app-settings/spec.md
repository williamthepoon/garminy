# Spec Delta

## Purpose

Lets each user configure garminy from the Garmin Connect app. This keeps the open-source app free of personal or hard-coded data.

## ADDED Requirements

### Requirement: Card selection and order
Users SHALL be able to enable or disable each of the eight cards individually. Enabled cards SHALL appear in this fixed order: Fortune, Motivational quote, Umbrella?, Weather, Daylight, Moon phase, World clock, On this day. All cards SHALL be enabled by default.

#### Scenario: Default install
- **WHEN** the app is installed and settings have never been changed
- **THEN** all eight cards rotate in the fixed order

#### Scenario: Disable a card
- **WHEN** the user disables the Moon phase card
- **THEN** the carousel skips Moon phase and keeps the order of the other cards

### Requirement: Rotation interval
Users SHALL be able to choose a rotation interval of 5, 10, 20, 30 or 60 seconds. The default SHALL be 10 seconds.

#### Scenario: Change interval
- **WHEN** the user sets the interval to 30 seconds
- **THEN** each unpinned card is shown for 30 seconds before advancing

### Requirement: World clock cities
Users SHALL be able to choose up to three cities for the World clock card from a bundled list, or choose "None" for any slot. The default SHALL be San Francisco, Singapore and Montreal.

#### Scenario: Two cities chosen
- **WHEN** the user picks two cities and sets the third slot to "None"
- **THEN** the World clock card shows exactly those two cities

### Requirement: Temperature units
Users SHALL be able to choose Celsius, Fahrenheit, or "Follow device". The default SHALL be "Follow device".

#### Scenario: Fahrenheit chosen
- **WHEN** the user selects Fahrenheit
- **THEN** every temperature on every card is shown in °F

#### Scenario: Follow device
- **WHEN** "Follow device" is selected and the watch is set to metric units
- **THEN** temperatures are shown in °C

### Requirement: Settings apply live
Changed settings SHALL take effect while the app is running, without a restart.

#### Scenario: Settings saved from phone while app is open
- **WHEN** the user saves new settings in Garmin Connect while garminy is open
- **THEN** the carousel uses the new settings within one rotation interval
