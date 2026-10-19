## ADDED Requirements

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
