#!/usr/bin/env bash
# Build garminy for one device: scripts/build.sh [device] [extra monkeyc args...]
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
export PATH="/opt/homebrew/opt/openjdk@21/bin:$SDK/bin:$PATH"
DEVICE="${1:-fenix7}"
shift || true
python3 scripts/build_content.py
mkdir -p bin
monkeyc -d "$DEVICE" -f monkey.jungle -o "bin/garminy-$DEVICE.prg" -y "$HOME/.garmin/developer_key.der" -w "$@"
