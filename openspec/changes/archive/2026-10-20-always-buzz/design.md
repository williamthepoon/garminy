# Design

## Context

`PresencePolicy.buzzOnRaise(term:presence:)` (`mac/Sources/GarminyCore/AlertQueue.swift`) returns false when the user is active and the source's terminal is frontmost. `AppModel.handle` sets `buzzOnShow`, `buzzes = 1` and `lastBuzz` only when it returns true. `repeatDue` requires `buzzes >= 1`, so an alert that was silent when raised never repeats. The user chose to keep that rule. The watch already handles `BUZZ (0x04)` for any alert it's showing, which is how repeats work. A 2 s `focusTick` runs `clearFocused()`, which withdraws a session's alerts when the user is active in its tab.

## Goals / Non-Goals

**Goals:**
- Three buzz modes, with the decision logic kept as pure, testable functions in GarminyCore.
- Smart mode reuses the existing focus-clear, and adds no new presence signals.

**Non-Goals:**
- Any watch or wire change.

## Decisions

1. **`public enum BuzzMode: Int { case always = 0, smart = 1, notAtTerminal = 2 }` in GarminyCore, and `buzzOnRaise(term:presence:mode:) -> BuzzDecision`, where `BuzzDecision` is `.now`, `.after(TimeInterval)` or `.never`.** "At terminal" is the existing condition: `!presence.away && terminalIsFrontmost`. Always gives `.now`. When not at the terminal, every mode gives `.now`. At the terminal, Smart gives `.after(20)` and Not at terminal gives `.never`. The `terminals` map and `terminalIsFrontmost` stay.
   - Considered: a Bool plus a separate smart flag. Rejected because one enum keeps the choice to a single function and a single test table.

2. **The delayed buzz is stored on the alert as `buzzAt: Date?`.** The raise path sends `.now` as today (`buzzOnShow`, `buzzes = 1`, `lastBuzz`). For `.after(d)` it sets `buzzAt = now + d` and shows the alert silently. A pure `PresencePolicy.delayedDue(_:now:)` returns true when `buzzAt <= now && buzzes == 0`. AppModel calls it from the 2 s `focusTick`, then sends `BUZZ(id)` and sets `buzzes = 1` and `lastBuzz`. Once that has happened, the alert has buzzed, so it can repeat under the unchanged rule.
   - Considered: a one-shot `Timer` per alert. Rejected because the 2 s tick already exists and survives the queue being rebuilt. A timer would need cancelling whenever an alert is resolved.
   - **Own step, before the focus-clear.** `focusTick` first runs the delayed-buzz step for every alert, then `clearFocused()`. The delayed step does not go through `FocusPolicy.hostToCheck`, whose 3 s activity guard would otherwise skip it whenever the user is idle, which is exactly the "looking at another machine" case.
   - **Disconnected when due.** `BLEPeripheral.send` drops messages while disconnected. So when a delayed buzz comes due with the watch disconnected, AppModel still sets `buzzes = 1` and `lastBuzz`, and adds the id to `buzzOnReconnect`. `sendSnapshot()` sends `BUZZ(id)` for each id still in the queue after the ALERTS message, then empties the set. The watch buzzes once in both cases. If it kept running, its `_seen` set already holds the id, so a `buzzOnShow` flag would be ignored. If it restarted, a flag plus a BUZZ would buzz twice. So `buzzOnShow` is not used for late buzzes.
   - **Race with a pending focus-clear.** `opener.selectedTab` answers asynchronously. While a tab-selection check for the alert's session is in flight, the delayed step skips that alert and tries again on the next tick (at most 2 s later). If the check then clears the alert, it never buzzes.
   - **Terminals without tab support** (Ghostty, VS Code, Warp and similar): `FocusPolicy` clears on `inFront` alone. So in Smart mode an alert raised while typing there is cleared within about 2 s and never buzzes, which behaves like Not at terminal. This is consistent with the spec: the user is active in that app.
   - Why 20 s: the focus-clear needs at most 3 s of activity plus up to a 2 s poll, so 20 s gives the user time to glance at the terminal and click in without making the delay feel long.

3. **The preference is `@Published var buzzMode: BuzzMode` in AppModel, saved to UserDefaults under `buzzMode` with `didSet`, following `keepAwakeEnabled`.** The UI is a `Picker` in the menu, above the "Keep Mac awake" toggle, which is where Mac-only preferences already live.

## Risks / Trade-offs

- [In Smart mode, an alert raised while the user is at the terminal buzzes up to 22 s late] → That is the trade the user picked. Always stays the default.
- [Focus-clear needs Automation for iTerm2 or Terminal. Without it, Smart can't see the tab switch and always buzzes after 20 s] → This fails safe, toward buzzing.
- [On a desk watch that is always charging, Always plus the default Beep charger signal means a beep for every Claude turn, including during quiet hours, which only drop the light] → The user confirmed on 2026-10-20 to keep this as is. Quiet hours muting stays out of scope.
- [A delayed buzz can be skipped for up to 2 s per tick while a tab check is in flight] → At most a few seconds late, never lost.
