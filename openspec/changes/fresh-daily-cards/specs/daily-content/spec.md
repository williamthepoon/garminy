## MODIFIED Requirements

### Requirement: On this day
The On-this-day card SHALL show a historical event for the current month and day, with its year above the event. When the Mac has sent events for today's date, the card SHALL show the next of them each time it is shown. Otherwise it SHALL show the bundled fact for the date. Every calendar date, including 29 February, SHALL have a bundled entry.

#### Scenario: Normal date
- **WHEN** the local date is 20 July
- **THEN** the card shows an event tied to 20 July, with its year above the event

#### Scenario: Leap day
- **WHEN** the local date is 29 February
- **THEN** the card shows an event tied to 29 February

#### Scenario: Mac events for today
- **WHEN** the Mac has sent 12 events for today and the card comes round twice
- **THEN** it shows two different events, each with its year

#### Scenario: Mac events for another date
- **WHEN** the newest Mac set is for yesterday's date
- **THEN** the card shows the bundled fact for today

### Requirement: Text fits the screen
Daily content, whether bundled or from the Mac, SHALL be fully readable within the visible area of a round screen, without being clipped by the bezel. Long text SHALL wrap to the width of the circle at each line's height and use the largest size that fits, never smaller than the TINY system font. Bundled text SHALL NOT be truncated mid-word. Mac text that cannot fit at TINY SHALL be cut at a word boundary and end with "…".

#### Scenario: Longest bundled entry
- **WHEN** the longest bundled entry is shown on the smallest supported round screen
- **THEN** every word is visible inside the circular display area, at TINY size or larger

#### Scenario: Short fortune
- **WHEN** a fortune of under 40 characters is shown
- **THEN** it is drawn larger than the SMALL system font

#### Scenario: Long Mac item
- **WHEN** a 140-byte Wikipedia fact does not fit at TINY
- **THEN** it is shown cut at a word boundary, ending in "…"

### Requirement: Varied selection
Within a set, no item SHALL repeat until every item in the set has been shown. Consecutive days SHALL NOT start with the same bundled fortune or quote, and a full bundled set SHALL be shown before any day's starting entry repeats.

#### Scenario: Consecutive days
- **WHEN** comparing the bundled fortunes chosen to start any two consecutive dates
- **THEN** they are different

#### Scenario: Cycling a set
- **WHEN** the Fortune card is shown 12 times with a 12-item set
- **THEN** each item appears exactly once

## ADDED Requirements

### Requirement: Fortunes and facts
The Fortune card SHALL show the next item from its current set each time it is shown, by rotation or UP/DOWN, wrapping after the last. The set SHALL be the latest one from the Mac when one was received within the last 36 hours, otherwise the bundled fortunes. With the bundled fortunes, the card SHALL start each day at that day's entry. Its settings name SHALL be "Fortunes & facts".

#### Scenario: Shown twice in a row
- **WHEN** the Fortune card comes round twice in the rotation
- **THEN** it shows a different item the second time

#### Scenario: New day without a Mac
- **WHEN** the local date changes on a watch that has never connected to a Mac
- **THEN** the Fortune card's next showing starts from the bundled fortune for the new date

#### Scenario: Mac set available
- **WHEN** a fortune set was received from the Mac 3 hours ago
- **THEN** the Fortune card shows items from that set, not the bundled fortunes

### Requirement: Motivational quotes
The Motivational quote card SHALL show the next quote from its current set each time it is shown, wrapping after the last. The set SHALL be the latest one from the Mac when one was received within the last 36 hours, otherwise the bundled quotes, starting each day at that day's entry. It SHALL show the quote text only, with no attribution line.

#### Scenario: Quote with attribution
- **WHEN** the Motivational quote card is shown
- **THEN** only the quote text is visible, with no author or source line

#### Scenario: Shown twice in a row
- **WHEN** the Motivational quote card comes round twice in the rotation
- **THEN** it shows a different quote the second time

### Requirement: Facts and jokes from the Mac
Once a day, and at launch or wake when the day's set is missing, the companion SHALL build a fortune set of up to 12 items. The set SHALL hold today's Wikipedia "Did you know" facts, shown as "Did you know that …?" with the source "Wikipedia", plus enough jokes from a keyless joke service to fill it. If one source fails, the set SHALL be built from the other.

#### Scenario: Normal day
- **WHEN** the Mac is online after midnight and Wikipedia lists 8 facts for today
- **THEN** the watch receives a set of 8 facts and 4 jokes

#### Scenario: Wikipedia unavailable
- **WHEN** the Wikipedia request fails
- **THEN** the set holds jokes only, and the companion retries Wikipedia within 30 minutes

#### Scenario: Both fail
- **WHEN** both sources fail
- **THEN** no new set is sent, and the watch keeps its last set until it is 36 hours old, then uses the bundled fortunes

### Requirement: Quote sources
Every quote, whether bundled on the watch or in the Mac app, MUST be public domain or original text, and each quote's source SHALL stay recorded in the repository.

#### Scenario: Adding a quote
- **WHEN** a quote is added to either pool
- **THEN** its author and work are recorded next to it in the repository

### Requirement: Quote pool on the Mac
The companion app SHALL bundle at least 1,000 quotes and send 12 of them each day. It SHALL NOT send a quote again within 30 days of sending it. Picking quotes SHALL need no network.

#### Scenario: Thirty days of quotes
- **WHEN** the companion has sent quote sets on 30 consecutive days
- **THEN** no quote appears in more than one of those sets

#### Scenario: Offline Mac
- **WHEN** the Mac has no network at midnight
- **THEN** the watch still receives the day's quote set

### Requirement: On-this-day events from the Mac
Once a day, the companion SHALL send up to 12 of Wikipedia's selected events for today's date, each with its year, trimmed to 140 bytes. A set SHALL be tied to its date, and the watch SHALL use it only on that date.

#### Scenario: Events sent
- **WHEN** the Mac is online on 20 October
- **THEN** the watch receives up to 12 events for 20 October, each with its year

### Requirement: Polite use of public services
Requests to Wikimedia and the joke service SHALL use HTTPS and a User-Agent naming garminy and its repository. The companion SHALL make at most 4 Wikimedia requests and 20 joke requests per day, and SHALL send no personal data.

#### Scenario: A day's traffic
- **WHEN** the companion runs for a full day with the network up
- **THEN** it has made no more than 4 Wikimedia requests and 20 joke requests

## REMOVED Requirements

### Requirement: One fortune per day
**Reason**: One fortune all day means it repeats about every 90 seconds at the default interval. Replaced by "Fortunes and facts", which shows the next item each showing.
**Migration**: None needed. The bundled fortunes remain as the offline fallback, and each day's starting entry is the old daily pick.

### Requirement: One motivational quote per day
**Reason**: Same repetition problem as fortunes. Replaced by "Motivational quotes", which keeps the no-attribution and public-domain rules.
**Migration**: None needed. The bundled quotes remain as the offline fallback.
