# Spec Delta

## Purpose

Connects garminy on the watch to the Mac companion over Bluetooth LE, so the Mac can push state and alerts and the watch can send commands back, with no phone, account or server.

## ADDED Requirements

### Requirement: Discover and connect to the companion
While the Mac companion setting is On, the watch SHALL scan for a peripheral advertising the garminy companion service and SHALL connect to the first one it finds. Peripherals without that service SHALL be ignored.

#### Scenario: Companion running nearby
- **WHEN** garminy is open, the setting is On and the Mac companion is advertising within range
- **THEN** the watch connects and receives state within 30 seconds

#### Scenario: Other Bluetooth devices nearby
- **WHEN** only peripherals without the garminy service are in range
- **THEN** the watch does not connect to any of them

#### Scenario: Setting Off
- **WHEN** the Mac companion setting is Off
- **THEN** the watch does not scan or connect

### Requirement: Scan back-off when no companion is found
When no companion has been found for 10 minutes, the watch SHALL reduce scanning to one short scan at least every 5 minutes until a companion is found.

#### Scenario: User has no Mac
- **WHEN** garminy has been open for an hour with the setting On and no companion in range
- **THEN** the watch is scanning only in short bursts no more than 5 minutes apart

#### Scenario: Mac appears later
- **WHEN** the companion starts advertising while the watch is in back-off
- **THEN** the watch connects within 6 minutes

### Requirement: Liveness and reconnection
The companion SHALL send a heartbeat at least every 10 seconds while connected. When the watch receives nothing for 30 seconds, or the connection drops, it SHALL treat the link as lost, release the connection and scan again without user input.

#### Scenario: Mac app restarted
- **WHEN** the companion app quits and is reopened 15 seconds later
- **THEN** the watch reconnects within 60 seconds of the app reopening

#### Scenario: Mac sleeps and wakes
- **WHEN** the Mac sleeps for 10 minutes and then wakes
- **THEN** the watch reconnects within 60 seconds of wake

#### Scenario: Silent link
- **WHEN** the connection stays up but no frame arrives for 30 seconds
- **THEN** the watch drops the connection and starts scanning

### Requirement: Mac offline state
While the companion has connected before but the link is down, the watch SHALL show a "Mac offline" state on companion content and SHALL NOT present stale companion state as current.

#### Scenario: Link lost
- **WHEN** the link has been down for more than 30 seconds
- **THEN** the Agents card reads "Mac offline" and the header status dot is grey

#### Scenario: Never connected
- **WHEN** no companion has ever connected
- **THEN** no "Mac offline" message or status dot is shown anywhere

### Requirement: Frames fit the link limit
Every frame sent in either direction SHALL be at most 20 bytes. Messages longer than one frame SHALL be split into numbered parts that the receiver reassembles, discarding a message whose parts are incomplete or out of sequence.

#### Scenario: Long message
- **WHEN** the companion sends a 50-byte state message
- **THEN** it is sent as several frames of at most 20 bytes and the watch applies it only after all parts arrive

#### Scenario: Missing part
- **WHEN** one part of a multi-part message is lost
- **THEN** the watch discards that message and keeps the previous state

### Requirement: Protocol version handshake
On every connection the watch SHALL send a hello carrying its protocol version, and the companion SHALL reply with a full state snapshot. If the versions are incompatible, both sides SHALL stay connected but ignore content frames, and the watch SHALL show "Update garminy" on companion content.

#### Scenario: Fresh connection
- **WHEN** the watch connects
- **THEN** it receives a complete snapshot of current companion state without waiting for new events

#### Scenario: Version mismatch
- **WHEN** the companion speaks a protocol version the watch does not support
- **THEN** the Agents card reads "Update garminy" and no alerts are shown

### Requirement: One request at a time
The watch SHALL have at most one Bluetooth request in flight. Further commands SHALL be queued in order and sent when the previous one completes or times out after 5 seconds.

#### Scenario: Rapid acknowledgements
- **WHEN** the user acknowledges three alerts within one second
- **THEN** all three acknowledgements reach the Mac, in order

### Requirement: Phone features unaffected
The companion link SHALL NOT stop the watch's own phone connection from working. A watch that is paired with a phone SHALL keep receiving Garmin weather and notifications while connected to the companion.

#### Scenario: Phone-paired watch with companion
- **WHEN** the watch is connected to both the phone and the companion for an hour
- **THEN** Garmin weather data is refreshed during that hour and phone notifications still arrive
