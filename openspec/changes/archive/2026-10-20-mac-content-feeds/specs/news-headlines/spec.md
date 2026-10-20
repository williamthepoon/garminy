# Spec Delta

## Purpose

Shows current news headlines on the desk watch. The Mac companion fetches a public RSS feed and sends the top headlines on the news channel, where a News card rotates through them.

## ADDED Requirements

### Requirement: Keyless news feed on the Mac
The companion SHALL fetch the chosen RSS feed over HTTPS with no account or API key, about every 15 minutes, and again soon after the Mac wakes or the feed choice changes. It SHALL keep the first 8 items with a non-empty title, in feed order. It SHALL send nothing about the user to the feed host beyond the request itself.

#### Scenario: Normal refresh
- **WHEN** the companion has been running for an hour with the network up
- **THEN** it has fetched the feed at least 3 times

#### Scenario: Long feed
- **WHEN** the feed has 40 items
- **THEN** the companion keeps only the first 8 headlines

#### Scenario: Fetch fails
- **WHEN** a fetch fails, returns a non-200 status, is larger than 512 KB, or is not an RSS 2.0 feed (for example an Atom feed)
- **THEN** the companion keeps the last headlines, retries within 5 minutes and shows the reason in the app

### Requirement: Feed choice
The companion's Watch settings window SHALL let the user pick the news feed from Sky News Home, Sky News World and BBC News, or enter a custom HTTPS RSS URL. The default SHALL be Sky News Home. The choice SHALL stay on the Mac and SHALL NOT be sent to the watch.

#### Scenario: Default
- **WHEN** the companion is installed and the feed has never been changed
- **THEN** headlines come from Sky News Home

#### Scenario: Custom feed
- **WHEN** the user enters a custom RSS URL that serves a valid feed
- **THEN** the next headlines on the watch come from that feed

#### Scenario: Non-HTTPS URL
- **WHEN** the user enters an `http://` URL
- **THEN** the app refuses it, says HTTPS is required and keeps the previous feed

### Requirement: Headline text
Each headline SHALL be sent as plain text: markup and entities decoded, whitespace collapsed, and trimmed to at most 120 UTF-8 bytes at a character boundary, ending in "…" when cut. The source name SHALL be the preset's name, or for a custom feed the part of the feed title after its last " | " or " - ", at most 20 bytes.

#### Scenario: Entities in a title
- **WHEN** a feed title is `Smith &amp; Jones &#8216;agree&#8217; deal`
- **THEN** the watch shows `Smith & Jones ‘agree’ deal`

#### Scenario: Very long title
- **WHEN** a title is 200 bytes long
- **THEN** the watch receives at most 120 bytes ending in "…", with no broken character

#### Scenario: Custom feed source
- **WHEN** a custom feed's title is "The Latest News | Example Times"
- **THEN** the source shown is "Example Times"

### Requirement: News card
The News card SHALL show one headline at a time, wrapped to fit the round screen, with one line below it giving the source and age (for example "Sky News · 25m"). It SHALL follow desk-legibility: no title line and no text smaller than SMALL. Each time the card is shown, by rotation or by UP/DOWN, it SHALL show the next headline, wrapping after the last.

#### Scenario: Card comes round
- **WHEN** the News card showed headline 3 of 8 last time and comes round again
- **THEN** it shows headline 4

#### Scenario: Wrap
- **WHEN** the card showed the last headline last time
- **THEN** it shows the first headline next

#### Scenario: No publish time
- **WHEN** the headline has no publish time
- **THEN** the line below the headline shows only the source

### Requirement: Pinned News card
While the News card is pinned, or is the only enabled card, it SHALL move to the next headline each time the rotation interval elapses, except while an alert is showing.

#### Scenario: Pinned
- **WHEN** the user pins the News card with a 10-second interval
- **THEN** a different headline shows every 10 seconds and the carousel stays on the News card

#### Scenario: Only card
- **WHEN** News is the only card in the rotation and the interval is 20 seconds
- **THEN** a different headline shows every 20 seconds

### Requirement: Out-of-date headlines
While the Mac is offline, the News card SHALL keep showing the saved headlines with their ages. When the saved set was received more than 12 hours ago, the line below the headline SHALL read "Out of date" in the alert colour, so stale news is never presented as current.

#### Scenario: Very old headlines
- **WHEN** the saved news set was received 13 hours ago
- **THEN** the line below the headline reads "Out of date" in the alert colour

#### Scenario: Recently received
- **WHEN** the saved set was received 2 hours ago and the Mac is offline
- **THEN** the card shows the source and age as normal

### Requirement: Card appears only with headlines
The News card SHALL be in the rotation only when its toggle is on, the Mac companion setting is on, and the watch has received headlines at least once. A watch that has never received headlines SHALL show no News card and no empty News state.

#### Scenario: No Mac
- **WHEN** the watch has never connected to a Mac companion
- **THEN** no News card appears in the rotation

#### Scenario: First headlines arrive
- **WHEN** a full set of headlines arrives for the first time and the News toggle is on
- **THEN** the News card joins the rotation after the Agents card
