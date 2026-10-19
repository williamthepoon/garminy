# Design

## Context

- `Buzz.play(kind)` in `Companion.mc` calls `Attention.vibrate` for a new alert with the buzz flag and for a Mac `BUZZ` message. On the fēnix 7 this does nothing while charging.
- `Attention.playTone` and `Attention.backlight` both worked on the charger in a temporary test build on 2026-10-19. The tone needs the watch's System → Sound & Vibe → Alert Tones setting on.
- Settings travel in `SETTINGS` (Mac → watch, 0x07) and `WATCH_SETTINGS` (0x43). The newer `changedAt` wins. The payload is 13 bytes, under the 17-byte single-frame limit.

## Decisions

### 1. Decide on the watch, not the Mac
The watch checks `System.getSystemStats().charging` when it plays a buzz. The Mac doesn't know the charging state, and sending it would be a new message for no gain.

### 2. Two new bytes, appended after `companion`
- `chargerSignal` u8: 0 Nothing, 1 Beep, 2 Light, 3 Beep and light. Default 1.
- `beepSound` u8: 0 Soft, 1 Chime, 2 Standard. Default 0.

The payload becomes 15 bytes, still one frame. Both decoders read them as optional: a 13-byte payload yields the defaults, so an older companion and a newer watch still sync the other settings.

*Alternative:* a protocol version bump. That would hide all companion content during a mixed install, which is worse than a missing field.

### 3. Beep sounds
`Attention.playTone` has no volume parameter, so loudness is shaped by pitch and length. The piezo is loudest around 2–4 kHz, so low and short means quiet. All three sounds use `ToneProfile` arrays via `playTone({:toneProfile => ...})` (API 3.0+), except Standard. Starting values, to tune on the watch:
- **Soft:** 600 Hz × 40 ms clicks, separated by 0 Hz × 120 ms gaps. 3 clicks for needs you, 2 for failed, 1 for done.
- **Chime:** done is 880 → 1320 Hz at 90 ms each; failed is 660 → 440 Hz; needs you is 880 → 1100 → 1320 Hz.
- **Standard:** the `TONE_ALERT_HI`, `TONE_FAILURE` and `TONE_SUCCESS` constants.

The watch checks `Attention has :playTone`.

### 5. Test on watch
New Mac → watch message `TEST_SIGNAL` (0x0A), payload: kind u8. The watch calls the same function as a real buzz, so the test exercises the charging check and settings. The Mac sends any pending settings first, so the test plays what's on screen. An older watch ignores the unknown type.

### 4. The light uses `Attention.backlight(true)`
The device times it out as usual. If the app's Backlight setting already holds the light on, this changes nothing, which is fine.

## Risks / Trade-offs

- [Alert Tones off on the watch: the beep is silent, as in the first charging test] → The README tells the user to turn it on, and the setting's title in Garmin Connect says "needs Alert Tones on".
- [A beep every 5 minutes for unanswered needs-you alerts while you're away could annoy people at home] → The repeat already stops after 3, and the user can pick Light or Nothing.
- [Firmware might allow vibration while charging on other versions] → Charging uses the fallback either way, which is harmless.
