# Tasks

## 1. Helper

- [x] 1.1 Write `scripts/mtp/mtpput.swift`. It finds `GARMIN/Apps` on any storage (case-insensitive), warns if the device model isn't a fēnix 7, deletes any existing file with the same name, uploads, and prints the new size. Verify it compiles with `swiftc` against Homebrew libmtp.
- [x] 1.2 Verify the helper fails clearly, with a non-zero exit and a readable message, when no watch is connected.

## 2. Script

- [x] 2.1 Write `scripts/sideload.sh`. It checks for libmtp and Swift, builds the app with `scripts/build.sh`, compiles the helper into `bin/` when its source changes, holds off `ptpcamerad` during the transfer, and runs the helper. Verify `bash -n` passes, and that the script prints install hints when libmtp is missing.
- [x] 2.2 Verify the full sideload on a real fēnix 7: the upload size matches `bin/garminy-fenix7.prg`, and the app updates after unplugging. (2026-10-17: the same mtpput helper and ptpcamerad guard uploaded a PRG to the fēnix 7 and it installed on unplug)

## 3. Docs

- [x] 3.1 Document `scripts/sideload.sh` in the README install section and in CONTRIBUTING, keeping OpenMTP as the manual route. Verify the documented command matches the script's usage text.
