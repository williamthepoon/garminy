import Foundation

/// One line on the companion socket, written by `garminy-hook`.
/// Only these fields exist, so prompt text, messages and tool input cannot reach the app.
public struct HookEvent: Codable, Equatable, Sendable {
    /// "claude" or "shell".
    public var src: String
    // Claude Code
    public var event: String?
    public var session: String?
    public var cwd: String?
    public var ntype: String?
    public var tool: String?
    // Shell
    public var phase: String?
    public var cmd: String?
    public var exit: Int?
    public var secs: Int?
    public var pid: Int?
    /// Identifies one command run (its start time), so a late "start" after its "end" is ignored.
    public var id: String?
    public var threshold: Int?
    /// $TERM_PROGRAM of the process that sent the event.
    public var term: String?
    // Where a Claude Code session runs (open-agent-session). Kept on the Mac, never sent to the watch.
    /// Bundle ID of the app hosting the session ($__CFBundleIdentifier).
    public var app: String?
    /// iTerm2 session unique ID (the UUID part of $ITERM_SESSION_ID).
    public var itermSession: String?
    /// Controlling terminal, e.g. "/dev/ttys004".
    public var tty: String?

    public init(src: String, event: String? = nil, session: String? = nil, cwd: String? = nil, ntype: String? = nil,
                tool: String? = nil, phase: String? = nil, cmd: String? = nil, exit: Int? = nil, secs: Int? = nil,
                pid: Int? = nil, id: String? = nil, threshold: Int? = nil, term: String? = nil,
                app: String? = nil, itermSession: String? = nil, tty: String? = nil) {
        self.src = src; self.event = event; self.session = session; self.cwd = cwd; self.ntype = ntype
        self.tool = tool; self.phase = phase; self.cmd = cmd; self.exit = exit; self.secs = secs
        self.pid = pid; self.id = id; self.threshold = threshold; self.term = term
        self.app = app; self.itermSession = itermSession; self.tty = tty
    }

    /// The session location this event carries, with invalid values dropped.
    public var location: SessionLocation {
        SessionLocation(app: app, itermSession: itermSession, tty: tty)
    }

    /// Builds the event from a Claude Code hook's stdin JSON, keeping only allowed fields.
    /// `env` is the hook's environment and `tty` its controlling terminal, for the session location.
    public static func fromClaudeHook(_ json: Data, term: String?, env: [String: String] = [:], tty: String? = nil) -> HookEvent? {
        guard let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let name = obj["hook_event_name"] as? String else { return nil }
        let loc = SessionLocation(app: env["__CFBundleIdentifier"],
                                  itermSession: env["ITERM_SESSION_ID"].map { String($0.split(separator: ":").last ?? "") },
                                  tty: tty)
        return HookEvent(src: "claude", event: name, session: obj["session_id"] as? String,
                         cwd: obj["cwd"] as? String, ntype: obj["notification_type"] as? String,
                         tool: obj["tool_name"] as? String, term: term,
                         app: loc.app, itermSession: loc.itermSession, tty: loc.tty)
    }

    public func line() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        var d = (try? enc.encode(self)) ?? Data()
        d.append(0x0A)
        return d
    }
}

/// Where a Claude Code session runs on the Mac. Every value is validated, because it ends up in AppleScript.
public struct SessionLocation: Equatable, Sendable {
    public var app: String?
    public var itermSession: String?
    public var tty: String?

    public init(app: String?, itermSession: String?, tty: String?) {
        self.app = app.flatMap { Self.matches($0, #"^[A-Za-z0-9][A-Za-z0-9.-]{0,254}$"#) ? $0 : nil }
        self.itermSession = itermSession.flatMap { Self.matches($0, #"^[0-9A-Fa-f-]{36}$"#) ? $0 : nil }
        self.tty = tty.flatMap { Self.matches($0, #"^/dev/ttys[0-9]{1,4}$"#) ? $0 : nil }
    }

    /// Keeps existing values where `newer` has none.
    public func merged(with newer: SessionLocation) -> SessionLocation {
        SessionLocation(app: newer.app ?? app, itermSession: newer.itermSession ?? itermSession, tty: newer.tty ?? tty)
    }

    static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }
}

public enum Format {
    /// "45s", "4m", "1h 5m".
    public static func duration(_ secs: Int) -> String {
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs / 60)m" }
        let m = (secs % 3600) / 60
        return m == 0 ? "\(secs / 3600)h" : "\(secs / 3600)h \(m)m"
    }

    /// "Allow Bash" for a permission alert, within the wire's detail limit.
    /// Drops an `mcp__<server>__` prefix and ends a shortened name with "…".
    public static func allow(_ tool: String?) -> String {
        var name = tool ?? ""
        if name.hasPrefix("mcp__"), let r = name.range(of: "__", range: name.index(name.startIndex, offsetBy: 5)..<name.endIndex) {
            name = String(name[r.upperBound...])
        }
        if name.isEmpty { name = "tool" }
        let full = "Allow " + name
        if full.utf8.count <= Wire.maxAlertDetail { return full }
        var cut = name
        while !cut.isEmpty && ("Allow " + cut + "…").utf8.count > Wire.maxAlertDetail { cut.removeLast() }
        return "Allow " + cut + "…"
    }
}
