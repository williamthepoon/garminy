import Foundation

/// Tracks Claude Code sessions from hook events (agent-status).
public struct SessionTracker: Sendable {
    public struct Session: Equatable, Sendable {
        public var id: String
        public var label: String
        public var state: SessionState
        public var since: Date
        public var lastEvent: Date
        public var term: String?
    }

    /// An alert-worthy change produced by `apply`.
    public enum Effect: Equatable, Sendable {
        case raise(kind: AlertKind, label: String, detail: String, source: String, term: String?)
        case resolve(source: String, kinds: Set<AlertKind>?)
    }

    public static let expiry: TimeInterval = 12 * 3600
    public static let minWorkForDone: TimeInterval = 30
    static let questionTools: Set<String> = ["AskUserQuestion", "ExitPlanMode"]
    static let inputNotifications: Set<String> = ["elicitation_dialog", "agent_needs_input", "permission_prompt"]

    public private(set) var sessions: [String: Session] = [:]

    public init() {}

    public static func source(_ id: String) -> String { "claude:\(id)" }

    public mutating func apply(_ e: HookEvent, now: Date) -> [Effect] {
        guard e.src == "claude", let id = e.session, let name = e.event else { return [] }
        if name == "SessionEnd" {
            sessions[id] = nil
            return [.resolve(source: Self.source(id), kinds: nil)]
        }
        var s = sessions[id] ?? Session(id: id, label: label(for: e.cwd), state: .done, since: now, lastEvent: now, term: e.term)
        s.lastEvent = now
        if let t = e.term { s.term = t }
        let src = Self.source(id)
        var effects: [Effect] = []

        let next: SessionState?
        var detail = ""
        switch name {
        case "SessionStart":
            next = sessions[id] == nil ? .done : nil
        case "UserPromptSubmit":
            next = .working
            effects.append(.resolve(source: src, kinds: nil))
        case "PreToolUse" where Self.questionTools.contains(e.tool ?? ""):
            next = .needsYou
            detail = e.tool == "ExitPlanMode" ? "Plan ready" : "Question"
        case "PreToolUse", "PostToolUse":
            next = .working
        case "PermissionRequest":
            next = .needsYou
            detail = "Permission: \(e.tool ?? "tool")"
        case "Notification" where Self.inputNotifications.contains(e.ntype ?? ""):
            next = s.state == .needsYou ? nil : .needsYou
            detail = e.ntype == "permission_prompt" ? "Permission" : "Input needed"
        case "Stop":
            next = .done
        case "StopFailure":
            next = .error
        default:
            next = nil
        }

        if let next, next != s.state {
            let worked = now.timeIntervalSince(s.since)
            let from = s.state
            s.state = next
            s.since = now
            switch next {
            case .needsYou:
                effects.append(.raise(kind: .needsYou, label: s.label, detail: detail, source: src, term: s.term))
            case .working where from == .needsYou:
                effects.append(.resolve(source: src, kinds: [.needsYou]))
            case .done where from == .working && worked >= Self.minWorkForDone:
                effects.append(.raise(kind: .done, label: s.label, detail: "Done · \(Format.duration(Int(worked)))", source: src, term: s.term))
            case .done where from == .needsYou:
                effects.append(.resolve(source: src, kinds: [.needsYou]))
            case .error:
                effects.append(.resolve(source: src, kinds: [.needsYou]))
                effects.append(.raise(kind: .failed, label: s.label, detail: "Stopped with an error", source: src, term: s.term))
            default:
                break
            }
        }
        sessions[id] = s
        return effects
    }

    /// Removes sessions with no events for 12 hours; returns their ids.
    public mutating func expire(now: Date) -> [String] {
        let old = sessions.values.filter { now.timeIntervalSince($0.lastEvent) >= Self.expiry }.map(\.id)
        old.forEach { sessions[$0] = nil }
        return old
    }

    public var ordered: [Session] {
        sessions.values.sorted { ($0.state.urgency, $0.since, $0.id) < ($1.state.urgency, $1.since, $1.id) }
    }

    public var anyWorking: Bool { sessions.values.contains { $0.state == .working } }

    public func wire(now: Date) -> (sessions: [WireSession], hidden: UInt8) {
        let o = ordered
        let shown = o.prefix(Wire.maxSessions).map {
            WireSession(state: $0.state, minutes: UInt16(clamping: Int(now.timeIntervalSince($0.since) / 60)), label: $0.label)
        }
        return (Array(shown), UInt8(clamping: o.count - shown.count))
    }

    /// Last path component of cwd, 16 characters max, with " 2", " 3"... for duplicates.
    func label(for cwd: String?) -> String {
        let base = String(((cwd ?? "").split(separator: "/").last.map(String.init) ?? "claude").prefix(Wire.maxSessionLabel))
        let taken = Set(sessions.values.map(\.label))
        if !taken.contains(base) { return base }
        for n in 2...99 {
            let suffix = " \(n)"
            let l = String(base.prefix(Wire.maxSessionLabel - suffix.count)) + suffix
            if !taken.contains(l) { return l }
        }
        return base
    }
}

/// Long shell commands (command-alerts).
public struct CommandTracker: Sendable {
    public struct Running: Equatable, Sendable {
        public var cmd: String
        public var started: Date
        public var threshold: Int
    }

    public static let cap: TimeInterval = 12 * 3600
    public private(set) var running: [Int: Running] = [:]
    /// Last finished run per shell, to drop a "start" that arrives after its "end".
    private var ended: [Int: String] = [:]

    public init() {}

    public static func source(_ pid: Int) -> String { "shell:\(pid)" }

    /// Returns an alert to raise when a long command finishes.
    public mutating func apply(_ e: HookEvent, now: Date) -> SessionTracker.Effect? {
        guard e.src == "shell", let pid = e.pid else { return nil }
        switch e.phase {
        case "start":
            if let id = e.id, ended[pid] == id { return nil }
            running[pid] = Running(cmd: e.cmd ?? "command", started: now, threshold: e.threshold ?? 30)
            return nil
        case "end":
            running[pid] = nil
            if let id = e.id { ended[pid] = id }
            guard let secs = e.secs, secs >= (e.threshold ?? 30) else { return nil }
            let cmd = e.cmd ?? "command"
            let code = e.exit ?? 0
            let dur = Format.duration(secs)
            return code == 0
                ? .raise(kind: .done, label: cmd, detail: dur, source: Self.source(pid), term: e.term)
                : .raise(kind: .failed, label: cmd, detail: "\(dur) · exit \(code)", source: Self.source(pid), term: e.term)
        default:
            return nil
        }
    }

    public mutating func expire(now: Date) {
        running = running.filter { now.timeIntervalSince($0.value.started) < Self.cap }
    }

    /// A command running at least its threshold counts as work for keep-awake.
    public func anyLongRunning(now: Date) -> Bool {
        running.values.contains { now.timeIntervalSince($0.started) >= Double($0.threshold) }
    }
}
