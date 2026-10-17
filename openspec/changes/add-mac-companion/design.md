# Design

## Context

See proposal.md for the motivation. Constraints come from the BLE spike (`spikes/ble/`, 2026-10-17, fēnix 7 to MacBook on macOS 27) and the research behind it:

- The watch can only be the BLE central. Connect IQ supports at most 3 registered profiles and needs every characteristic declared up front. A value is at most **20 bytes**: the Mac reported `maximumUpdateValueLength` 20, and a 21-byte notification was silently cut to 20 rather than rejected. Only **one GATT request** can be in flight; the spike's taps failed while an UP write was waiting for its reply. The link is unencrypted.
- The spike confirmed several things:
  - Discovery by a 128-bit service UUID works.
  - Notifications every 2 s arrived with no gaps.
  - Both write types reached the Mac, and `onCharacteristicWrite` fires for write-without-response too.
  - A buzz requested by a notification vibrated the watch.
  - After the Mac app restarted, the watch reconnected by itself in 46 s.
- BLE works only in the foreground app, not in the glance (64 KB) or in background services. garminy runs in the foreground 24/7, so that's acceptable.
- The current watch code is driven by `CarouselView`'s single 1 s timer, cards implement `Card` (`id/refresh/draw`), settings live in `Settings.mc` and `Application.Properties`, and `Umbrella` and the glance read `Toybox.Weather` directly.
- The user's own `~/.claude/settings.json` already registers a `cc-status` hook on 10 events. The new hooks must sit alongside it.
- The user's watch is no longer paired with a phone, so `Toybox.Weather` returns nothing and Garmin Connect settings are unreachable.

## Goals / Non-Goals

**Goals:**
- Use one wire protocol that is small, versioned and identical on both sides, checked against shared test vectors.
- Keep the Mac in charge of state. The watch is a renderer plus an acknowledge button, so the Monkey C side stays small and easy to test.
- Leave phone users and Mac-less users unchanged: same cards, same weather source, no visible companion content.

**Non-Goals:**
- Running the companion link from the glance or a background service.
- Making the watch's alert logic smarter than the Mac's. Presence, repeats and expiry all live on the Mac.
- Sharing code between Swift and Monkey C beyond the test vectors.

## Decisions

### 1. Transport: direct BLE, the Mac as peripheral

The design follows the spike's layout:

| UUID | Use | Properties |
|---|---|---|
| `51C80001-4A93-428D-9D38-6812A7B5F0A9` | Service | |
| `51C80002-4A93-428D-9D38-6812A7B5F0A9` | Mac → watch frames | notify |
| `51C80004-4A93-428D-9D38-6812A7B5F0A9` | Watch → Mac frames | write, write without response |

The spike's characteristic UUIDs are reused, but the spike app is throwaway and incompatible. The Mac advertises the service UUID with the local name `GRMNY`, which fits the 8-byte name limit.

The watch writes without response for acknowledgements and the hello, and waits for `onCharacteristicWrite` before sending the next request.

**Alternatives considered:**
- An HTTPS server on the Mac reached through the phone with `makeWebRequest`. Rejected: the user has no phone, it needs certificates, and it only polls.
- An ANT USB stick. Rejected: extra hardware, and BLE already works.

### 2. Framing: a 3-byte header, up to 17 bytes of payload

`[type u8][msgId u8][part<<4 | total]` followed by the payload.
- A message has 1 to 15 parts, so the maximum message is 255 bytes.
- The receiver collects the parts of one `msgId`. It drops a message if a part is missing or out of order, or if a different `msgId` starts first.
- Messages are idempotent: each carries the whole value of its subject, never a diff. A dropped message is simply superseded by the next one.

**Mac → watch:**

| Type | Name | Payload |
|---|---|---|
| 0x01 | `HELLO_REPLY` | protocol version, Mac epoch time u32. Starts a snapshot. |
| 0x02 | `SESSIONS` | count, then per session: state u8, minutes in state u16, label length and UTF-8 label (≤16). Up to 4 sessions plus a hidden count. |
| 0x03 | `ALERTS` | the whole queue, most urgent first, up to 5. Per alert: id u8, kind u8, buzz u8, label (≤24), detail (≤20), so 5 alerts fit the 255-byte limit. The total count is included. |
| 0x04 | `BUZZ` | alert id. Asks the watch to buzz that alert's pattern now; used for repeats. |
| 0x05 | `WEATHER` | observed u32, current temp i8, current condition u8, today hi/lo/condition, tomorrow hi/lo/condition, hourly base u32, then 12 hourly chances u8. |
| 0x06 | `LOCATION` | lat i16 and lon i16, each ×100. |
| 0x07 | `SETTINGS` | changedAt u32, card bitmask u16, interval u8, city1–3 i8, units u8, backlight u8, companion u8. |
| 0x08 | `SNAPSHOT_END` | (empty) |
| 0x09 | `HEARTBEAT` | (empty), every 5 s |

**Watch → Mac:**

| Type | Name | Payload |
|---|---|---|
| 0x41 | `HELLO` | protocol version, which starts at 1 |
| 0x42 | `ACK` | alert id |
| 0x43 | `SETTINGS` | the same layout as 0x07. Sent after `HELLO` and on every `onSettingsChanged`. |

Sending the whole alert queue (`ALERTS`) instead of add/remove events makes "Queue follows the Mac" automatic. Reconnecting just means receiving the next `ALERTS`. A tap while offline is kept in a small pending-acknowledgement list that is flushed after `HELLO`.

Weather conditions are sent as Garmin `Weather.CONDITION_*` numbers. The Mac maps Open-Meteo's WMO codes to them, so `WeatherIcons.mc` is unchanged.

**Alternative considered:** a tiny JSON message split over frames. Rejected because it takes 3 to 4 times as many frames and parsing it in Monkey C costs memory.

### 3. Watch structure

All new files go in `source/companion/`:

- **`Proto.mc`:** a frame assembler and decoders, written as pure functions so they can be unit-tested against the test vectors.
- **`Link.mc`:** the BLE delegate and its state machine: `OFF → SCANNING → BACKOFF → PAIRING → SUBSCRIBING → CONNECTED`.
  - It has a single write queue with a 5 s timeout.
  - Its watchdog runs from `CarouselView`'s 1 s tick: 30 s of silence counts as link lost, and a 30 s timeout covers pairing and subscribing.
  - Scan back-off: scan continuously for 10 minutes, then for 10 s every 5 minutes.
  - On connect it rescans by UUID and never reuses an old `ScanResult`, because the Mac's address can change.
  - The spike bug where the watchdog compared against `lastRx = 0` is fixed by resetting the timestamps on every state change.
- **`Companion.mc`:** the model.
  - It holds the connected flag, sessions, the alert queue, the pending acknowledgements, and the Mac clock offset. The offset converts "minutes in state" so it doesn't depend on the watch clock.
  - It stores `everConnected` in `Application.Storage`.
- **`AgentsCard.mc`:** a new `Card`.
- **`CarouselView`** gains three things:
  - an alert overlay, drawn after the card;
  - a status dot in the header, next to the existing pin dot;
  - tap routing: tap acknowledges when an alert is showing and toggles the pin otherwise.

  Rotation pauses while an alert is showing.
- **`WeatherSource.mc`:** marked `(:glance)`. It reads Garmin weather and the Mac forecast saved in `Application.Storage` and picks one by the rule in the weather-cards delta. `UmbrellaCard`, `WeatherCard` and the glance go through it. `LocationSource` gains the Mac location as its last fallback.
- **Settings from the Mac:** the watch applies an incoming `SETTINGS` only if its `changedAt` is newer than the watch's stored `settingsChangedAt`. The watch sets that value to now in `onSettingsChanged`, which is triggered by Garmin Connect.
  - Applying means writing `Application.Properties` and calling `reload()`. This gives "most recent wins" in both directions, accepting that the two clocks may differ by up to a few seconds.
- **Manifest:** adds the `BluetoothLowEnergy` permission. New properties are `cardAgents` (default true) and `companion` (default true).

### 4. Mac structure

The Mac side is a SwiftPM package in `mac/`, using Swift 6 and targeting macOS 14 with no third-party dependencies.

- **`GarminyCore` (library, no UI):**
  - `Wire`: an encoder and decoder that mirror `Proto.mc`.
  - `SessionTracker`: the hook-event state machine, labels and expiry.
  - `AlertQueue`: priorities, expiry, and the resolve rules.
  - `PresencePolicy`: decides the buzz level and repeat schedule from presence and the source.
  - `WeatherMapper`: maps WMO codes to Garmin codes and rounds the location.
  - `SettingsModel`.
- **`GarminyCompanion` (app):**
  - `BLEPeripheral`: `CBPeripheralManager`. It re-advertises on wake and whenever Bluetooth powers on, and keeps App Nap off.
  - `SocketServer`: a Unix domain socket at `~/Library/Application Support/garminy/garminy.sock`, mode 0600, carrying one JSON line per event.
  - `Presence`: `CGEventSource` idle time, `com.apple.screenIsLocked/Unlocked`, `NSWorkspace` sleep/wake and the frontmost app.
  - `WeatherService`: `URLSession` calls to Open-Meteo for the forecast, using `CoreLocation` for this Mac's position.
  - `KeepAwake`: `IOPMAssertionCreateWithName(PreventUserIdleSystemSleep)`.
  - `MenuBarExtra` UI and `SMAppService` for launch at login.
- **`garminy-hook` (CLI):**
  - `garminy-hook claude` reads hook JSON from stdin, keeps `hook_event_name`, `session_id`, `cwd`, `notification_type` and `tool_name`, and adds `$TERM_PROGRAM`.
  - `garminy-hook shell start|end --cmd <first-word> --exit N --secs N`.
  - It connects with a 150 ms timeout, writes one line, and exits 0 in every case.
- **The privacy rule is enforced in two places.** The CLI drops `prompt`, `message`, `last_assistant_message` and `tool_input` before they leave the hook process. The Wire encoder only takes typed fields with length limits, never free text from hooks.

**Alternatives considered:**
- An Xcode project. Rejected for now: the `.pbxproj` churns and nothing here needs provisioning.
- The built-in Claude Code HTTP hooks. Rejected: they log an error whenever the app isn't running, and a localhost port can be reached by any local process.
- A sandboxed app. Rejected: it makes the socket and the hook install harder.

### 5. Claude Code integration as a plugin

The plugin lives in `claude-plugin/`: `.claude-plugin/plugin.json` plus `hooks/hooks.json`. A `.claude-plugin/marketplace.json` at the repo root lets users run `claude plugin marketplace add williamthepoon/garminy` and then `claude plugin install garminy`.

- Every hook is `"async": true` and runs `"$HOME/.local/bin/garminy-hook" claude`.
- Events used: `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Notification`, `Stop`, `StopFailure`.
- Claude Code merges plugin hooks with the user's own, so the existing `cc-status` hook keeps working. No settings file is edited.

**Alternative considered:** having the app merge entries into `~/.claude/settings.json` itself. Rejected: it's riskier, and the docs confirm that plugin hooks merge.

**State mapping:**

| Hook event | Session state |
|---|---|
| `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | working |
| `PermissionRequest`; `PreToolUse` for `AskUserQuestion` or `ExitPlanMode`; `Notification` with `elicitation_dialog` or `agent_needs_input` | needs you |
| `Stop` | done |
| `StopFailure` | error |
| `SessionEnd` | removed |

A needs-you alert is resolved by the next working event in the same session, and a new prompt resolves every alert for that session. The `idle_prompt` notification is ignored: it always follows a finished turn, so it would repeat the done alert as a needs-you alert.

"The source's terminal is frontmost" is approximated as: the frontmost app's bundle ID matches the session's `TERM_PROGRAM`. That covers iTerm2, Terminal, Ghostty, Warp and VS Code. It cannot tell two windows or tabs of the same terminal apart (see Risks).

### 6. Shell snippet

`garminy-hook shell-init zsh` prints a snippet the user adds with `eval "$(garminy-hook shell-init zsh)"`.

- It uses `add-zsh-hook` for `preexec`/`precmd` and `$EPOCHREALTIME`.
- It reports `start` from `preexec`, and `end` in `precmd` when the command ran for at least the threshold. Both calls run in the background (`&!`).
- It does nothing when `$CLAUDECODE` is set.
- The ignore list defaults to `vim nvim vi nano less more man ssh mosh tmux screen top htop claude` and can be set with `GARMINY_IGNORE`.
- The threshold is `GARMINY_LONG_CMD_SECS`, default 30.

The companion counts a command as running from `start` until `end`, with a 12 h cap in case `end` never arrives.

### 7. Weather from the Mac

`WeatherService` requests:

```
api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m,weather_code&hourly=precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto
```

- It refreshes every 30 minutes, 30 s after wake, and when the location changes. After a failure it retries after 5 minutes.
- Temperatures are sent in °C, and the watch converts them as it does today.
- The location comes only from CoreLocation (this Mac's position, kilometre accuracy). There is no city search: the user asked for none, and the menu-bar app's text field could not take keyboard focus reliably.
- Attribution (CC BY 4.0) goes in the README and the app's About section.

**Alternatives considered:**
- WeatherKit. Rejected: it needs a paid Apple Developer membership.
- wttr.in. Rejected: no service level and a less stable format.

### 8. Signing so permissions survive rebuilds

`scripts/bundle-mac.sh` builds the release, assembles `garminy Companion.app` with the Info.plist entries (`LSUIElement`, `NSBluetoothAlwaysUsageDescription`, `NSLocationWhenInUseUsageDescription`), and signs it.

- It signs with the identity named `garminy-local` if the keychain has one; otherwise it signs ad-hoc and prints a warning.
- `scripts/mac-signing-identity.sh` creates that self-signed code-signing certificate once.
- The app is installed to `~/Applications`, and `garminy-hook` is symlinked to `~/.local/bin`.
- The swiftc target is set explicitly to `arm64-apple-macos14.0`. The spike's default target, `minos 28.0`, would not launch on macOS 27.

## Risks / Trade-offs

- **The Agents card fits 3 rows, not 4.** Simulator screenshots showed that 4 rows with a `FONT_TINY` label and an `XTINY` state line overlap on the 260 px round display, so the card shows 3 rows and "+N more". The Mac still sends up to 4 sessions.
- **The terminal app is frontmost but showing a different session, so a buzz is suppressed when it shouldn't be.** Suppression only applies within 2 minutes of activity, and the alert is still shown on screen. Documented as a known approximation.
- **Unencrypted BLE, so nearby devices can read labels and the location.** Only folder names, states, command first words and a 2-decimal location are sent; this is documented in the README. Bonding is possible on API 5.1+ and is left for later.
- **`onConnectedStateChanged(DISCONNECTED)` isn't always delivered on some firmware.** The 30 s heartbeat watchdog doesn't depend on it.
- **Watch clock drift without a phone.** "Minutes in state" is computed on the Mac, and alert times use the Mac clock.
- **The Garmin weather coexistence check for phone users wasn't verified, because the user has no phone now.** It stays a hardware check that needs a phone briefly (task 9.6), and the link only uses its own connection slot.
- **Two writers for settings.** "Most recent wins" means one source can override a change from the other. This is acceptable for a single user, and both UIs show the current values.
- **Open-Meteo availability or terms change.** The source is isolated in `WeatherService`, the last forecast stays visible with its age, and the watch shows "Updated Nh ago".
- **Memory on the watch.** About 6 new classes plus small buffers. The device app limit is 786 KB, so this is low risk; the glance only gains `WeatherSource`.

## Migration Plan

1. Archive `add-garminy-v1` (and `add-sideload-script`) first, so `openspec/specs/` contains the requirements this change modifies.
2. Watch: the new properties have defaults, so existing installs keep their settings. Phone users see no change until a companion connects. Bump the app version for the Store build.
3. Rollback: set the Mac companion setting to Off on the watch, or quit the Mac app. The watch then behaves as v1. Uninstall the plugin with `claude plugin uninstall garminy`.

## Open Questions

- The exact vibration durations and duty cycles for the three patterns. Tune them on the watch; the spec fixes only the pulse counts.
- Whether VS Code's integrated terminal needs a separate bundle-ID mapping (`TERM_PROGRAM=vscode` maps to `com.microsoft.VSCode`). Check during implementation.
