import Foundation
import GarminyCore

/// Fetches the chosen RSS feed for the News card (news-headlines).
final class NewsService: ObservableObject {
    static let refreshEvery: TimeInterval = 15 * 60
    static let retryAfter: TimeInterval = 5 * 60

    @Published private(set) var status = "Waiting for the first fetch"
    /// A preset id from `News.presets`, or "custom".
    @Published private(set) var choice: String
    @Published private(set) var customURL: String
    @Published private(set) var customError: String?
    /// The current set and its batch stamp (Mac time it was built).
    private(set) var items: [FeedItem] = []
    private(set) var batch: UInt32 = 0
    private var timer: Timer?
    var onUpdate: (() -> Void)?

    init() {
        let d = UserDefaults.standard
        choice = d.string(forKey: "newsFeed") ?? News.defaultPreset.id
        customURL = d.string(forKey: "newsFeedURL") ?? ""
    }

    func start() { fetch() }

    func didWake() { schedule(after: 30) }

    /// The feed URL and the source name to show, for the current choice.
    private var target: (url: URL, source: String?)? {
        if choice == "custom" { return News.customURL(customURL).map { ($0, nil) } }
        let p = News.presets.first { $0.id == choice } ?? News.defaultPreset
        return (p.url, p.source)
    }

    func choose(_ id: String) {
        guard id != choice else { return }
        choice = id
        UserDefaults.standard.set(id, forKey: "newsFeed")
        if id != "custom" || News.customURL(customURL) != nil { fetch() }
    }

    /// Sets the custom feed URL. Non-HTTPS URLs are refused and the previous feed is kept.
    func setCustomURL(_ s: String) {
        guard News.customURL(s) != nil else {
            customError = "The feed URL must start with https://"
            return
        }
        customError = nil
        customURL = s
        UserDefaults.standard.set(s, forKey: "newsFeedURL")
        if choice == "custom" { fetch() }
    }

    private func fetch() {
        guard let t = target else { return }
        var req = URLRequest(url: t.url)
        req.setValue("garminy-companion (https://github.com/williamthepoon/garminy)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            let code = (resp as? HTTPURLResponse)?.statusCode
            DispatchQueue.main.async { self?.finish(data: data, code: code, err: err, source: t.source) }
        }.resume()
    }

    private func finish(data: Data?, code: Int?, err: Error?, source: String?) {
        let failure: String?
        if let err {
            failure = err.localizedDescription
        } else if code != 200 {
            failure = "HTTP \(code ?? 0)"
        } else if let data, data.count > News.maxBody {
            failure = "feed is larger than 512 KB"
        } else if let data, let feed = News.parse(data), !feed.items.isEmpty {
            let fresh = News.items(feed, source: source ?? News.sourceName(channelTitle: feed.title))
            let f = DateFormatter(); f.timeStyle = .short
            status = "Updated \(f.string(from: Date()))"
            if fresh != items {
                items = fresh
                batch = UInt32(Date().timeIntervalSince1970)
                Log.info("news updated (\(fresh.count))")
                onUpdate?()
            }
            schedule(after: Self.refreshEvery)
            return
        } else {
            failure = "not an RSS feed"
        }
        status = "News failed: \(failure ?? "?"); retrying in 5 min"
        Log.info(status)
        schedule(after: Self.retryAfter)
    }

    private func schedule(after s: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: s, repeats: false) { [weak self] _ in self?.fetch() }
    }
}
