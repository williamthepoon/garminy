# Spec Delta

## Purpose

Keeps every card and the alert overlay readable from a desk 50–80 cm away. It sets the minimum text size, the size tiers, how text fits the round screen, and how colour is used for text.

## ADDED Requirements

### Requirement: Minimum text size
Text on carousel cards and on the full-screen alert SHALL use the device's SMALL system font size or larger. The exceptions are bundled daily content as allowed by daily-content, the "Hold BACK to exit" hint and the glance. The extra-tiny system font SHALL NOT appear on any carousel card or alert.

#### Scenario: Secondary data on cards
- **WHEN** the Weather, Daylight, Moon, World clock or Agents card is shown with data
- **THEN** high/low temperatures, sunrise and sunset times, the next full-moon date, city names, day offsets and agent state lines are each drawn at SMALL size or larger

#### Scenario: Alert overlay
- **WHEN** a full-screen alert is showing
- **THEN** its kind, source label, detail line and footer are each drawn at SMALL size or larger

#### Scenario: Exit hint
- **WHEN** the user presses BACK briefly
- **THEN** the "Hold BACK to exit" hint may use a smaller font

### Requirement: No card titles
Cards SHALL NOT draw a title line above their content. The space below the clock header SHALL be used for the card's content.

#### Scenario: Card shown
- **WHEN** any card is shown
- **THEN** no title such as "WEATHER", "MOON" or "QUOTE OF THE DAY" appears, and the card's content starts directly below the clock header

### Requirement: Text fits the round screen
Wrapped and single-line text SHALL use the largest available size at which every word fits inside the circular display at the height it is drawn. Text SHALL NOT be clipped by the bezel or cut mid-word.

#### Scenario: Long daylight line
- **WHEN** the Daylight card shows its remaining-time line at its lowest position
- **THEN** the whole line is visible inside the circle

#### Scenario: Short message
- **WHEN** a card shows a short no-data message such as "Mac offline"
- **THEN** it is drawn larger than SMALL

### Requirement: Large numerals and hero words
Each card's main value SHALL be drawn larger than ordinary text. Digit-only values SHALL use a large numeral font where they fit: world-clock times, the current temperature and the moon illumination. The Umbrella verdict and the alert kind word SHALL be drawn larger than the LARGE system font.

#### Scenario: Umbrella verdict
- **WHEN** the Umbrella? card shows YES
- **THEN** "YES" is drawn taller than the LARGE system font

#### Scenario: World clock with 12-hour time
- **WHEN** the device uses 12-hour time and a city time with its am/pm suffix does not fit beside the city name in the large numeral font
- **THEN** that card's times use the largest smaller font at which every row fits, and no city name or time is clipped

### Requirement: Data in full contrast
Values and words the user reads from the desk SHALL be drawn in white or in a saturated state colour, not in grey. Grey SHALL be used only for dividers, outlines and secondary hints.

#### Scenario: Sunrise and sunset times
- **WHEN** the Daylight card shows sunrise and sunset
- **THEN** both times are drawn in white

#### Scenario: Alert footer while connected
- **WHEN** a full-screen alert shows its footer with the Mac connected
- **THEN** the footer is not drawn in dark grey
