import Foundation

public struct Alert: Equatable, Sendable {
    public var id: UInt8
    public var kind: AlertKind
    public var label: String
    public var detail: String
    /// Who raised it: "claude:<session>" or "shell:<pid>".
    public var source: String
    /// $TERM_PROGRAM of the source, for presence checks.
    public var term: String?
    public var created: Date
    public var buzzes: Int = 0
    public var lastBuzz: Date?
    /// Buzz when the watch first shows it.
    public var buzzOnShow: Bool = false
    /// Smart mode: buzz at this time if it hasn't buzzed yet (always-buzz).
    public var buzzAt: Date?
    /// Raised by a Claude session whose host app is known (open-agent-session).
    public var openable: Bool = false
}

/// The Mac-owned alert queue (desk-alerts). Ordered needs you, failed, done; oldest first within a kind.
public struct AlertQueue: Sendable {
    public static let expiry: TimeInterval = 2 * 3600
    public private(set) var alerts: [Alert] = []
    private var nextId: UInt8 = 1

    public init() {}

    public var ordered: [Alert] {
        alerts.sorted { ($0.kind, $0.created) < ($1.kind, $1.created) }
    }

    @discardableResult
    public mutating func add(kind: AlertKind, label: String, detail: String, source: String,
                             term: String?, now: Date) -> Alert {
        let a = Alert(id: freshId(), kind: kind, label: label, detail: detail, source: source, term: term, created: now)
        alerts.append(a)
        return a
    }

    public mutating func update(_ a: Alert) {
        if let i = alerts.firstIndex(where: { $0.id == a.id }) { alerts[i] = a }
    }

    public mutating func acknowledge(id: UInt8) {
        alerts.removeAll { $0.id == id }
    }

    /// Withdraws alerts from a source, optionally only some kinds.
    public mutating func resolve(source: String, kinds: Set<AlertKind>? = nil) {
        alerts.removeAll { $0.source == source && (kinds?.contains($0.kind) ?? true) }
    }

    /// Done and failed alerts expire after 2 hours; needs-you alerts never do.
    public mutating func expire(now: Date) {
        alerts.removeAll { $0.kind != .needsYou && now.timeIntervalSince($0.created) >= Self.expiry }
    }

    public func wire() -> (alerts: [WireAlert], total: UInt8) {
        let o = ordered
        let shown = o.prefix(Wire.maxAlerts).map {
            WireAlert(id: $0.id, kind: $0.kind, buzz: $0.buzzOnShow, label: $0.label, detail: $0.detail, openable: $0.openable)
        }
        return (Array(shown), UInt8(min(255, o.count)))
    }

    private mutating func freshId() -> UInt8 {
        let used = Set(alerts.map(\.id))
        for _ in 0..<255 {
            let id = nextId
            nextId = nextId == 255 ? 1 : nextId + 1
            if !used.contains(id) { return id }
        }
        return nextId
    }
}

/// What the Mac knows about the user, for deciding when to buzz.
public struct Presence: Equatable, Sendable {
    public var idleSeconds: Double
    public var locked: Bool
    public var frontmostBundle: String?

    public init(idleSeconds: Double, locked: Bool, frontmostBundle: String?) {
        self.idleSeconds = idleSeconds; self.locked = locked; self.frontmostBundle = frontmostBundle
    }

    public var away: Bool { locked || idleSeconds >= PresencePolicy.awayAfter }
}

/// The Buzz on Claude alerts setting (always-buzz).
public enum BuzzMode: Int, CaseIterable, Sendable {
    case always = 0, smart = 1, notAtTerminal = 2

    public var title: String {
        switch self {
        case .always: return "Always"
        case .smart: return "Smart"
        case .notAtTerminal: return "Not at terminal"
        }
    }
}

public enum BuzzDecision: Equatable, Sendable {
    case now
    case after(TimeInterval)
    case never
}

public enum PresencePolicy {
    public static let awayAfter: Double = 120
    public static let repeatEvery: TimeInterval = 300
    public static let maxRepeats = 3

    /// Bundle IDs of terminals by $TERM_PROGRAM.
    public static let terminals: [String: Set<String>] = [
        "iTerm.app": ["com.googlecode.iterm2"],
        "Apple_Terminal": ["com.apple.Terminal"],
        "ghostty": ["com.mitchellh.ghostty"],
        "WarpTerminal": ["dev.warp.Warp-Stable", "dev.warp.Warp"],
        "WezTerm": ["com.github.wez.wezterm"],
        "vscode": ["com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.exafunction.windsurf"],
        "zed": ["dev.zed.Zed"],
    ]

    public static func terminalIsFrontmost(term: String?, presence: Presence) -> Bool {
        guard let term, let front = presence.frontmostBundle, let ids = terminals[term] else { return false }
        return ids.contains(front)
    }

    public static let smartDelay: TimeInterval = 20

    /// Not at the terminal: every mode buzzes now. Active with the source's terminal frontmost:
    /// Always buzzes now, Smart waits 20 s, Not at terminal stays silent.
    public static func buzzOnRaise(term: String?, presence: Presence, mode: BuzzMode) -> BuzzDecision {
        guard !presence.away && terminalIsFrontmost(term: term, presence: presence) else { return .now }
        switch mode {
        case .always: return .now
        case .smart: return .after(smartDelay)
        case .notAtTerminal: return .never
        }
    }

    /// A Smart alert that hasn't buzzed yet buzzes once its time comes, whatever the user is doing,
    /// unless a tab check for its session is still in flight.
    public static func delayedDue(_ a: Alert, now: Date, checking: Bool = false) -> Bool {
        guard let at = a.buzzAt, a.buzzes == 0, !checking else { return false }
        return at <= now
    }

    /// A needs-you alert re-buzzes every 5 minutes while the user is away, at most 3 more times.
    public static func repeatDue(_ a: Alert, presence: Presence, now: Date) -> Bool {
        guard a.kind == .needsYou, presence.away, a.buzzes >= 1, a.buzzes <= maxRepeats,
              let last = a.lastBuzz else { return false }
        return now.timeIntervalSince(last) >= repeatEvery
    }
}

/// Clears a session's alerts when the user is working in it (open-agent-session).
public enum FocusPolicy {
    public static let activeWithin: Double = 3
    /// Hosts where only the selected tab counts; anywhere else the frontmost app is enough.
    public static let tabHosts: Set<String> = ["com.googlecode.iterm2", "com.apple.Terminal"]

    /// Hosts worth asking for their selected tab: the frontmost app, if it hosts an alerting session.
    public static func hostToCheck(alerts: [Alert], location: (String) -> SessionLocation?, presence: Presence) -> String? {
        guard !presence.locked, presence.idleSeconds < activeWithin, let front = presence.frontmostBundle else { return nil }
        return alerts.contains { location($0.source)?.app == front } ? front : nil
    }

    /// Sources of alerts whose session is in front. `selected` is the host's selected tab (iTerm2 or Terminal),
    /// or nil when it could not be read; tab hosts then clear nothing.
    public static func inFront(alerts: [Alert], location: (String) -> SessionLocation?, host: String,
                               selected: SessionLocation?) -> Set<String> {
        Set(alerts.compactMap { a -> String? in
            guard let loc = location(a.source), loc.app == host else { return nil }
            if !tabHosts.contains(host) { return a.source }
            guard let selected else { return nil }
            if let id = loc.itermSession, id == selected.itermSession { return a.source }
            if let tty = loc.tty, tty == selected.tty { return a.source }
            return nil
        })
    }
}
