# app-settings Specification

## Purpose
Lets each user configure garminy from the Garmin Connect app. This keeps the open-source app free of personal or hard-coded data.

## Requirements

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

### Requirement: Backlight setting
Users SHALL be able to choose a Backlight setting of Off, Low, Medium or High. The default SHALL be Off.

#### Scenario: Default install
- **WHEN** settings have never been changed
- **THEN** the Backlight setting is Off

### Requirement: Settings apply live
Changed settings SHALL take effect while the app is running, without a restart.

#### Scenario: Settings saved from phone while app is open
- **WHEN** the user saves new settings in Garmin Connect while garminy is open
- **THEN** the carousel uses the new settings within one rotation interval

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

### Requirement: On the charger setting
Users SHALL be able to choose what an alert does while the watch is charging: Nothing, Beep, Light, or Beep and light. The default SHALL be Beep.

#### Scenario: Default install
- **WHEN** settings have never been changed
- **THEN** On the charger is set to Beep

#### Scenario: Silent on the charger
- **WHEN** the user sets On the charger to Nothing
- **THEN** alerts on a charging watch are shown without sound or light

### Requirement: Beep sound setting
Users SHALL be able to choose the beep sound: Soft, Chime or Standard. The default SHALL be Soft. Soft SHALL play short, low clicks in the alert kind's buzz pattern. Chime SHALL play a short melody per kind. Standard SHALL play the watch's built-in alert, failure and success tones.

#### Scenario: Default install
- **WHEN** settings have never been changed
- **THEN** Beep sound is Soft

#### Scenario: Soft needs-you beep
- **WHEN** Beep sound is Soft and a needs-you alert beeps
- **THEN** the watch plays three short, low clicks

### Requirement: Quiet hours setting
Users SHALL be able to turn Quiet hours On or Off and choose a start hour and an end hour, each a whole hour from 00:00 to 23:00. The defaults SHALL be On, starting at 18:00 and ending at 09:00. Quiet hours SHALL run from the start hour up to, but not including, the end hour, wrapping past midnight when the start is later than the end. When the start and end hours are equal, quiet hours SHALL never be active.

#### Scenario: Default install
- **WHEN** settings have never been changed
- **THEN** Quiet hours is On, from 18:00 to 09:00

#### Scenario: Overnight window
- **WHEN** quiet hours run from 18:00 to 09:00 and the local time is 02:30
- **THEN** quiet hours are active

#### Scenario: End hour is not quiet
- **WHEN** quiet hours run from 18:00 to 09:00 and the local time is 09:00
- **THEN** quiet hours are not active

#### Scenario: Same-day window
- **WHEN** quiet hours run from 12:00 to 14:00 and the local time is 13:15
- **THEN** quiet hours are active

#### Scenario: Equal start and end
- **WHEN** the start and end hours are both 08:00
- **THEN** quiet hours are never active

#### Scenario: Turned off
- **WHEN** Quiet hours is Off and the local time is 23:00
- **THEN** quiet hours are not active
