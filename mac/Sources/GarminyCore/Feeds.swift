import Foundation

/// One text item for a watch card (mac-content-feeds).
public struct FeedItem: Equatable, Codable, Sendable {
    /// Mac time for news, a channel-defined number otherwise; 0 = none.
    public var stamp: UInt32
    public var source: String
    public var text: String

    public init(stamp: UInt32, source: String, text: String) {
        self.stamp = stamp; self.source = source; self.text = text
    }
}

/// Feed channels. Unknown channels are ignored by the watch.
public enum FeedChannel: UInt8, CaseIterable, Sendable {
    case news = 0
    // Reserved for fresh-daily-cards.
    case quote = 1, fortune = 2, onThisDay = 3
}

public enum Feeds {
    public static let maxItems = 12
    public static let maxText = 140
    public static let maxSource = 20

    /// Cuts to at most `maxBytes` UTF-8 bytes on a character boundary, ending in "…" when cut.
    public static func trim(_ s: String, maxBytes: Int) -> String {
        if s.utf8.count <= maxBytes { return s }
        let ellipsis = "…"
        var out = ""
        for ch in s {
            if out.utf8.count + String(ch).utf8.count + ellipsis.utf8.count > maxBytes { break }
            out.append(ch)
        }
        return out.trimmingCharacters(in: .whitespaces) + ellipsis
    }

    /// Drops HTML tags left inside CDATA.
    public static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
    }

    /// Collapses runs of whitespace (including newlines) to single spaces.
    public static func collapse(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

/// Chooses which message goes to the watch next: anything on the main queue first, feed items only
/// when it is empty. Whole messages only, since the watch reassembles one message at a time.
public struct Outbox: Sendable {
    public private(set) var main: [[Data]] = []
    /// Feed messages tagged with channel and batch, so a newer set can replace an unsent older one.
    public private(set) var feed: [(channel: UInt8, batch: UInt32, frames: [Data])] = []

    public init() {}

    public mutating func push(_ frames: [Data]) { main.append(frames) }

    public mutating func pushFeed(channel: UInt8, batch: UInt32, frames: [Data]) {
        feed.removeAll { $0.channel == channel && $0.batch != batch }
        feed.append((channel, batch, frames))
    }

    /// The next whole message to send, or nil.
    public mutating func next() -> [Data]? {
        if !main.isEmpty { return main.removeFirst() }
        if !feed.isEmpty { return feed.removeFirst().frames }
        return nil
    }

    public mutating func clear() { main = []; feed = [] }
}
