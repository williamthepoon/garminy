# Spec Delta

## MODIFIED Requirements

### Requirement: Pin current card
Tapping the screen SHALL toggle a pin on the current card, except while a companion alert is showing, when a tap SHALL acknowledge the alert instead and leave the pin unchanged. While a card is pinned, automatic rotation SHALL stop and a pin indicator SHALL be visible. Manual navigation SHALL clear the pin.

#### Scenario: Pin
- **WHEN** the user taps an unpinned card
- **THEN** a pin indicator appears and the card no longer auto-advances

#### Scenario: Unpin by tap
- **WHEN** the user taps a pinned card
- **THEN** the pin indicator disappears and rotation resumes with a full interval

#### Scenario: Navigation clears pin
- **WHEN** a card is pinned and the user presses UP or DOWN
- **THEN** the pin is cleared and rotation resumes on the newly shown card

#### Scenario: Tap while an alert is showing
- **WHEN** a companion alert is showing over an unpinned card and the user taps the screen
- **THEN** the alert is acknowledged and the card stays unpinned
