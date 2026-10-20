# mac-content-feeds Specification

## Purpose
Carries short text items such as headlines, quotes and facts from the Mac companion to the watch, on separate channels, so that text cards can show fresh content while keeping alerts fast and the watch usable offline.

## Requirements

### Requirement: Feed channels
The companion SHALL send text items to the watch on numbered channels. Each item SHALL carry plain text of at most 140 UTF-8 bytes, an optional source name of at most 20 bytes, and an optional time. A set SHALL hold at most 12 items. The watch SHALL ignore channels it does not know.

#### Scenario: Unknown channel
- **WHEN** the companion sends items on a channel this watch build does not use
- **THEN** the watch ignores them and its other cards and alerts keep working

#### Scenario: Older watch build
- **WHEN** a watch build without feed support connects to a companion that sends feed items
- **THEN** the watch ignores them and everything else keeps working

### Requirement: Whole sets only
The watch SHALL replace a channel's items only once every item of a new set has arrived. A set that is cut short SHALL never show. When a newer set starts before an older one completes, the older one SHALL be discarded. Duplicate items SHALL be ignored.

#### Scenario: Set cut short
- **WHEN** the link drops after 3 of 8 items in a new set have arrived
- **THEN** the watch keeps showing the previous set for that channel

#### Scenario: Newer set overtakes
- **WHEN** set B starts arriving before set A is complete
- **THEN** set A is discarded and set B shows once it is complete

### Requirement: Feeds sent on change and on connect
The companion SHALL send a channel's set after a refresh that changes it, and on every new connection after the initial state snapshot completes.

#### Scenario: Watch connects
- **WHEN** the watch connects and a news set is available
- **THEN** the watch receives the agent, alert, weather and settings snapshot first, then the news set

#### Scenario: Refresh with no change
- **WHEN** a refresh returns the same items as the last set sent
- **THEN** nothing is sent

### Requirement: Feeds never delay alerts
Feed messages SHALL be sent only while no other message is waiting to go to the watch. An alert, buzz or state change raised during a feed transfer SHALL be sent before any remaining feed items.

#### Scenario: Alert during a news transfer
- **WHEN** an agent needs the user while a news set is being sent
- **THEN** the alert reaches the watch within 2 seconds and the news set finishes afterwards

### Requirement: Saved feeds
The watch SHALL save the last complete set of each channel so it survives restarts, and SHALL keep using it while the Mac is offline. Item ages SHALL be computed in watch time from the Mac's clock offset. An item without a time SHALL have no age.

#### Scenario: App restarted while Mac is asleep
- **WHEN** garminy is reopened while the Mac is asleep and a news set was received an hour ago
- **THEN** the News card shows the saved headlines with their ages

#### Scenario: Item without a time
- **WHEN** an item arrives with no time
- **THEN** the watch shows no age for it rather than a made-up one

### Requirement: Feed text always shows
A feed card SHALL never draw an empty screen for an item that has text. When an item is too long to fit at the desk text floor, the watch SHALL cut it at a word boundary and end it with "…" so that it fits.

#### Scenario: Item too long for the screen
- **WHEN** a 140-byte item does not fit inside the round screen at SMALL
- **THEN** the card shows as many whole words as fit, ending in "…"
