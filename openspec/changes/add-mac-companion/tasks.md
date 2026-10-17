# Tasks

## 1. Prerequisites and scaffolding

- [x] 1.1 Archive `add-garminy-v1` and `add-sideload-script` (after their open hardware tasks are confirmed), then verify `openspec list --specs` shows card-carousel, app-settings, weather-cards and sky-cards and `openspec validate add-mac-companion --strict` reports no "Archive would refuse" notices
- [x] 1.2 Create the SwiftPM package `mac/` (targets `GarminyCore`, `GarminyCompanion`, `garminy-hook`, `GarminyCoreTests`; macOS 14; Swift 6) and verify `swift build` and `swift test` succeed on an empty test
- [x] 1.3 Create `source/companion/`, add the `BluetoothLowEnergy` permission to `manifest.xml`, and verify `scripts/build.sh` still builds and `scripts/test.sh` still passes
- [x] 1.4 Write the shared protocol test vectors (frames for every message type in design §2, including a 3-part message) as `mac/Tests/vectors.md`, and verify every frame listed is ≤ 20 bytes

## 2. Wire protocol (mac-link)

- [x] 2.1 Implement `Wire` in `GarminyCore` (encode/decode, splitting into parts, length limits on labels) and verify Swift tests reproduce every vector in `vectors.md` byte for byte
- [x] 2.2 Implement `Proto.mc` on the watch (reassembly by msgId, drop on a missing or out-of-order part, decoders for every Mac→watch type, encoders for HELLO/ACK/SETTINGS) and verify `(:test)` functions decode the same vectors and reject an incomplete message
- [x] 2.3 Verify oversize protection: a Swift test proves the encoder never emits a frame over 20 bytes for maximum-length labels and 255-byte messages

## 3. Watch link and model (mac-link)

- [x] 3.1 Implement `Link.mc` (state machine, scan by service UUID, pair, CCCD subscribe, single write queue with 5 s timeout, 30 s silence watchdog, 30 s pairing timeout, back-off of 10 s scans every 5 min after 10 min) driven from `CarouselView`'s tick; verify unit tests of the pure state-transition and back-off timing functions
- [x] 3.2 Implement `Companion.mc` (connected flag, sessions, alert queue from `ALERTS`, pending acks flushed after HELLO, Mac clock offset, `everConnected` in Storage, version-mismatch state) and verify unit tests for snapshot replacement, offline acks and "Update garminy"
- [x] 3.3 Add the `companion` and `cardAgents` properties and settings (default On/true) with strings, and make the setting start or stop the link live; verify in the simulator App Settings editor that toggling Off stops scanning (the link state shows OFF in a debug log line)

## 4. Mac companion core (mac-companion-app)

- [x] 4.1 Implement `BLEPeripheral` (service and characteristics from design §1, advertise `GRMNY`, re-advertise on wake/power-on, 5 s heartbeat, snapshot on HELLO, App Nap off) and verify with the real watch running a debug build that HELLO→snapshot→heartbeat appears in the app log
- [x] 4.2 Implement `SocketServer` (Unix socket, 0600, JSON lines) and verify a Swift test sends events through a temp socket and the file mode is 0600; verify `lsof -nP -a -p <pid> -i` shows no network listeners
- [x] 4.3 Implement `garminy-hook` (`claude`, `shell start|end`, `shell-init zsh`; field allow-list; 150 ms connect timeout; always exit 0) and verify with a test that it exits 0 in under 200 ms with no app running and that `prompt`, `message`, `tool_input` and `last_assistant_message` never appear in its output line
- [x] 4.4 Implement `Presence` (idle seconds, lock/unlock, sleep/wake, frontmost bundle ID) and `KeepAwake` (IOPM assertion with a user toggle); verify `pmset -g assertions` shows the assertion while a fake working session exists and it is released within 1 minute after it ends
- [ ] 4.5 Implement the `MenuBarExtra` UI (connection state, sessions, pending alerts, Bluetooth-denied message with a System Settings link, Launch at login via `SMAppService`, Quit) and verify each state by running the app with Bluetooth on and with the watch out of range
- [x] 4.6 Add `scripts/bundle-mac.sh` and `scripts/mac-signing-identity.sh` (explicit `arm64-apple-macos14.0` target, Info.plist keys, `garminy-local` identity with ad-hoc fallback, install to `~/Applications`, symlink `garminy-hook` into `~/.local/bin`); verify `codesign -dr -` output is identical across two rebuilds and Bluetooth is not re-prompted
- [x] 4.7 Add a macOS CI job running `swift build` and `swift test` in `mac/`, and verify it passes on a pushed branch

## 5. Alerts (desk-alerts)

- [x] 5.1 Implement `AlertQueue` and `PresencePolicy` in `GarminyCore` (priority order, resolve rules, 2 h expiry for done/failed, buzz decision from idle/lock/frontmost terminal, needs-you repeats every 5 min up to 3 times, stop on unlock) and verify Swift tests cover every desk-alerts scenario
- [x] 5.2 Implement the watch alert overlay in `CarouselView` (kind colour and word, label, detail, "+N", clock header kept, rotation paused, "Mac offline" marker) and the three vibration patterns; verify in a temporary simulator preview build with injected alerts by screenshotting needs-you, failed, done and "+2" states, then remove the preview hook
- [x] 5.3 Route taps (acknowledge when an alert is showing, otherwise pin) and ignore swipes/UP/DOWN for alerts; verify unit tests for the routing and the card-carousel "Tap while an alert is showing" scenario in the simulator preview build
- [x] 5.4 Document the buzz patterns and acknowledgement in the README's companion section and verify the README renders the table correctly

## 6. Claude Code sessions (agent-status)

- [x] 6.1 Implement `SessionTracker` (event→state mapping from design §5, labels with numeric suffixes, 12 h expiry, alert rules including the 30 s minimum for done) and verify Swift tests cover every agent-status scenario
- [x] 6.2 Add the Claude Code plugin (`claude-plugin/.claude-plugin/plugin.json`, `claude-plugin/hooks/hooks.json`, root `.claude-plugin/marketplace.json`; all hooks async) and verify on this Mac that after installing it the existing `cc-status` hook still fires and the companion log shows SessionStart/UserPromptSubmit/Stop for a test session
- [x] 6.3 Implement `AgentsCard.mc` (up to 3 rows most urgent first, state colour/word, time in state, hidden count, "No agents running", "Mac offline", only after `everConnected`) and the header status dot; verify in a simulator preview build by screenshotting 0, 3 and 6 sessions and the offline state, then remove the preview hook
- [x] 6.4 Verify privacy end to end: capture every frame the Mac sends during a real session that edits a file and runs a command (debug log of encoded frames) and confirm none contains prompt, message, tool input or file text
- [ ] 6.5 Document plugin install and uninstall in the README and verify the documented commands work as written

## 7. Long commands (command-alerts)

- [x] 7.1 Implement the zsh snippet emitted by `garminy-hook shell-init zsh` (preexec/precmd, `$EPOCHREALTIME`, threshold `GARMINY_LONG_CMD_SECS`, `GARMINY_IGNORE` list, skip under `$CLAUDECODE`, background calls) and verify with `zsh -i` tests that `sleep 31` reports, `sleep 1` and `vim` do not, and prompt latency stays under 50 ms with the app quit
- [x] 7.2 Implement command tracking and alerts in `GarminyCore` (running set with 12 h cap, done/failed alerts with "4m · exit 1" detail, counts toward keep-awake) and verify Swift tests for every command-alerts scenario
- [x] 7.3 Add the "Set up terminal alerts" menu action (copies the eval line, shows instructions) and document it in the README; verify the copied line works in a fresh shell

## 8. Weather, location and settings from the Mac (companion-weather, weather-cards, sky-cards, app-settings)

- [x] 8.1 Implement `WeatherService` (Open-Meteo forecast, 30 min refresh, wake and location-change refresh, 5 min retry, CoreLocation) and `WeatherMapper` (WMO→Garmin conditions, 2-decimal location); verify Swift tests for the mapping, rounding and request URL, plus one live fetch for Montreal
- [x] 8.2 Use only this Mac's location (no city search): request Location access, show the status and a System Settings link when denied; verify that allowing Location triggers a fetch and that no request is made while access is denied or undecided
- [x] 8.3 Implement `WeatherSource.mc` (`(:glance)`; Garmin first when under 3 h old, else newest; Mac forecast saved in Storage) and switch `UmbrellaCard`, `WeatherCard` and the glance to it with the new missing-data message; verify unit tests for every weather-cards scenario
- [x] 8.4 Add the Mac location as the last fallback in `LocationSource` with the new unknown-location message; verify a unit test for the fallback order
- [x] 8.5 Verify the Umbrella, Weather and Daylight cards in a simulator preview build with an injected Mac forecast and location (rain, dry, stale "Updated 9h ago", no data), screenshot each, then remove the preview hook
- [x] 8.6 Implement settings in both directions (Mac `SettingsModel` and UI with every Garmin Connect option; watch applies `SETTINGS` only when `changedAt` is newer, saves to Properties, reloads; watch sends its settings after HELLO and on `onSettingsChanged`); verify unit tests for the newer-wins rule on both sides
- [x] 8.7 Update the Agents card's place in the card order (first, only after `everConnected`) and verify the app-settings scenarios in the simulator
- [x] 8.8 Document weather, location privacy, Open-Meteo attribution and Mac settings in the README and the app's About section, and verify the README renders

## 9. Hardware integration on the fēnix 7

- [ ] 9.1 Sideload with `scripts/sideload.sh`, remove `BLESPIKE.PRG` from the watch, and verify garminy connects to the bundled companion app within 30 s and the Agents card appears
- [ ] 9.2 Run a real Claude Code session and verify on the watch: working → needs you (permission prompt) alert with buzz while the Mac is locked, tap acknowledges and the Mac shows it acknowledged, answering in the terminal withdraws a pending alert within 5 s
- [ ] 9.3 Run `sleep 45; false` in a hooked shell while another app is frontmost and verify a failed alert with one buzz; repeat with the terminal frontmost and verify no buzz
- [ ] 9.4 Verify recovery: quit and reopen the app (reconnects within 60 s), sleep the Mac 10 minutes (reconnects within 60 s of wake), and turn the watch setting Off and On from the Mac app
- [ ] 9.5 Verify a phone-less watch shows Mac weather on Umbrella, Weather and Daylight, and that changing the interval in the Mac app applies on the watch
- [ ] 9.6 If a phone can be paired briefly, verify Garmin weather still refreshes and phone notifications arrive during an hour with the companion connected; otherwise record this check as not run in the README's status
- [ ] 9.7 Run overnight (8 h+) with an agent session idle and verify in the morning: garminy still running, link connected or reconnected on its own, clock header correct, Mac idle-slept normally once no work was running

## Workflow follow-up

- Run `openspec validate add-mac-companion --strict`, then `/opsx:archive` after the hardware checks pass.
- Delete `spikes/ble/` and the `.git/info/exclude` entry once the companion replaces it.
