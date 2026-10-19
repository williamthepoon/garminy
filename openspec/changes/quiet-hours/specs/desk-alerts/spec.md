## ADDED Requirements

### Requirement: No alert light during quiet hours
During quiet hours, an alert SHALL NOT turn on the backlight, even when On the charger includes Light. The alert SHALL still be shown, and a beep SHALL still play when On the charger includes Beep.

#### Scenario: Beep and light at night
- **WHEN** quiet hours are active, the watch is charging, On the charger is Beep and light, and a needs-you alert arrives with a buzz request
- **THEN** the watch beeps and shows the alert, and the backlight stays off

#### Scenario: Light outside quiet hours
- **WHEN** quiet hours are not active, the watch is charging, On the charger is Light, and a done alert arrives with a buzz request
- **THEN** the backlight comes on
