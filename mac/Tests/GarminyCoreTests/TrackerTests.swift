import Foundation
import Testing
@testable import GarminyCore

let t0 = Date(timeIntervalSince1970: 1_760_000_000)
func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }
func claude(_ event: String, _ session: String = "s1", cwd: String = "/Users/x/garminy", tool: String? = nil, ntype: String? = nil) -> HookEvent {
    HookEvent(src: "claude", event: event, session: session, cwd: cwd, ntype: ntype, tool: tool, term: "iTerm.app")
}

// MARK: agent-status

@Test func agentFinishesLongTurnRaisesDone() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit"), now: at(0))
    let fx = t.apply(claude("Stop"), now: at(240))
    #expect(t.sessions["s1"]?.state == .done)
    #expect(fx == [.raise(kind: .done, label: "garminy", detail: "Done · 4m", source: "claude:s1", term: "iTerm.app")])
}

@Test func quickTurnNoAlert() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit"), now: at(0))
    let fx = t.apply(claude("Stop"), now: at(10))
    #expect(t.sessions["s1"]?.state == .done)
    #expect(fx.isEmpty)
}

@Test func permissionAndQuestionsNeedYou() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit"), now: at(0))
    let fx = t.apply(claude("PermissionRequest", tool: "Bash"), now: at(5))
    #expect(t.sessions["s1"]?.state == .needsYou)
    #expect(fx == [.raise(kind: .needsYou, label: "garminy", detail: "Allow Bash", source: "claude:s1", term: "iTerm.app")])
    // Answering resolves it.
    let fx2 = t.apply(claude("PostToolUse", tool: "Bash"), now: at(9))
    #expect(fx2 == [.resolve(source: "claude:s1", kinds: [.needsYou])])
    let fx3 = t.apply(claude("PreToolUse", tool: "AskUserQuestion"), now: at(20))
    #expect(fx3.first == .raise(kind: .needsYou, label: "garminy", detail: "Question", source: "claude:s1", term: "iTerm.app"))
    _ = t.apply(claude("UserPromptSubmit"), now: at(30))
    let fx4 = t.apply(claude("PreToolUse", tool: "ExitPlanMode"), now: at(40))
    #expect(fx4.first == .raise(kind: .needsYou, label: "garminy", detail: "Plan ready", source: "claude:s1", term: "iTerm.app"))
}

@Test func idleReminderIgnored() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit"), now: at(0))
    _ = t.apply(claude("Stop"), now: at(100))
    let fx = t.apply(claude("Notification", ntype: "idle_prompt"), now: at(160))
    #expect(t.sessions["s1"]?.state == .done)
    #expect(fx.isEmpty)
}

@Test func stopFailureIsError() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit"), now: at(0))
    let fx = t.apply(claude("StopFailure"), now: at(5))
    #expect(t.sessions["s1"]?.state == .error)
    #expect(fx.contains(.raise(kind: .failed, label: "garminy", detail: "Error", source: "claude:s1", term: "iTerm.app")))
}

@Test func newPromptResolvesEverything() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit"), now: at(0))
    _ = t.apply(claude("Stop"), now: at(100))
    let fx = t.apply(claude("UserPromptSubmit"), now: at(200))
    #expect(fx.contains(.resolve(source: "claude:s1", kinds: nil)))
}

@Test func sessionLifetime() {
    var t = SessionTracker()
    _ = t.apply(claude("SessionStart"), now: at(0))
    _ = t.apply(claude("SessionStart", "s2"), now: at(0))
    _ = t.apply(claude("SessionEnd"), now: at(10))
    #expect(t.sessions["s1"] == nil)
    #expect(t.expire(now: at(12 * 3600 - 1)).isEmpty)
    #expect(t.expire(now: at(12 * 3600 + 1)) == ["s2"])
    #expect(t.sessions.isEmpty)
}

@Test func duplicateLabelsGetSuffix() {
    var t = SessionTracker()
    _ = t.apply(claude("SessionStart", "a", cwd: "/x/garminy"), now: at(0))
    _ = t.apply(claude("SessionStart", "b", cwd: "/y/garminy"), now: at(1))
    _ = t.apply(claude("SessionStart", "c", cwd: "/z/a-very-long-folder-name-here"), now: at(2))
    #expect(t.sessions["a"]?.label == "garminy")
    #expect(t.sessions["b"]?.label == "garminy 2")
    #expect(t.sessions["c"]?.label == "a-very-long-fold")
}

@Test func agentsCardOrder() {
    var t = SessionTracker()
    _ = t.apply(claude("UserPromptSubmit", "w", cwd: "/x/api-svc"), now: at(0))
    _ = t.apply(claude("UserPromptSubmit", "d", cwd: "/x/website"), now: at(0))
    _ = t.apply(claude("Stop", "d", cwd: "/x/website"), now: at(60))
    _ = t.apply(claude("UserPromptSubmit", "n", cwd: "/x/garminy"), now: at(0))
    _ = t.apply(claude("PermissionRequest", "n", cwd: "/x/garminy", tool: "Bash"), now: at(600))
    let w = t.wire(now: at(720))
    #expect(w.sessions.map(\.label) == ["garminy", "api-svc", "website"])
    #expect(w.sessions.map(\.state) == [.needsYou, .working, .done])
    #expect(w.sessions[1].minutes == 12)
    #expect(w.hidden == 0)
}

// MARK: desk-alerts

@Test func queueOrderAndExpiry() {
    var q = AlertQueue()
    q.add(kind: .done, label: "a", detail: "", source: "x", term: nil, now: at(0))
    q.add(kind: .needsYou, label: "b", detail: "", source: "y", term: nil, now: at(10))
    q.add(kind: .failed, label: "c", detail: "", source: "z", term: nil, now: at(20))
    #expect(q.ordered.map(\.label) == ["b", "c", "a"])
    q.expire(now: at(2 * 3600 + 30))
    #expect(q.ordered.map(\.label) == ["b"])
}

@Test func acknowledgeAndResolve() {
    var q = AlertQueue()
    let a = q.add(kind: .done, label: "a", detail: "", source: "x", term: nil, now: at(0))
    q.add(kind: .needsYou, label: "b", detail: "", source: "y", term: nil, now: at(0))
    q.acknowledge(id: a.id)
    q.resolve(source: "y", kinds: [.needsYou])
    #expect(q.alerts.isEmpty)
}

@Test func wireCountsHidden() {
    var q = AlertQueue()
    for i in 0..<7 { q.add(kind: .done, label: "\(i)", detail: "", source: "s\(i)", term: nil, now: at(Double(i))) }
    let w = q.wire()
    #expect(w.alerts.count == 5 && w.total == 7)
}

@Test func buzzByPresence() {
    let typingInITerm = Presence(idleSeconds: 3, locked: false, frontmostBundle: "com.googlecode.iterm2")
    let inBrowser = Presence(idleSeconds: 3, locked: false, frontmostBundle: "com.apple.Safari")
    let locked = Presence(idleSeconds: 0, locked: true, frontmostBundle: "com.googlecode.iterm2")
    let idle = Presence(idleSeconds: 150, locked: false, frontmostBundle: "com.googlecode.iterm2")
    #expect(!PresencePolicy.buzzOnRaise(term: "iTerm.app", presence: typingInITerm))
    #expect(PresencePolicy.buzzOnRaise(term: "iTerm.app", presence: inBrowser))
    #expect(PresencePolicy.buzzOnRaise(term: "iTerm.app", presence: locked))
    #expect(PresencePolicy.buzzOnRaise(term: "iTerm.app", presence: idle))
    #expect(PresencePolicy.buzzOnRaise(term: nil, presence: typingInITerm))
}

@Test func needsYouRepeatsWhileAway() {
    let away = Presence(idleSeconds: 0, locked: true, frontmostBundle: nil)
    var q = AlertQueue()
    var a = q.add(kind: .needsYou, label: "g", detail: "", source: "s", term: nil, now: at(0))
    a.buzzes = 1; a.lastBuzz = at(0)
    var times = [0.0]
    for s in stride(from: 0.0, through: 16 * 60, by: 30) where PresencePolicy.repeatDue(a, presence: away, now: at(s)) {
        a.buzzes += 1; a.lastBuzz = at(s); times.append(s)
    }
    #expect(times == [0, 300, 600, 900])
    #expect(a.buzzes == 4)
    // Back at the desk: no repeats.
    var b = a; b.buzzes = 1
    #expect(!PresencePolicy.repeatDue(b, presence: Presence(idleSeconds: 1, locked: false, frontmostBundle: nil), now: at(2000)))
    // Done alerts never repeat.
    var d = a; d.kind = .done; d.buzzes = 1
    #expect(!PresencePolicy.repeatDue(d, presence: away, now: at(5000)))
}

// MARK: command-alerts

func shell(_ phase: String, _ cmd: String, exit: Int? = nil, secs: Int? = nil, pid: Int = 42) -> HookEvent {
    HookEvent(src: "shell", phase: phase, cmd: cmd, exit: exit, secs: secs, pid: pid, threshold: 30, term: "iTerm.app")
}

@Test func longCommandAlerts() {
    var c = CommandTracker()
    _ = c.apply(shell("start", "cargo"), now: at(0))
    #expect(c.apply(shell("end", "cargo", exit: 0, secs: 134), now: at(134))
            == .raise(kind: .done, label: "cargo", detail: "2m", source: "shell:42", term: "iTerm.app"))
    _ = c.apply(shell("start", "pytest"), now: at(200))
    #expect(c.apply(shell("end", "pytest", exit: 1, secs: 240), now: at(440))
            == .raise(kind: .failed, label: "pytest", detail: "4m · exit 1", source: "shell:42", term: "iTerm.app"))
    #expect(c.apply(shell("end", "ls", exit: 0, secs: 0), now: at(441)) == nil)
}

@Test func runningCommandsKeepAwake() {
    var c = CommandTracker()
    _ = c.apply(shell("start", "make"), now: at(0))
    #expect(!c.anyLongRunning(now: at(10)))
    #expect(c.anyLongRunning(now: at(3600)))
    c.expire(now: at(13 * 3600))
    #expect(c.running.isEmpty)
}

@Test func durationFormat() {
    #expect(Format.duration(45) == "45s")
    #expect(Format.duration(240) == "4m")
    #expect(Format.duration(3900) == "1h 5m")
}

// MARK: privacy

@Test func hookEventDropsContent() throws {
    let raw = """
    {"hook_event_name":"UserPromptSubmit","session_id":"abc","cwd":"/x/garminy","prompt":"SECRET PROMPT",
     "message":"SECRET MESSAGE","last_assistant_message":"SECRET REPLY","tool_input":{"command":"rm -rf secret"},"tool_name":"Bash"}
    """
    let e = try #require(HookEvent.fromClaudeHook(Data(raw.utf8), term: "iTerm.app"))
    let line = String(decoding: e.line(), as: UTF8.self)
    #expect(!line.contains("SECRET") && !line.contains("rm -rf"))
    #expect(line.contains("UserPromptSubmit") && line.hasSuffix("\n"))
}

@Test func lateStartAfterEndIsIgnored() {
    var c = CommandTracker()
    _ = c.apply(HookEvent(src: "shell", phase: "end", cmd: "ls", exit: 0, secs: 0, pid: 9, id: "100.5", threshold: 30), now: at(0))
    _ = c.apply(HookEvent(src: "shell", phase: "start", cmd: "ls", pid: 9, id: "100.5", threshold: 30), now: at(0))
    #expect(c.running.isEmpty)
    _ = c.apply(HookEvent(src: "shell", phase: "start", cmd: "make", pid: 9, id: "200.1", threshold: 30), now: at(1))
    #expect(c.running[9]?.cmd == "make")
}

// MARK: open-agent-session

let itermUUID = "9B2568DF-31BB-4892-97AC-5DAAD4A462F3"

@Test func hookCapturesSessionLocation() throws {
    let raw = #"{"hook_event_name":"SessionStart","session_id":"s1","cwd":"/x/garminy"}"#
    let env = ["__CFBundleIdentifier": "com.googlecode.iterm2", "ITERM_SESSION_ID": "w0t1p0:\(itermUUID)"]
    let e = try #require(HookEvent.fromClaudeHook(Data(raw.utf8), term: "iTerm.app", env: env, tty: "/dev/ttys004"))
    #expect(e.location == SessionLocation(app: "com.googlecode.iterm2", itermSession: itermUUID, tty: "/dev/ttys004"))
}

@Test func sessionLocationRejectsScriptInjection() {
    let l = SessionLocation(app: "com.x\" & do shell script \"x", itermSession: "\" & quit & \"", tty: "/dev/ttys1\"")
    #expect(l == SessionLocation(app: nil, itermSession: nil, tty: nil))
}

@Test func trackerKeepsLatestLocation() {
    var t = SessionTracker()
    var e = claude("SessionStart")
    e.app = "com.googlecode.iterm2"; e.itermSession = itermUUID; e.tty = "/dev/ttys004"
    _ = t.apply(e, now: at(0))
    var e2 = claude("PermissionRequest", tool: "Bash")
    e2.tty = "/dev/ttys009"
    _ = t.apply(e2, now: at(1))
    #expect(t.location(source: "claude:s1") == SessionLocation(app: "com.googlecode.iterm2", itermSession: itermUUID, tty: "/dev/ttys009"))
    #expect(t.location(source: "shell:42") == nil)
}

@Test func locationNeverReachesTheWire() {
    var t = SessionTracker()
    var e = claude("PermissionRequest", tool: "Bash")
    e.app = "com.googlecode.iterm2"; e.itermSession = itermUUID; e.tty = "/dev/ttys004"
    let fx = t.apply(e, now: at(0))
    var q = AlertQueue()
    for case let .raise(kind, label, detail, source, term) in fx {
        q.add(kind: kind, label: label, detail: detail, source: source, term: term, now: at(0))
    }
    let frames = Wire.encode(MacMessage.sessions(t.wire(now: at(0)).sessions, hidden: 0), msgId: 1)
        + Wire.encode(MacMessage.alerts(q.wire().alerts, total: q.wire().total), msgId: 2)
    let bytes = frames.reduce(Data(), +)
    for secret in ["iterm2", "9B2568DF", "ttys"] {
        #expect(bytes.range(of: Data(secret.utf8)) == nil)
    }
}

@Test func focusClearsOnlyTheSelectedTab() {
    var q = AlertQueue()
    q.add(kind: .done, label: "a", detail: "", source: "claude:a", term: nil, now: at(0))
    q.add(kind: .needsYou, label: "b", detail: "", source: "claude:b", term: nil, now: at(0))
    q.add(kind: .done, label: "c", detail: "", source: "claude:c", term: nil, now: at(0))
    q.add(kind: .done, label: "cargo", detail: "", source: "shell:1", term: nil, now: at(0))
    let iterm = "com.googlecode.iterm2"
    let locs: [String: SessionLocation] = [
        "claude:a": SessionLocation(app: iterm, itermSession: itermUUID, tty: "/dev/ttys004"),
        "claude:b": SessionLocation(app: iterm, itermSession: "11111111-2222-3333-4444-555555555555", tty: "/dev/ttys005"),
        "claude:c": SessionLocation(app: "com.microsoft.VSCode", itermSession: nil, tty: "/dev/ttys006"),
    ]
    let loc = { (s: String) in locs[s] }
    let typing = Presence(idleSeconds: 1, locked: false, frontmostBundle: iterm)
    let host = FocusPolicy.hostToCheck(alerts: q.alerts, location: loc, presence: typing)
    #expect(host == iterm)
    let selectedA = SessionLocation(app: nil, itermSession: itermUUID, tty: nil)
    #expect(FocusPolicy.inFront(alerts: q.alerts, location: loc, host: iterm, selected: selectedA) == ["claude:a"])
    #expect(FocusPolicy.inFront(alerts: q.alerts, location: loc, host: iterm, selected: nil).isEmpty)
    #expect(FocusPolicy.inFront(alerts: q.alerts, location: loc, host: "com.microsoft.VSCode", selected: nil) == ["claude:c"])
    // Idle, locked, or in an app with no alerting session: nothing to check.
    #expect(FocusPolicy.hostToCheck(alerts: q.alerts, location: loc, presence: Presence(idleSeconds: 300, locked: false, frontmostBundle: iterm)) == nil)
    #expect(FocusPolicy.hostToCheck(alerts: q.alerts, location: loc, presence: Presence(idleSeconds: 1, locked: true, frontmostBundle: iterm)) == nil)
    #expect(FocusPolicy.hostToCheck(alerts: q.alerts, location: loc, presence: Presence(idleSeconds: 1, locked: false, frontmostBundle: "com.apple.Safari")) == nil)
}

@Test func permissionDetailFitsTheWire() {
    #expect(Format.allow("Bash") == "Allow Bash")
    #expect(Format.allow(nil) == "Allow tool")
    #expect(Format.allow("mcp__github__list_prs") == "Allow list_prs")
    #expect(Format.allow("mcp__claude_ai_Gmail__search_threads") == "Allow search_threads")
    let long = Format.allow("mcp__claude_ai_Google_Calendar__create_event_now")
    #expect(long.utf8.count <= Wire.maxAlertDetail)
    #expect(long.hasPrefix("Allow create_") && long.hasSuffix("…"))
    #expect(Format.allow("NotebookEdit") == "Allow NotebookEdit")
    #expect(Format.allow("AVeryLongToolNameIndeed").utf8.count <= Wire.maxAlertDetail)
}
