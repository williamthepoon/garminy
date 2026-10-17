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

    public init(src: String, event: String? = nil, session: String? = nil, cwd: String? = nil, ntype: String? = nil,
                tool: String? = nil, phase: String? = nil, cmd: String? = nil, exit: Int? = nil, secs: Int? = nil,
                pid: Int? = nil, id: String? = nil, threshold: Int? = nil, term: String? = nil) {
        self.src = src; self.event = event; self.session = session; self.cwd = cwd; self.ntype = ntype
        self.tool = tool; self.phase = phase; self.cmd = cmd; self.exit = exit; self.secs = secs
        self.pid = pid; self.id = id; self.threshold = threshold; self.term = term
    }

    /// Builds the event from a Claude Code hook's stdin JSON, keeping only allowed fields.
    public static func fromClaudeHook(_ json: Data, term: String?) -> HookEvent? {
        guard let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let name = obj["hook_event_name"] as? String else { return nil }
        return HookEvent(src: "claude", event: name, session: obj["session_id"] as? String,
                         cwd: obj["cwd"] as? String, ntype: obj["notification_type"] as? String,
                         tool: obj["tool_name"] as? String, term: term)
    }

    public func line() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        var d = (try? enc.encode(self)) ?? Data()
        d.append(0x0A)
        return d
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
}
