import Foundation

/// Fresh daily content for the Fortune, Quote and On-this-day cards (fresh-daily-cards).
public enum DailyFeeds {
    public static let userAgent = "garminy-companion (https://github.com/williamthepoon/garminy)"
    public static let wikipediaSource = "Wikipedia"

    /// The Wikimedia featured feed for a local date: one request gives "Did you know" and on-this-day.
    public static func featuredURL(year: Int, month: Int, day: Int) -> URL {
        URL(string: String(format: "https://api.wikimedia.org/feed/v1/wikipedia/en/featured/%04d/%02d/%02d", year, month, day))!
    }

    public static let jokeURL = URL(string: "https://icanhazdadjoke.com/")!

    public struct Featured: Equatable, Sendable {
        public var facts: [String]
        public var events: [(year: Int, text: String)]

        public static func == (a: Featured, b: Featured) -> Bool {
            a.facts == b.facts && a.events.map(\.year) == b.events.map(\.year) && a.events.map(\.text) == b.events.map(\.text)
        }
    }

    private struct FeaturedJSON: Decodable {
        struct Item: Decodable { let text: String? }
        struct Event: Decodable { let text: String?; let year: Int? }
        let dyk: [Item]?
        let onthisday: [Event]?
    }

    /// Parses the featured feed. Either part may be missing; nil only for unreadable JSON.
    public static func parseFeatured(_ data: Data) -> Featured? {
        guard let f = try? JSONDecoder().decode(FeaturedJSON.self, from: data) else { return nil }
        let facts = (f.dyk ?? []).compactMap { $0.text.flatMap(fact) }
        let events = (f.onthisday ?? []).compactMap { e -> (Int, String)? in
            guard let y = e.year, let t = e.text.map(clean), !t.isEmpty else { return nil }
            return (y, cutAtWord(t, maxBytes: Feeds.maxText, end: "…"))
        }
        return Featured(facts: facts, events: Array(events.prefix(Feeds.maxItems)))
    }

    /// "... that X?" → "Did you know that X?", cut to 140 bytes at a word. Nil when too little would be left.
    public static func fact(_ raw: String) -> String? {
        var t = clean(raw).replacingOccurrences(of: " (pictured)", with: "")
        guard let r = t.range(of: "that ") , t.distance(from: t.startIndex, to: r.lowerBound) <= 4 else { return nil }
        t = "Did you know that " + t[r.upperBound...]
        if t.utf8.count <= Feeds.maxText { return t }
        let body = t.hasSuffix("?") ? String(t.dropLast()) : t
        let cut = cutAtWord(body, maxBytes: Feeds.maxText, end: "…?")
        return cut.utf8.count * 10 >= t.utf8.count * 4 ? cut : nil
    }

    /// A joke from icanhazdadjoke's JSON: (id, text), or nil.
    public static func parseJoke(_ data: Data) -> (id: String, text: String)? {
        struct J: Decodable { let id: String; let joke: String }
        guard let j = try? JSONDecoder().decode(J.self, from: data) else { return nil }
        let t = clean(j.joke)
        guard !t.isEmpty, t.utf8.count <= Feeds.maxText else { return nil }
        return (j.id, t)
    }

    /// The fortune set: today's facts first, then jokes to fill up to 12, interleaved so jokes are spread out.
    public static func fortuneSet(facts: [String], jokes: [String]) -> [FeedItem] {
        let f = Array(facts.prefix(Feeds.maxItems))
        let j = Array(jokes.prefix(Feeds.maxItems - f.count))
        var out: [FeedItem] = []
        var fi = 0, ji = 0
        while fi < f.count || ji < j.count {
            // Roughly one joke every three items.
            if ji < j.count && (fi >= f.count || out.count % 3 == 2) {
                out.append(FeedItem(stamp: 0, source: "", text: j[ji])); ji += 1
            } else {
                out.append(FeedItem(stamp: 0, source: wikipediaSource, text: f[fi])); fi += 1
            }
        }
        return out
    }

    /// On-this-day events with the year in `stamp` (two's complement for BC years).
    public static func eventSet(_ events: [(year: Int, text: String)]) -> [FeedItem] {
        events.prefix(Feeds.maxItems).map {
            FeedItem(stamp: UInt32(bitPattern: Int32(clamping: $0.year)), source: wikipediaSource, text: $0.text)
        }
    }

    /// Strips tags, decodes the common entities and collapses whitespace.
    static func clean(_ s: String) -> String {
        var t = Feeds.stripTags(s)
        for (e, c) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] {
            t = t.replacingOccurrences(of: e, with: c)
        }
        return Feeds.collapse(t)
    }

    /// Cuts at the last whole word that fits `maxBytes` together with `end`.
    static func cutAtWord(_ s: String, maxBytes: Int, end: String) -> String {
        if s.utf8.count <= maxBytes { return s }
        var out = ""
        for w in s.split(separator: " ") {
            let next = out.isEmpty ? String(w) : out + " " + w
            if next.utf8.count + end.utf8.count > maxBytes { break }
            out = next
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: ",;:-–—")) + end
    }
}

/// Picks the day's quotes so none repeats within 30 days (fresh-daily-cards).
public struct QuotePicker: Sendable {
    public static let window: TimeInterval = 30 * 86400
    public static let perDay = 12

    /// Quote index → when it was last sent.
    public private(set) var history: [Int: Date]

    public init(history: [Int: Date] = [:]) { self.history = history }

    /// `perDay` indexes into a pool of `count`, none sent within the window, chosen with `rng`.
    public mutating func pick<G: RandomNumberGenerator>(count: Int, now: Date, rng: inout G) -> [Int] {
        history = history.filter { now.timeIntervalSince($0.value) < Self.window }
        var free = (0..<count).filter { history[$0] == nil }
        if free.count < Self.perDay {
            // Pool too small for the window: fall back to the least recently sent.
            free = (0..<count).sorted { (history[$0] ?? .distantPast) < (history[$1] ?? .distantPast) }
        }
        free.shuffle(using: &rng)
        let out = Array(free.prefix(Self.perDay))
        for i in out { history[i] = now }
        return out
    }
}

/// A small seeded generator so picks are testable.
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
