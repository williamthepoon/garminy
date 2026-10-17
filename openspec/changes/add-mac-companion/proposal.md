# Proposal

## Why

The watch sits beside the Mac all day, but it only knows about weather and the sky. Its most useful job at a desk is the one a macOS notification does badly: show at a glance from across the desk what your AI agents and long commands are doing, and buzz only when something needs you. The BLE spike (2026-10-17, `spikes/ble/`) showed that a fēnix 7 can connect to a Mac acting as a BLE peripheral, receive notifications and write back. That was the main unknown, so the feature can now be built. The user has also disconnected the watch from the phone for good. Without the phone, garminy has no weather and no settings screen, so the Mac now has to supply both.

## What Changes

- **New Mac companion app** in `mac/`: a Swift menu-bar app (macOS 14+) that runs a BLE GATT peripheral the watch connects to. It runs locally, needs no account or server, and is built from source.
- **New `garminy-hook` command-line tool**, bundled with the app. Claude Code hooks and a zsh snippet use it to report events to the app over a local Unix socket. It never blocks or fails the caller.
- **Claude Code integration** shipped as a Claude Code plugin. Plugin hooks are merged with the user's own hooks, so existing hooks keep working.
- **Watch link**: garminy scans for the companion, connects, keeps the link alive, reconnects on its own, and shows "Mac offline" when the link is down.
- **Agents card**: a new card listing Claude Code sessions by project and state (working, needs you, done, error), with elapsed time.
- **Alerts with a buzz vocabulary**:
  - Events are queued by priority: needs you, then failed, then done.
  - A full-screen alert shows on the watch, and each kind has its own vibration pattern.
  - Tapping the watch acknowledges the alert, and the acknowledgement is synced back to the Mac.
- **Long-command alert**: a shell command that runs for 30 s or more (the threshold is configurable) produces a done or failed alert with its name, duration and exit status.
- **Presence-aware buzzing**: the Mac uses idle time and the screen-lock state to decide whether to buzz.
  - At the Mac and looking at the terminal: no buzz.
  - At the Mac but working elsewhere: one buzz.
  - Away: it re-buzzes until the alert is acknowledged.
- **Keep awake**: the Mac does not idle-sleep while any agent is working or a tracked command is running.
- **Weather and location from the Mac**: the companion fetches a forecast from Open-Meteo, which is free and needs no API key. It uses this Mac's location from macOS Location Services. It sends the watch current conditions, today and tomorrow, 12 hourly rain chances, and a rounded location. The Umbrella, Weather and Daylight cards use this when the watch has no Garmin weather. Phone users keep Garmin weather as their first source.
- **Settings from the Mac**: the menu-bar app can edit every garminy setting (cards, interval, cities, units, backlight) and send it to the watch, which saves and applies it. This works without a phone. Garmin Connect settings still work, and the most recent change wins.
- **Watch settings**: a new "Mac companion" setting, On by default, so that a watch without a phone can still reach the Mac. If no Mac is found, the watch slows its scanning down. The Agents card appears only after a companion has connected at least once, so people without a Mac see no difference.
- **Changed**: tapping the watch acknowledges the alert while one is showing. Otherwise, tapping pins the current card as before.

## Out of scope

- Mac system stats, Now Playing and CI/PR status (rejected by the user).
- Calendar and meetings, the on-air (camera/mic) light, Focus mirroring, breaks, the end-of-day shutdown, the household knock, and pinning to the watch. These are candidates for later changes.
- Approving Claude Code permission prompts from the watch. This needs its own change after the hook timing is verified.
- Supporting more than one Mac, encrypting or bonding the BLE link, and devices other than `fenix7`.
- Syncing the watch clock from the Mac (Connect IQ cannot set the system time; the watch keeps its own clock and GPS time).
- Weather providers other than Open-Meteo, and severe-weather alerts.
- Homebrew or notarized distribution (needs a paid Apple Developer ID), and Linux or Windows companions.
- Reading prompt text, assistant messages or command arguments. These are never sent to the watch.

## Capabilities

### New Capabilities
- `mac-link`: The BLE link between the watch and the Mac companion: discovery, connection, the 20-byte framed protocol, heartbeat, reconnection, single-request queuing, and the offline state.
- `desk-alerts`: The attention queue: alert priorities, the full-screen alert, the buzz vocabulary, acknowledgement in both directions, and presence-aware escalation.
- `agent-status`: Tracking Claude Code sessions on the Mac from hook events, and the Agents card on the watch.
- `command-alerts`: Reporting long-running shell commands, and their done/failed alerts.
- `companion-weather`: The Mac fetching forecast and location and supplying them to the watch, including refresh, staleness and the privacy of location data.
- `mac-companion-app`: The Mac menu-bar app and `garminy-hook`: install, the local socket, the Claude Code plugin, the shell snippet, keep-awake, settings and the privacy rules.

### Modified Capabilities
- `card-carousel`: "Pin current card" changes so that tapping acknowledges a showing alert instead of toggling the pin.
- `app-settings`: "Card selection and order" gains the Agents card. New requirements cover the "Mac companion" setting and settings pushed from the Mac.
- `weather-cards`: the weather cards fall back to Mac weather. "Missing weather data" changes its message and "Stale weather indicator" covers both sources. "No direct network access" still holds for the watch.
- `sky-cards`: "Unknown location" adds the Mac as a location source and changes its message.

## Impact

- **Watch code:**
  - New `source/` files for the BLE link, the protocol decoder, the alert queue and overlay, and the Agents card.
  - Changes to `CarouselView.mc` (overlay, tap routing, header status dot), `Card.mc`, `Settings.mc` and the settings resources.
  - New tests in `tests/`.
- **Manifest:** adds the `BluetoothLowEnergy` permission. Store users see this permission even if they leave the companion Off.
- **New code:**
  - `mac/`: a SwiftPM package with the app, `garminy-hook` and core libraries with `swift test`.
  - `scripts/bundle-mac.sh`.
  - The Claude Code plugin and marketplace manifest.
- **CI:** adds a macOS job for `swift build` and `swift test`.
- **Docs:** README sections on companion setup, macOS permissions (Bluetooth), and what data crosses the unencrypted BLE link.
- **Prerequisite:** archive `add-garminy-v1` before this change, because the `card-carousel` and `app-settings` deltas modify requirements that change introduces.
- **Network:** the Mac app makes an HTTPS request to Open-Meteo about every 30 minutes. The watch itself still makes no web requests.
- **Risk:** for phone users, the spike did not confirm that Garmin weather keeps working while the BLE link is up. This is verified on hardware in the first task group.
