# Proposal

## Why

Installing garminy means copying a `.prg` onto the watch over MTP. On macOS that currently needs a GUI app (OpenMTP), plus knowing to quit Garmin Express and to work around `ptpcamerad`, the macOS service that grabs MTP devices first. A single command makes development and contributor testing much faster.

## What Changes

- New `scripts/sideload.sh`:
  1. Builds the app.
  2. Compiles a small Swift helper against `libmtp`.
  3. Keeps `ptpcamerad` from grabbing the watch.
  4. Checks the connected watch is a fēnix 7.
  5. Replaces `GARMIN/Apps/GARMINY.PRG`.
  6. Confirms the upload by name and size.
- New helper source `scripts/mtp/mtpput.swift`.
- README and CONTRIBUTING document the command. OpenMTP stays as the manual alternative.

### Out of scope

- Windows and Linux support. The script targets macOS; the helper is plain libmtp, so a Linux port is possible later.
- Reading the watch's Connect IQ error logs.
- Connect IQ Store publishing, which is tracked as a separate to-do.

## Capabilities

### New Capabilities
- None. This is developer tooling with no change to app behaviour (`skip_specs: true`).

### Modified Capabilities
- None.

## Impact

- Adds a build-time dependency for sideloading only: `brew install libmtp`.
- New files: `scripts/sideload.sh`, `scripts/mtp/mtpput.swift`, `scripts/mtp/bridge.h`. The compiled helper goes to `bin/` and is gitignored.
