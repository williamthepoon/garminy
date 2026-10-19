# daily-content Specification

## Purpose
Provides the Fortune, Motivational quote and On-this-day cards. Their text is bundled with the app and chosen once per day, so they work offline for every user.

## Requirements

### Requirement: One fortune per day
The Fortune card SHALL show one fortune from the bundled set. It SHALL stay the same for the whole local calendar day and change at local midnight.

#### Scenario: Same day
- **WHEN** the Fortune card is shown several times on the same local date
- **THEN** it shows the same fortune each time

#### Scenario: New day
- **WHEN** the local date changes
- **THEN** the Fortune card shows a fortune chosen for the new date

### Requirement: One motivational quote per day
The Motivational quote card SHALL show one motivational quote from the bundled set, selected per local calendar day like the Fortune card. It SHALL show the quote text only, with no attribution line. Bundled quotes MUST be public domain or original text, and each bundled quote's source SHALL stay recorded in the repository.

#### Scenario: Quote with attribution
- **WHEN** the Motivational quote card is shown
- **THEN** only the quote text is visible, with no author or source line

### Requirement: On this day
The On-this-day card SHALL show one bundled historical fact for the current month and day, including the year it happened. The year SHALL be shown above the fact. Every calendar date, including 29 February, SHALL have an entry.

#### Scenario: Normal date
- **WHEN** the local date is 20 July
- **THEN** the card shows a fact tied to 20 July, with its year above the fact

#### Scenario: Leap day
- **WHEN** the local date is 29 February
- **THEN** the card shows a fact tied to 29 February

### Requirement: Text fits the screen
Daily content SHALL be fully readable within the visible area of a round screen, without being clipped by the bezel. Long text SHALL wrap to the width of the circle at each line's height and use the largest size that fits, never smaller than the TINY system font. It SHALL NOT be truncated mid-word.

#### Scenario: Longest bundled entry
- **WHEN** the longest bundled entry is shown on the smallest supported round screen
- **THEN** every word is visible inside the circular display area, at TINY size or larger

#### Scenario: Short fortune
- **WHEN** a fortune of under 40 characters is shown
- **THEN** it is drawn larger than the SMALL system font

### Requirement: Varied selection
Consecutive days SHALL NOT show the same fortune or quote. A full set SHALL be shown before any entry repeats.

#### Scenario: Consecutive days
- **WHEN** comparing the fortunes chosen for any two consecutive dates
- **THEN** they are different
