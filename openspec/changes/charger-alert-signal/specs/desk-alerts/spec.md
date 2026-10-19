## MODIFIED Requirements

### Requirement: Buzz vocabulary
Each alert kind SHALL have its own fixed vibration pattern: done is one short pulse, failed is two sharp pulses, needs you is three pulses. The watch SHALL vibrate only when the Mac asks it to for that alert. While the watch is charging, when it cannot vibrate, it SHALL instead use the On the charger signal for that alert. The beep uses the chosen Beep sound for that kind. The light turns the backlight on.

#### Scenario: Done with buzz
- **WHEN** a done alert arrives with a buzz request and the watch is on battery
- **THEN** the watch vibrates once briefly

#### Scenario: Alert without buzz
- **WHEN** an alert arrives without a buzz request
- **THEN** the alert is shown silently, whether or not the watch is charging

#### Scenario: Needs you on the charger
- **WHEN** a needs-you alert arrives with a buzz request, the watch is charging, and On the charger is Beep
- **THEN** the watch plays the needs-you beep in the chosen Beep sound

#### Scenario: Light on the charger
- **WHEN** a done alert arrives with a buzz request, the watch is charging, and On the charger is Light
- **THEN** the backlight comes on and no tone plays
