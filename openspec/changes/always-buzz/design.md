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
   - Why 20 s: the focus-clear needs at most 3 s of activity plus up to a 2 s poll, so 20 s gives the user time to glance at the terminal and click in without making the delay feel long.

3. **The preference is `@Published var buzzMode: BuzzMode` in AppModel, saved to UserDefaults under `buzzMode` with `didSet`, following `keepAwakeEnabled`.** The UI is a `Picker` in the menu, above the "Keep Mac awake" toggle, which is where Mac-only preferences already live.

## Risks / Trade-offs

- [In Smart mode, an alert raised while the user is at the terminal buzzes up to 22 s late] → That is the trade the user picked. Always stays the default.
- [Focus-clear needs Automation for iTerm2 or Terminal. Without it, Smart can't see the tab switch and always buzzes after 20 s] → This fails safe, toward buzzing.
