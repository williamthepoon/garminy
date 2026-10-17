# Spec Delta

## MODIFIED Requirements

### Requirement: Card selection and order
Users SHALL be able to enable or disable each of the nine cards individually. Enabled cards SHALL appear in this fixed order: Agents, Fortune, Motivational quote, Umbrella?, Weather, Daylight, Moon phase, World clock, On this day. All cards SHALL be enabled by default. The Agents card SHALL appear only after a Mac companion has connected at least once.

#### Scenario: Default install
- **WHEN** the app is installed and settings have never been changed
- **THEN** all eight non-companion cards rotate in the fixed order

#### Scenario: Disable a card
- **WHEN** the user disables the Moon phase card
- **THEN** the carousel skips Moon phase and keeps the order of the other cards

#### Scenario: Companion connects for the first time
- **WHEN** a Mac companion connects for the first time and the Agents card is enabled
- **THEN** the Agents card joins the rotation as the first card

## ADDED Requirements

### Requirement: Mac companion setting
Users SHALL be able to turn the Mac companion On or Off. The default SHALL be On. When Off, the watch SHALL NOT use Bluetooth for the companion and SHALL hide all companion content.

#### Scenario: Turned off
- **WHEN** the user turns the Mac companion Off
- **THEN** the link disconnects, the Agents card and header status dot disappear and no alerts are shown

### Requirement: Settings from the Mac
The watch SHALL accept settings sent by the Mac companion, save them as its own settings and apply them live. A setting changed later in Garmin Connect SHALL replace the Mac's value, and the reverse.

#### Scenario: Interval changed on the Mac
- **WHEN** the user sets the interval to 60 seconds in the companion app while the watch is connected
- **THEN** the watch uses 60 seconds within one rotation interval and still does after a restart

#### Scenario: Watch without a phone
- **WHEN** the watch has never been paired with a phone and the user disables the Fortune card in the companion app
- **THEN** Fortune no longer appears in the rotation
