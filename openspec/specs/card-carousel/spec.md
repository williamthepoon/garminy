# card-carousel Specification

## Purpose
Shows a rotating set of full-screen info cards on a desk-mounted watch. Users can browse, pin and exit without ever pressing the START button.

## Requirements

### Requirement: Launch from glance
The app SHALL provide a glance that shows the app name and a one-line summary. Selecting the glance by touch SHALL open the full carousel, so the app can be started without the START button.

#### Scenario: Open from glance by tap
- **WHEN** the user scrolls to the garminy glance and taps it
- **THEN** the carousel opens on the first enabled card

#### Scenario: Glance on device without a touchscreen
- **WHEN** the device has no touchscreen
- **THEN** the glance still appears and the app can be opened with the device's standard select action

### Requirement: Automatic rotation
The carousel SHALL advance to the next enabled card each time the configured rotation interval elapses, wrapping from the last card back to the first.

#### Scenario: Interval elapses
- **WHEN** a card has been shown for the configured interval and it is not pinned
- **THEN** the next enabled card is shown

#### Scenario: Wrap around
- **WHEN** the last enabled card's interval elapses
- **THEN** the first enabled card is shown

#### Scenario: Only one card enabled
- **WHEN** exactly one card is enabled
- **THEN** that card stays on screen and its content keeps refreshing

### Requirement: Manual navigation
DOWN or swipe up SHALL show the next card, and UP or swipe down SHALL show the previous card. Any manual navigation SHALL restart the rotation timer for the newly shown card.

#### Scenario: Next card by button
- **WHEN** the user presses DOWN
- **THEN** the next enabled card is shown and gets a full interval before auto-advancing

#### Scenario: Previous card by swipe
- **WHEN** the user swipes down on the touchscreen
- **THEN** the previous enabled card is shown

### Requirement: Pin current card
Tapping the screen SHALL toggle a pin on the current card, except while a companion alert is showing, when a tap SHALL acknowledge the alert instead and leave the pin unchanged. While a card is pinned, automatic rotation SHALL stop and a pin indicator SHALL be visible. Manual navigation SHALL clear the pin.

#### Scenario: Pin
- **WHEN** the user taps an unpinned card
- **THEN** a pin indicator appears and the card no longer auto-advances

#### Scenario: Unpin by tap
- **WHEN** the user taps a pinned card
- **THEN** the pin indicator disappears and rotation resumes with a full interval

#### Scenario: Navigation clears pin
- **WHEN** a card is pinned and the user presses UP or DOWN
- **THEN** the pin is cleared and rotation resumes on the newly shown card

#### Scenario: Tap while an alert is showing
- **WHEN** a companion alert is showing over an unpinned card and the user taps the screen
- **THEN** the alert is acknowledged and the card stays unpinned

### Requirement: Persistent clock
Every card SHALL show the current local time in a small header that follows the device's 12/24-hour setting. The header SHALL update at least once per minute.

#### Scenario: Minute changes
- **WHEN** the device's local minute changes while any card is shown
- **THEN** the header shows the new time within 60 seconds

### Requirement: Guarded exit
A short BACK press SHALL NOT exit the app. Instead it SHALL briefly show a "Hold BACK to exit" hint. Holding BACK for at least one second SHALL exit the app.

#### Scenario: Accidental BACK press
- **WHEN** the user presses and releases BACK in under one second
- **THEN** the app stays open and shows the exit hint for about 2 seconds

#### Scenario: Deliberate exit
- **WHEN** the user holds BACK for one second or longer
- **THEN** the app exits

### Requirement: Runs indefinitely on a desk
While open, the app SHALL keep running without a timeout and without user input. It SHALL NOT hold the backlight on unless the Backlight setting asks for it.

#### Scenario: Left unattended overnight
- **WHEN** the app has been open for 12 hours with no input while charging
- **THEN** it is still running, still rotating cards, and the clock is correct

### Requirement: Keep backlight on
While the app is open and the Backlight setting is Low, Medium or High, the app SHALL hold the display backlight on at that brightness, overriding the device's backlight timeout, except during quiet hours. When quiet hours begin, or the app opens during them, the app SHALL turn the backlight off once, whatever the Backlight setting, and SHALL NOT hold it on until they end. Outside quiet hours, when the setting is Off, the app SHALL leave the backlight to the device.

#### Scenario: Backlight on Medium
- **WHEN** the Backlight setting is Medium, quiet hours are not active, and the app has been open for 10 minutes with no input
- **THEN** the backlight is still lit at medium brightness

#### Scenario: Backlight Off
- **WHEN** the Backlight setting is Off and quiet hours are not active
- **THEN** the backlight turns off after the device's normal timeout

#### Scenario: Turned off while lit
- **WHEN** the user changes the Backlight setting from High to Off while the app is open
- **THEN** the backlight turns off within one rotation interval

#### Scenario: Quiet hours begin
- **WHEN** the Backlight setting is High, quiet hours run from 18:00 to 09:00, and the local time reaches 18:00 with the app open
- **THEN** the backlight turns off within 2 seconds and stays off

#### Scenario: Quiet hours end
- **WHEN** the Backlight setting is High, quiet hours run from 18:00 to 09:00, and the local time reaches 09:00 with the app open
- **THEN** the backlight comes on at high brightness within 2 seconds and stays on

#### Scenario: Touched during quiet hours
- **WHEN** quiet hours are active and the user touches the screen
- **THEN** the backlight follows the device's normal timeout and the app does not keep it on

#### Scenario: Opened during quiet hours
- **WHEN** the Backlight setting is High and the app is opened at 22:00 with quiet hours from 18:00 to 09:00
- **THEN** the backlight turns off within 2 seconds and the app does not hold it on

#### Scenario: Backlight Off when quiet hours begin
- **WHEN** the Backlight setting is Off, the backlight is lit, and quiet hours begin with the app open
- **THEN** the backlight turns off within 2 seconds

### Requirement: No cards enabled
When the user has disabled every card, the carousel SHALL show a message explaining how to enable cards in the Garmin Connect app.

#### Scenario: All cards disabled
- **WHEN** all cards are disabled in settings
- **THEN** the screen reads "Enable cards in Garmin Connect" and the clock header still shows
