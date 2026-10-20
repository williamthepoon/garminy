import Foundation

// Wire protocol shared with the watch (source/companion/Proto.mc).
// Frame: [type][msgId][part<<4 | total] + up to 17 payload bytes, at most 20 bytes in all.
// Layouts and test vectors: mac/Tests/vectors.md.

public enum SessionState: UInt8, Sendable, Comparable {
    case working = 0, needsYou = 1, done = 2, error = 3

    /// Lower is more urgent.
    public var urgency: Int {
        switch self {
        case .needsYou: return 0
        case .error: return 1
        case .working: return 2
        case .done: return 3
        }
    }

    public static func < (a: SessionState, b: SessionState) -> Bool { a.urgency < b.urgency }
}

public enum AlertKind: UInt8, Sendable, Comparable {
    case needsYou = 0, failed = 1, done = 2

    public static func < (a: AlertKind, b: AlertKind) -> Bool { a.rawValue < b.rawValue }
}

public struct WireSession: Equatable, Sendable {
    public var state: SessionState
    public var minutes: UInt16
    public var label: String

    public init(state: SessionState, minutes: UInt16, label: String) {
        self.state = state; self.minutes = minutes; self.label = label
    }
}

public struct WireAlert: Equatable, Sendable {
    public var id: UInt8
    public var kind: AlertKind
    public var buzz: Bool
    public var label: String
    public var detail: String
    /// Tapping it on the watch can open the session that raised it.
    public var openable: Bool

    public init(id: UInt8, kind: AlertKind, buzz: Bool, label: String, detail: String, openable: Bool = false) {
        self.id = id; self.kind = kind; self.buzz = buzz; self.label = label; self.detail = detail
        self.openable = openable
    }
}

public struct WireDay: Equatable, Sendable {
    public var high: Int8
    public var low: Int8
    public var condition: UInt8

    public init(high: Int8, low: Int8, condition: UInt8) {
        self.high = high; self.low = low; self.condition = condition
    }
}

public struct WireWeather: Equatable, Sendable {
    public var observed: UInt32
    public var temperature: Int8
    public var condition: UInt8
    public var today: WireDay
    public var tomorrow: WireDay
    public var hourlyBase: UInt32
    /// 12 hourly precipitation chances starting at hourlyBase; 255 = unknown.
    public var chances: [UInt8]

    public init(observed: UInt32, temperature: Int8, condition: UInt8, today: WireDay, tomorrow: WireDay, hourlyBase: UInt32, chances: [UInt8]) {
        self.observed = observed; self.temperature = temperature; self.condition = condition
        self.today = today; self.tomorrow = tomorrow; self.hourlyBase = hourlyBase; self.chances = chances
    }
}

public struct WireSettings: Equatable, Sendable {
    public var changedAt: UInt32
    /// Bit 0 Agents, 1 Fortune, 2 Quote, 3 Umbrella, 4 Weather, 5 Daylight, 6 Moon, 7 World clock, 8 On this day.
    public var cards: UInt16
    public var interval: UInt8
    public var cities: [Int8]
    public var units: UInt8
    public var backlight: UInt8
    public var companion: Bool
    /// What a buzz does while the watch charges: 0 nothing, 1 beep, 2 light, 3 beep and light.
    public var chargerSignal: UInt8
    /// 0 soft, 1 chime, 2 standard.
    public var beepSound: UInt8
    /// Backlight off from quietStart up to quietEnd (whole hours, wrapping past midnight).
    public var quietHours: Bool
    public var quietStart: UInt8
    public var quietEnd: UInt8

    public init(changedAt: UInt32, cards: UInt16, interval: UInt8, cities: [Int8], units: UInt8, backlight: UInt8, companion: Bool,
                chargerSignal: UInt8 = 1, beepSound: UInt8 = 0, quietHours: Bool = true, quietStart: UInt8 = 18, quietEnd: UInt8 = 9) {
        self.changedAt = changedAt; self.cards = cards; self.interval = interval; self.cities = cities
        self.units = units; self.backlight = backlight; self.companion = companion
        self.chargerSignal = chargerSignal; self.beepSound = beepSound
        self.quietHours = quietHours; self.quietStart = quietStart; self.quietEnd = quietEnd
    }
}

/// Mac → watch messages.
public enum MacMessage: Equatable, Sendable {
    case helloReply(version: UInt8, macTime: UInt32)
    case sessions([WireSession], hidden: UInt8)
    case alerts([WireAlert], total: UInt8)
    case buzz(id: UInt8)
    /// Play an alert kind's signal now (Test on watch).
    case testSignal(kind: AlertKind)
    case weather(WireWeather)
    case location(lat: Double, lon: Double)
    case settings(WireSettings)
    case snapshotEnd
    case heartbeat
    /// One item of a channel's set (mac-content-feeds).
    case feed(channel: UInt8, batch: UInt32, index: UInt8, count: UInt8, item: FeedItem)
}

/// Watch → Mac messages.
public enum WatchMessage: Equatable, Sendable {
    case hello(version: UInt8)
    case ack(id: UInt8)
    /// Acknowledge and open the session that raised the alert (a live tap on a needs-you alert).
    case open(id: UInt8)
    case settings(WireSettings)
}

public enum Wire {
    public static let maxFrame = 20
    public static let maxPayloadPerFrame = 17
    public static let maxParts = 15
    public static let maxSessions = 4
    public static let maxAlerts = 5
    public static let maxSessionLabel = 16
    public static let maxAlertLabel = 24
    public static let maxAlertDetail = 20

    enum Kind: UInt8 {
        case helloReply = 0x01, sessions = 0x02, alerts = 0x03, buzz = 0x04, weather = 0x05
        case location = 0x06, settings = 0x07, snapshotEnd = 0x08, heartbeat = 0x09, testSignal = 0x0A, feed = 0x0B
        case hello = 0x41, ack = 0x42, watchSettings = 0x43, open = 0x44
    }

    // MARK: Framing

    /// Splits a payload into frames. Payloads over 255 bytes are cut to fit.
    public static func frames(type: UInt8, msgId: UInt8, payload: Data) -> [Data] {
        let bytes = [UInt8](payload.prefix(maxPayloadPerFrame * maxParts))
        var chunks: [[UInt8]] = stride(from: 0, to: bytes.count, by: maxPayloadPerFrame).map {
            Array(bytes[$0..<min($0 + maxPayloadPerFrame, bytes.count)])
        }
        if chunks.isEmpty { chunks = [[]] }
        let total = UInt8(chunks.count)
        return chunks.enumerated().map { i, c in Data([type, msgId, UInt8(i) << 4 | total] + c) }
    }

    public static func encode(_ m: MacMessage, msgId: UInt8) -> [Data] {
        var p = Data()
        let kind: Kind
        switch m {
        case let .helloReply(version, macTime):
            kind = .helloReply; p.append(version); p.u32(macTime)
        case let .sessions(list, hidden):
            kind = .sessions
            let shown = Array(list.prefix(maxSessions))
            p.append(UInt8(shown.count))
            p.append(UInt8(min(255, Int(hidden) + list.count - shown.count)))
            for s in shown { p.append(s.state.rawValue); p.u16(s.minutes); p.str(s.label, max: maxSessionLabel) }
        case let .alerts(list, total):
            kind = .alerts
            let shown = Array(list.prefix(maxAlerts))
            p.append(max(total, UInt8(shown.count)))
            p.append(UInt8(shown.count))
            for a in shown {
                p.append(a.id); p.append(a.kind.rawValue); p.append((a.buzz ? 1 : 0) | (a.openable ? 2 : 0))
                p.str(a.label, max: maxAlertLabel); p.str(a.detail, max: maxAlertDetail)
            }
        case let .buzz(id):
            kind = .buzz; p.append(id)
        case let .testSignal(k):
            kind = .testSignal; p.append(k.rawValue)
        case let .weather(w):
            kind = .weather
            p.u32(w.observed); p.i8(w.temperature); p.append(w.condition)
            for d in [w.today, w.tomorrow] { p.i8(d.high); p.i8(d.low); p.append(d.condition) }
            p.u32(w.hourlyBase)
            let c = Array(w.chances.prefix(12))
            p.append(contentsOf: c + Array(repeating: 255, count: 12 - c.count))
        case let .location(lat, lon):
            kind = .location; p.i16(hundredths(lat)); p.i16(hundredths(lon))
        case let .settings(s):
            kind = .settings; p.settings(s)
        case .snapshotEnd:
            kind = .snapshotEnd
        case .heartbeat:
            kind = .heartbeat
        case let .feed(channel, batch, index, count, item):
            kind = .feed
            p.append(channel); p.u32(batch); p.append(index); p.append(count); p.u32(item.stamp)
            p.str(item.source, max: Feeds.maxSource); p.str(item.text, max: Feeds.maxText)
        }
        return frames(type: kind.rawValue, msgId: msgId, payload: p)
    }

    public static func encode(_ m: WatchMessage, msgId: UInt8) -> [Data] {
        var p = Data()
        let kind: Kind
        switch m {
        case let .hello(v): kind = .hello; p.append(v)
        case let .ack(id): kind = .ack; p.append(id)
        case let .open(id): kind = .open; p.append(id)
        case let .settings(s): kind = .watchSettings; p.settings(s)
        }
        return frames(type: kind.rawValue, msgId: msgId, payload: p)
    }

    static func hundredths(_ deg: Double) -> Int16 {
        Int16(clamping: Int((deg * 100).rounded()))
    }

    // MARK: Decoding

    /// Decodes a complete watch → Mac payload.
    public static func decodeWatch(type: UInt8, payload: Data) -> WatchMessage? {
        var r = Reader(payload)
        switch Kind(rawValue: type) {
        case .hello: return r.u8().map { .hello(version: $0) }
        case .ack: return r.u8().map { .ack(id: $0) }
        case .open: return r.u8().map { .open(id: $0) }
        case .watchSettings: return r.settings().map { .settings($0) }
        default: return nil
        }
    }

    /// Decodes a complete Mac → watch payload (used by tests and the debug log).
    public static func decodeMac(type: UInt8, payload: Data) -> MacMessage? {
        var r = Reader(payload)
        switch Kind(rawValue: type) {
        case .helloReply:
            guard let v = r.u8(), let t = r.u32() else { return nil }
            return .helloReply(version: v, macTime: t)
        case .sessions:
            guard let n = r.u8(), let hidden = r.u8() else { return nil }
            var list: [WireSession] = []
            for _ in 0..<n {
                guard let s = r.u8().flatMap(SessionState.init), let m = r.u16(), let l = r.str() else { return nil }
                list.append(WireSession(state: s, minutes: m, label: l))
            }
            return .sessions(list, hidden: hidden)
        case .alerts:
            guard let total = r.u8(), let n = r.u8() else { return nil }
            var list: [WireAlert] = []
            for _ in 0..<n {
                guard let id = r.u8(), let k = r.u8().flatMap(AlertKind.init), let b = r.u8(),
                      let l = r.str(), let d = r.str() else { return nil }
                list.append(WireAlert(id: id, kind: k, buzz: b & 1 != 0, label: l, detail: d, openable: b & 2 != 0))
            }
            return .alerts(list, total: total)
        case .buzz:
            return r.u8().map { .buzz(id: $0) }
        case .testSignal:
            return r.u8().flatMap(AlertKind.init).map { .testSignal(kind: $0) }
        case .weather:
            guard let obs = r.u32(), let t = r.i8(), let c = r.u8(),
                  let th = r.i8(), let tl = r.i8(), let tc = r.u8(),
                  let mh = r.i8(), let ml = r.i8(), let mc = r.u8(),
                  let base = r.u32(), let ch = r.bytes(12) else { return nil }
            return .weather(WireWeather(observed: obs, temperature: t, condition: c,
                                        today: WireDay(high: th, low: tl, condition: tc),
                                        tomorrow: WireDay(high: mh, low: ml, condition: mc),
                                        hourlyBase: base, chances: ch))
        case .location:
            guard let la = r.i16(), let lo = r.i16() else { return nil }
            return .location(lat: Double(la) / 100, lon: Double(lo) / 100)
        case .settings:
            return r.settings().map { .settings($0) }
        case .snapshotEnd: return .snapshotEnd
        case .heartbeat: return .heartbeat
        case .feed:
            guard let ch = r.u8(), let b = r.u32(), let i = r.u8(), let n = r.u8(), let st = r.u32(),
                  let src = r.str(), let t = r.str() else { return nil }
            return .feed(channel: ch, batch: b, index: i, count: n, item: FeedItem(stamp: st, source: src, text: t))
        default: return nil
        }
    }
}

/// Reassembles multi-part messages. A message is dropped when a part is missing,
/// out of order, or a different msgId starts first.
public struct Reassembler: Sendable {
    private var type: UInt8 = 0
    private var msgId: UInt8 = 0
    private var next = 0
    private var total = 0
    private var buffer = Data()

    public init() {}

    /// Feeds one frame; returns (type, payload) once a message is complete.
    public mutating func feed(_ frame: Data) -> (type: UInt8, payload: Data)? {
        let f = [UInt8](frame)
        guard f.count >= 3, f.count <= Wire.maxFrame else { reset(); return nil }
        let part = Int(f[2] >> 4), count = Int(f[2] & 0x0F)
        guard count >= 1, part < count else { reset(); return nil }
        if part == 0 {
            type = f[0]; msgId = f[1]; total = count; next = 0; buffer = Data()
        } else if f[0] != type || f[1] != msgId || count != total || part != next {
            reset(); return nil
        }
        buffer.append(contentsOf: f[3...])
        next = part + 1
        if next == total {
            let out = (type, buffer)
            reset()
            return out
        }
        return nil
    }

    private mutating func reset() { total = 0; next = 0; buffer = Data() }
}

// MARK: - Byte helpers

extension Data {
    mutating func u16(_ v: UInt16) { append(contentsOf: [UInt8(v >> 8), UInt8(v & 0xFF)]) }
    mutating func u32(_ v: UInt32) { append(contentsOf: [24, 16, 8, 0].map { UInt8((v >> $0) & 0xFF) }) }
    mutating func i8(_ v: Int8) { append(UInt8(bitPattern: v)) }
    mutating func i16(_ v: Int16) { u16(UInt16(bitPattern: v)) }

    /// Length-prefixed UTF-8, cut to `max` bytes on a character boundary.
    mutating func str(_ s: String, max: Int) {
        var out = Data()
        for ch in s {
            let b = Data(String(ch).utf8)
            if out.count + b.count > max { break }
            out.append(b)
        }
        append(UInt8(out.count)); append(out)
    }

    mutating func settings(_ s: WireSettings) {
        u32(s.changedAt); u16(s.cards); append(s.interval)
        let c = Array(s.cities.prefix(3)) + Array(repeating: Int8(-1), count: Swift.max(0, 3 - s.cities.count))
        c.forEach { i8($0) }
        append(s.units); append(s.backlight); append(s.companion ? 1 : 0)
        append(s.chargerSignal); append(s.beepSound)
        append(s.quietHours ? 1 : 0); append(s.quietStart); append(s.quietEnd)
    }
}

struct Reader {
    let d: [UInt8]
    var i = 0
    init(_ data: Data) { d = [UInt8](data) }

    mutating func u8() -> UInt8? { guard i < d.count else { return nil }; defer { i += 1 }; return d[i] }
    mutating func i8() -> Int8? { u8().map { Int8(bitPattern: $0) } }
    mutating func u16() -> UInt16? {
        guard let a = u8(), let b = u8() else { return nil }
        return UInt16(a) << 8 | UInt16(b)
    }
    mutating func i16() -> Int16? { u16().map { Int16(bitPattern: $0) } }
    mutating func u32() -> UInt32? {
        guard let a = u16(), let b = u16() else { return nil }
        return UInt32(a) << 16 | UInt32(b)
    }
    mutating func bytes(_ n: Int) -> [UInt8]? {
        guard i + n <= d.count else { return nil }
        defer { i += n }
        return Array(d[i..<i + n])
    }
    mutating func str() -> String? {
        guard let n = u8(), let b = bytes(Int(n)) else { return nil }
        return String(decoding: b, as: UTF8.self)
    }
    mutating func settings() -> WireSettings? {
        guard let at = u32(), let cards = u16(), let iv = u8(),
              let c1 = i8(), let c2 = i8(), let c3 = i8(),
              let un = u8(), let bl = u8(), let co = u8() else { return nil }
        // Added later: a 13- or 15-byte payload from an older side gets the defaults.
        return WireSettings(changedAt: at, cards: cards, interval: iv, cities: [c1, c2, c3],
                            units: un, backlight: bl, companion: co != 0, chargerSignal: u8() ?? 1, beepSound: u8() ?? 0,
                            quietHours: (u8() ?? 1) != 0, quietStart: u8() ?? 18, quietEnd: u8() ?? 9)
    }
}
