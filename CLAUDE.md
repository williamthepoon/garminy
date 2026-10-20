# garminy

Open-source Garmin Connect IQ app **garminy** that turns a retired watch into a 24/7 desk display. It rotates full-screen info cards. The primary test device is a Fenix 7 47mm with a broken START button, sitting on a stand and never worn. The app must work for anyone with a fēnix 7: no personal data, no API keys, no hosted backend. **Only `fenix7` is supported**, by the user's decision on 2026-10-17; don't add devices unless asked.

## Spec-driven development: OpenSpec (required)

All feature work goes through [OpenSpec](https://openspec.dev/) (CLI `@fission-ai/openspec`, v1.14.x, schema `spec-driven`). Don't write feature code without an approved change.

- `openspec/specs/<capability>/spec.md` is the source of truth for current behaviour.
- `openspec/changes/<change-name>/` holds in-flight work: `proposal.md` (why/what), `specs/` (delta specs), `design.md` (how), `tasks.md` (checklist).
- `openspec/changes/archive/` holds completed changes.
- `openspec/config.yaml` holds the project context and rules that every artifact must follow.

Workflow, using the slash commands in `.claude/commands/opsx/` and the skills in `.claude/skills/openspec-*`:
1. `/opsx:explore`: investigate before committing to a change (optional).
2. `/opsx:propose "<idea>"`: create the change and all artifacts. Planning only; stop for user review.
3. `/opsx:apply`: implement `tasks.md`, ticking tasks off as they are done. Only start after the user asks.
4. `/opsx:archive`: once the work is verified, archive the change and merge its deltas into `openspec/specs/`.

Rules:
- Every requirement needs at least one `#### Scenario:` with WHEN/THEN.
- Run `openspec validate <change> --strict` before presenting a proposal and before archiving.
- If behaviour changes during implementation, update the change's spec deltas and tasks first, then the code.
- Useful commands: `openspec list`, `openspec list --specs`, `openspec show <item>`, `openspec status --change <name>`.

## Platform constraints (verified during research)

- Connect IQ, Monkey C, Fenix 7 = API 5.2. The display is 260x260 round MIP with 64 colours, and the backlight is off by default.
- **The watch doesn't vibrate while charging** (tested 2026-10-19). `Attention.vibrate` does nothing on the charger, but `playTone` and `backlight` still work; tones need the watch's Alert Tones setting on. That's why `Buzz.play` swaps to the On the charger signal (charger-alert-signal).
- **START (KEY_ENTER) cannot be relied on.** Inputs are touch (tap/swipe), UP, DOWN, BACK. LIGHT belongs to the system.
- Ship as a device app with a glance. Users open it via the glance; widgets time out, device apps don't.
- Weather comes from `Toybox.Weather` (via the phone's Garmin Connect). Avoid `makeWebRequest` unless a spec requires it.
- Bundled content (fortunes, quotes, on-this-day) lives in resources. Keep it within device-app memory limits; the background service limit is about 64 KB.
- Layouts scale from `dc` size (see `source/Layout.mc`). The only build target is `fenix7`.

## Build and install

Toolchain (installed 2026-10-17): Homebrew `openjdk@21` and Connect IQ SDK 9.2.0 in `~/Library/Application Support/Garmin/ConnectIQ/Sdks/` (the active SDK is set in `current-sdk.cfg`). Both are on PATH via `~/.zshrc`. Device definitions (e.g. `fenix7`) come from `/Applications/SdkManager.app` and need a Garmin login. The developer key is at `~/.garmin/developer_key.der`, outside the repo.

- Build: `scripts/build.sh`. This regenerates `resources/jsonData/` from `content/*.json`, so edit content in `content/`, never in the generated files.
- Unit tests: `scripts/test.sh`. It launches the simulator if needed. Tests are `(:test)` functions in `tests/`; put helpers inside the `(:test) module T`, because top-level `(:test)` functions run as tests.

- Sideload: `scripts/sideload.sh` (macOS, needs `brew install libmtp`). It replaces `GARMIN/Apps/GARMINY.PRG` through the Swift libmtp helper in `scripts/mtp/`. macOS's `ptpcamerad` grabs the watch, so the script keeps killing it during the transfer, and the stock `mtp-sendfile` fails on this watch ("could not get storage id"). The watch installs on unplug and keeps its settings. If the watch then never reconnects (no `watch subscribed` in the companion log) and restarting the companion or the watch doesn't help, turn the Mac's Bluetooth off and on (seen 2026-10-20).
- Never commit or lose `~/.garmin/developer_key.der`. Store updates must be signed with the same key.

Mac companion (`mac/`, SwiftPM, Swift 6, macOS 14+):
- **Build and install:** `scripts/bundle-mac.sh` builds the app, signs it with the `garminy-local` identity (created once by `scripts/mac-signing-identity.sh`, already in the login keychain), installs `~/Applications/garminy Companion.app`, links `~/.local/bin/garminy-hook`, and relaunches it.
- **Tests:** `swift test --package-path mac`. The log is `~/Library/Logs/garminy-companion.log`. `defaults write com.github.williamthepoon.garminy.companion debugFrames -bool true` logs every BLE frame.
- **Signing:** use the stable identity, because ad-hoc signatures make macOS re-prompt for Bluetooth after every rebuild. The hardened runtime needs the `com.apple.security.personal-information.location` entitlement and the `NSLocationAlwaysAndWhenInUseUsageDescription` key, or Location requests fail silently. The Location prompt shows only while the app is frontmost.
- **Wire protocol:** frames are at most 20 bytes, and only one GATT request can be in flight. iOS and Connect IQ cut oversize notifications silently. Layouts and shared test vectors are in `mac/Tests/vectors.md`. `source/companion/Proto.mc` and `mac/Sources/GarminyCore/Wire.swift` must stay in sync.
- **Tap to open (open-agent-session):** the hook records `__CFBundleIdentifier`, the `ITERM_SESSION_ID` UUID and the controlling tty, and these never go on the wire. The ALERTS buzz byte is a flags byte (bit 0 buzz, bit 1 openable), and the watch sends `OPEN` (0x44) in place of `ACK` for a live tap on an openable alert. A 2 s focus poll clears a session's alerts when the user is active in its tab; it checks `AEDeterminePermissionToAutomateTarget` first, so it never prompts. `SessionOpener` uses AppleScript for iTerm2 and Terminal and falls back to `NSWorkspace.openApplication`. This needs the `com.apple.security.automation.apple-events` entitlement; check `-1743` in the log if tab selection fails.
- **Claude Code exports `CLAUDECODE`,** so the zsh snippet ignores commands run from Claude's own shell. Unset it when testing the snippet.
- **Monkey C reserves the word `hidden`.**
- **Monkey C can't reference a class `const` from outside an instance** (`WorldClockCard.GAP` fails with "Cannot find symbol"). Use a module-level constant (e.g. `CLOCK_GAP`, `AGENT_ROWS`).
- **Desk text:** the floor is `FONT_SMALL` (daily content may drop to TINY). Draw text with `Ui.drawFitted` / `Ui.fitLine` / `Ui.fonts`, which wrap to the round screen's chord and use vector RobotoCondensedBold above 40 px. NUMBER fonts only have digits and `# % + - . / : °`.

Simulator verification notes:
- `scripts/test.sh` leaves the simulator with no app loaded. Relaunch with `monkeydo bin/garminy-fenix7.prg fenix7`.
- Tests write to `Application.Properties`, and the simulator keeps those values, overriding `properties.xml` defaults. Use File → Reset All App Data before checking defaults.
- To check visual states (rain, polar day, °F, moon shapes, alerts), make a temporary preview build that injects the data, screenshot it, then restore the sources. Don't commit preview hooks. When other windows cover the simulator, capture it by window ID with `screencapture -l <id>`, getting the ID from `CGWindowListCopyWindowInfo`.
- Settings → Glance Launch Mode must be "Normal", or the app opens as a glance preview.
