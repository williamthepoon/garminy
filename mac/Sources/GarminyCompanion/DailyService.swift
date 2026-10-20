import Foundation
import GarminyCore

/// Builds the day's quote, fortune and on-this-day sets (fresh-daily-cards). Sets are kept per local
/// date in Application Support, so a relaunch resends the same day's content instead of new picks.
final class DailyService: ObservableObject {
    static let wikiRetry: TimeInterval = 30 * 60
    static let maxWikiPerDay = 4
    static let maxJokesPerDay = 20

    struct Day: Codable {
        var date: String
        var revision = 0
        var quotes: [FeedItem] = []
        var facts: [String] = []
        var events: [FeedItem] = []
        var jokes: [String] = []
        var jokeIds: [String] = []
        var wikiDone = false
        var wikiAttempts = 0
        var jokeRequests = 0
        var lastWikiTry: Date?
    }

    @Published private(set) var status = "Waiting for the first build"
    private(set) var day: Day?
    private var timer: Timer?
    private var fetching = false
    var onUpdate: (() -> Void)?

    private static var file: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("garminy")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("daily.json")
    }

    func start() {
        if let d = try? Data(contentsOf: Self.file), let saved = try? JSONDecoder().decode(Day.self, from: d) { day = saved }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.check() }
    }

    func didWake() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in self?.check() }
    }

    // MARK: Sets for the watch

    /// The batch stamp: the Mac time one hour into the set's local day, plus a revision, so the
    /// watch can tell which date an on-this-day set belongs to.
    var batch: UInt32 {
        guard let day, let start = Self.formatter.date(from: day.date) else { return 0 }
        return UInt32(start.timeIntervalSince1970 + 3600) + UInt32(day.revision)
    }

    var quoteItems: [FeedItem] { day?.quotes ?? [] }
    var fortuneItems: [FeedItem] { day.map { DailyFeeds.fortuneSet(facts: $0.facts, jokes: $0.jokes) } ?? [] }
    var eventItems: [FeedItem] { day?.events ?? [] }

    // MARK: Building

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Starts a new day when the date changed, then fills in whatever is still missing.
    private func check() {
        let today = Self.formatter.string(from: Date())
        if day?.date != today {
            var d = Day(date: today)
            var picker = QuotePicker(history: loadHistory())
            var rng = SystemRandomNumberGenerator()
            d.quotes = picker.pick(count: QuotePool.all.count, now: Date(), rng: &rng).map {
                FeedItem(stamp: 0, source: "", text: QuotePool.all[$0][0])
            }
            saveHistory(picker.history)
            day = d
            save()
            Log.info("daily: new day \(today), \(d.quotes.count) quotes")
            onUpdate?()
        }
        fetchMissing()
    }

    private func fetchMissing() {
        guard !fetching, let d = day else { return }
        let wikiDue = !d.wikiDone && d.wikiAttempts < Self.maxWikiPerDay
            && Date().timeIntervalSince(d.lastWikiTry ?? .distantPast) >= Self.wikiRetry
        let jokesWanted = Feeds.maxItems - min(d.facts.count, Feeds.maxItems) - d.jokes.count
        if wikiDue {
            fetchWiki()
        } else if d.wikiDone || d.wikiAttempts > 0, jokesWanted > 0, d.jokeRequests < Self.maxJokesPerDay {
            fetchJoke()
        }
    }

    private func request(_ url: URL, _ done: @escaping (Data?) -> Void) {
        var req = URLRequest(url: url)
        req.setValue(DailyFeeds.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        fetching = true
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { [weak self] in
                self?.fetching = false
                done(ok ? data : nil)
            }
        }.resume()
    }

    private func fetchWiki() {
        guard var d = day, let date = Self.formatter.date(from: d.date) else { return }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        d.wikiAttempts += 1
        d.lastWikiTry = Date()
        day = d
        request(DailyFeeds.featuredURL(year: c.year!, month: c.month!, day: c.day!)) { [weak self] data in
            guard let self, var d = self.day else { return }
            if let data, let f = DailyFeeds.parseFeatured(data) {
                d.facts = f.facts
                d.events = DailyFeeds.eventSet(f.events)
                d.wikiDone = true
                d.revision += 1
                self.status = "Wikipedia: \(f.facts.count) facts, \(f.events.count) events"
                Log.info("daily: \(self.status)")
                self.day = d
                self.save()
                self.onUpdate?()
            } else {
                self.status = "Wikipedia failed; retrying in 30 min"
                Log.info("daily: \(self.status)")
                self.save()
            }
            self.fetchMissing()
        }
    }

    private func fetchJoke() {
        guard var d = day else { return }
        d.jokeRequests += 1
        day = d
        request(DailyFeeds.jokeURL) { [weak self] data in
            guard let self, var d = self.day else { return }
            if let data, let j = DailyFeeds.parseJoke(data), !d.jokeIds.contains(j.id) {
                d.jokes.append(j.text)
                d.jokeIds.append(j.id)
            }
            self.day = d
            let wanted = Feeds.maxItems - min(d.facts.count, Feeds.maxItems) - d.jokes.count
            if wanted <= 0 || d.jokeRequests >= Self.maxJokesPerDay {
                // Set complete (or out of budget): send it.
                self.day?.revision += 1
                self.save()
                Log.info("daily: fortune set \(d.facts.count) facts + \(d.jokes.count) jokes")
                self.onUpdate?()
            } else {
                self.save()
                self.fetchMissing()
            }
        }
    }

    // MARK: Storage

    private func save() {
        if let day, let data = try? JSONEncoder().encode(day) { try? data.write(to: Self.file, options: .atomic) }
    }

    private func loadHistory() -> [Int: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: "quoteHistory") as? [String: Double] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, Date(timeIntervalSince1970: v)) } })
    }

    private func saveHistory(_ h: [Int: Date]) {
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: h.map { (String($0.key), $0.value.timeIntervalSince1970) }), forKey: "quoteHistory")
    }
}
