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
The Motivational quote card SHALL show one motivational quote and its attribution from the bundled set, selected per local calendar day like the Fortune card. Bundled quotes MUST be public domain or original text.

#### Scenario: Quote with attribution
- **WHEN** the Motivational quote card is shown
- **THEN** the quote text and its author or source line are both visible

### Requirement: On this day
The On-this-day card SHALL show one bundled historical fact for the current month and day, including the year it happened. Every calendar date, including 29 February, SHALL have an entry.

#### Scenario: Normal date
- **WHEN** the local date is 20 July
- **THEN** the card shows a fact tied to 20 July, with its year

#### Scenario: Leap day
- **WHEN** the local date is 29 February
- **THEN** the card shows a fact tied to 29 February

### Requirement: Text fits the screen
Daily content SHALL be fully readable within the visible area of a round screen, without being clipped by the bezel. Long text SHALL wrap or use a smaller font, and SHALL NOT be truncated mid-word.

#### Scenario: Longest bundled entry
- **WHEN** the longest bundled entry is shown on the smallest supported round screen
- **THEN** every word is visible inside the circular display area

### Requirement: Varied selection
Consecutive days SHALL NOT show the same fortune or quote. A full set SHALL be shown before any entry repeats.

#### Scenario: Consecutive days
- **WHEN** comparing the fortunes chosen for any two consecutive dates
- **THEN** they are different
