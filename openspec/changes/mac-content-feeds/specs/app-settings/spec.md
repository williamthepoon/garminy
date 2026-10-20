## MODIFIED Requirements

### Requirement: Card selection and order
Users SHALL be able to enable or disable each of the ten cards individually. Enabled cards SHALL appear in this fixed order: Agents, News, Fortune, Motivational quote, Umbrella?, Weather, Daylight, Moon phase, World clock, On this day. All cards SHALL be enabled by default. The Agents card SHALL appear only after a Mac companion has connected at least once. The News card SHALL appear only after headlines have been received from a Mac companion at least once.

#### Scenario: Default install
- **WHEN** the app is installed and settings have never been changed
- **THEN** all eight non-companion cards rotate in the fixed order

#### Scenario: Disable a card
- **WHEN** the user disables the Moon phase card
- **THEN** the carousel skips Moon phase and keeps the order of the other cards

#### Scenario: Companion connects for the first time
- **WHEN** a Mac companion connects for the first time and the Agents card is enabled
- **THEN** the Agents card joins the rotation as the first card

#### Scenario: Disable News
- **WHEN** headlines have been received and the user disables the News card in Garmin Connect or in the Mac's Watch settings window
- **THEN** the carousel skips the News card and the other cards keep their order

#### Scenario: Settings saved before News existed
- **WHEN** a Mac or watch whose card settings were saved before the News card existed syncs settings
- **THEN** the News card is On
