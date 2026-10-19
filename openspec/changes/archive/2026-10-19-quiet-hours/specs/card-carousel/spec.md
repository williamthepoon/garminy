## MODIFIED Requirements

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
