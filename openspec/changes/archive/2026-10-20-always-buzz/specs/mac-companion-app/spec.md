## ADDED Requirements

### Requirement: Buzz on Claude alerts setting
The companion menu SHALL offer a Buzz on Claude alerts setting with the choices Always, Smart and Not at terminal. The default SHALL be Always. The choice SHALL be kept on the Mac across relaunches and SHALL NOT be sent to the watch.

#### Scenario: Default install
- **WHEN** the companion runs for the first time
- **THEN** Buzz on Claude alerts is Always

#### Scenario: Choice survives relaunch
- **WHEN** the user picks Smart and relaunches the companion
- **THEN** Buzz on Claude alerts is still Smart
