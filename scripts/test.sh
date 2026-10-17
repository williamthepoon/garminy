#!/usr/bin/env bash
# Build and run unit tests in the Connect IQ simulator: scripts/test.sh [device]
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
export PATH="/opt/homebrew/opt/openjdk@21/bin:$SDK/bin:$PATH"
DEVICE="${1:-fenix7}"
python3 scripts/build_content.py
mkdir -p bin
monkeyc -d "$DEVICE" -f monkey.jungle -o "bin/garminy-test.prg" -y "$HOME/.garmin/developer_key.der" --unit-test
if ! pgrep -f "ConnectIQ.app" >/dev/null; then
  open "$SDK/bin/ConnectIQ.app"
  sleep 6
fi
monkeydo bin/garminy-test.prg "$DEVICE" -t
