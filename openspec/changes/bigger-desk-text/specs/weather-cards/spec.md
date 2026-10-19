# Spec Delta

## ADDED Requirements

### Requirement: Umbrella card identity
With no card titles, the Umbrella? card SHALL draw an umbrella icon above its verdict, so the verdict reads as an answer about rain. The icon SHALL use the verdict's colour.

#### Scenario: Verdict shown
- **WHEN** the Umbrella? card shows any verdict
- **THEN** an umbrella icon appears above the verdict, in the same colour

#### Scenario: No weather
- **WHEN** the Umbrella? card has no weather data
- **THEN** the umbrella icon still appears above the no-weather message
