# Proposal

## Why

The Mac doesn't buzz the watch for a new alert while the user is typing with that session's terminal in front. That assumes the user is reading the terminal, but they are often looking at another machine while the Mac's terminal stays focused. So needs-you and done alerts arrive silently and get missed. Different users want different trade-offs, so the rule should be a choice.

## What Changes

- New Mac-only setting **Buzz on Claude alerts**, in the companion's menu next to "Keep Mac awake while work runs":
  - **Always** (default): every alert buzzes once when it's raised.
  - **Smart**: if the user is active with the session's terminal in front, the buzz waits 20 seconds. If the user switches to that tab in the meantime, the alert is cleared and never buzzes. Otherwise it buzzes. In every other case it buzzes right away.
  - **Not at terminal**: today's behaviour. No buzz while the user is active with the session's terminal in front.
- **Every Claude turn raises a done alert**, however short. This replaces the 30-second minimum, so with Always the watch buzzes at the end of every turn. The user asked for this on 2026-10-20.
- When the watch is charging, a buzz still becomes the On the charger signal, and quiet hours still suppress the light.
- The repeat rule doesn't change. Only a needs-you alert that has already buzzed re-buzzes while the user is away.

## Out of scope

- Syncing the setting to the watch or Garmin Connect. The decision is made on the Mac, so the watch never needs it.
- Separate choices per alert kind, and configurable repeats.
- Muting buzzes or beeps during quiet hours.
- New presence signals or permissions, such as display sleep or KVM detection.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `desk-alerts`: Presence-aware buzzing follows the chosen mode.
- `agent-status`: Agent alerts raises a done alert for every turn, with no 30-second minimum.
- `mac-companion-app`: adds the Buzz on Claude alerts setting.

## Impact

- `mac/Sources/GarminyCore/AlertQueue.swift`: the `BuzzMode` enum, `PresencePolicy.buzzOnRaise(term:presence:mode:)`, and the delayed buzz.
- `mac/Sources/GarminyCompanion/AppModel.swift`: the stored preference, the raise path, and the due-buzz check on the 2 s tick.
- `mac/Sources/GarminyCompanion/CompanionApp.swift`: the menu picker.
- `mac/Tests/GarminyCoreTests/TrackerTests.swift`.
- The Mac companion only. No watch build, wire or Garmin Connect change.
