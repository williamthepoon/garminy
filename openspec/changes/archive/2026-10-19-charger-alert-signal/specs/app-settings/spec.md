## ADDED Requirements

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
