#!/usr/bin/env bash
# Build garminy and copy it onto a USB-connected fēnix 7 (macOS).
# Usage: scripts/sideload.sh [--no-build]
#
# Needs: Homebrew libmtp (brew install libmtp), Swift (Xcode command line tools),
# and the Connect IQ toolchain from the README. Quit Garmin Express first.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=1
case "${1:-}" in
  --no-build) BUILD=0 ;;
  "") ;;
  -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "usage: scripts/sideload.sh [--no-build]" >&2; exit 2 ;;
esac

if ! command -v brew >/dev/null || ! [ -f "$(brew --prefix)/include/libmtp.h" ]; then
  echo "error: libmtp not found. Install it with: brew install libmtp" >&2
  exit 1
fi
if ! command -v swiftc >/dev/null; then
  echo "error: swiftc not found. Install the Xcode command line tools: xcode-select --install" >&2
  exit 1
fi
if pgrep -qf "Garmin Express"; then
  echo "error: Garmin Express is running and will lock the watch. Quit it first." >&2
  exit 1
fi

PRG=bin/garminy-fenix7.prg
if [ "$BUILD" = 1 ]; then
  scripts/build.sh fenix7 | tail -1
fi
[ -f "$PRG" ] || { echo "error: $PRG not found; run without --no-build" >&2; exit 1; }

# Compile the MTP helper when its source is newer than the binary.
HELPER=bin/mtpput
if [ ! -x "$HELPER" ] || [ scripts/mtp/mtpput.swift -nt "$HELPER" ]; then
  echo "Compiling MTP helper..."
  P="$(brew --prefix)"
  swiftc -O -import-objc-header scripts/mtp/bridge.h -I"$P/include" -L"$P/lib" -lmtp \
    scripts/mtp/mtpput.swift -o "$HELPER"
fi

# macOS's ptpcamerad claims MTP devices as soon as they appear; keep it
# stopped while we talk to the watch. It restarts on its own afterwards.
( while true; do killall -9 ptpcamerad 2>/dev/null || true; sleep 0.2; done ) &
GUARD=$!
trap 'kill $GUARD 2>/dev/null || true' EXIT
sleep 0.5

"$HELPER" "$PRG" GARMINY.PRG 2>&1 | grep -v "extended association"
exit "${PIPESTATUS[0]}"
