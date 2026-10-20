import Foundation

/// RSS headlines for the News card (news-headlines).
public enum News {
    public static let maxHeadlines = 8
    public static let maxHeadline = 120
    public static let maxBody = 512 * 1024

    public struct Preset: Equatable, Sendable {
        public let id: String
        public let name: String
        public let url: URL
        public let source: String
    }

    public static let presets = [
        Preset(id: "skyHome", name: "Sky News Home", url: URL(string: "https://feeds.skynews.com/feeds/rss/home.xml")!, source: "Sky News"),
        Preset(id: "skyWorld", name: "Sky News World", url: URL(string: "https://feeds.skynews.com/feeds/rss/world.xml")!, source: "Sky News"),
        Preset(id: "bbc", name: "BBC News", url: URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!, source: "BBC News"),
    ]
    public static let defaultPreset = presets[0]

    public struct Feed: Equatable, Sendable {
        public var title: String
        public var items: [(title: String, published: Date?)]

        public static func == (a: Feed, b: Feed) -> Bool {
            a.title == b.title && a.items.map(\.title) == b.items.map(\.title) && a.items.map(\.published) == b.items.map(\.published)
        }
    }

    /// Accepts only https URLs.
    public static func customURL(_ s: String) -> URL? {
        guard let u = URL(string: s.trimmingCharacters(in: .whitespaces)), u.scheme?.lowercased() == "https", u.host != nil else { return nil }
        return u
    }

    /// Parses an RSS 2.0 feed: the channel title and the first 8 items with a non-empty title.
    /// Returns nil for anything that is not RSS (Atom, HTML, broken XML).
    public static func parse(_ data: Data) -> Feed? {
        let p = RSSParser()
        let x = XMLParser(data: data)
        x.delegate = p
        guard x.parse(), p.isRSS else { return nil }
        return Feed(title: Feeds.collapse(p.channelTitle), items: Array(p.items.prefix(maxHeadlines)))
    }

    /// The source shown for a custom feed: the channel title after its last " | " or " - ".
    public static func sourceName(channelTitle: String) -> String {
        var s = channelTitle
        for sep in [" | ", " - "] {
            if let r = s.range(of: sep, options: .backwards) { s = String(s[r.upperBound...]) }
        }
        return Feeds.trim(s.trimmingCharacters(in: .whitespaces), maxBytes: Feeds.maxSource)
    }

    /// The watch's items for a parsed feed.
    public static func items(_ f: Feed, source: String) -> [FeedItem] {
        f.items.map {
            FeedItem(stamp: $0.published.map { UInt32($0.timeIntervalSince1970) } ?? 0,
                     source: source, text: Feeds.trim($0.title, maxBytes: maxHeadline))
        }
    }

    static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "dd MMM yyyy HH:mm:ss Z"] {
            f.dateFormat = fmt
            if let d = f.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
        }
        return nil
    }
}

private final class RSSParser: NSObject, XMLParserDelegate {
    var isRSS = false
    var channelTitle = ""
    var items: [(title: String, published: Date?)] = []
    private var path: [String] = []
    private var text = ""
    private var itemTitle = ""
    private var itemDate: Date?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if path.isEmpty { isRSS = name == "rss" }
        if !isRSS { parser.abortParsing(); return }
        path.append(name)
        text = ""
        if name == "item" { itemTitle = ""; itemDate = nil }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) { text += s }

    func parser(_ parser: XMLParser, foundCDATA d: Data) { text += String(decoding: d, as: UTF8.self) }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let parent = path.dropLast().last
        if name == "title" && parent == "channel" { channelTitle = text }
        if name == "title" && parent == "item" { itemTitle = Feeds.collapse(Feeds.stripTags(text)) }
        if name == "pubDate" && parent == "item" { itemDate = News.date(text) }
        if name == "item" && !itemTitle.isEmpty { items.append((itemTitle, itemDate)) }
        path.removeLast()
        text = ""
    }
}
