import AppKit
import Foundation
import GarminyCore
import ServiceManagement

/// Ties the sources (hooks, shell, presence) to the alert queue and the watch link.
final class AppModel: ObservableObject {
    @Published private(set) var watchConnected = false
    @Published private(set) var sessions: [SessionTracker.Session] = []
    @Published private(set) var alerts: [Alert] = []
    @Published private(set) var bluetoothNote: String?
    @Published var keepAwakeEnabled: Bool {
        didSet { UserDefaults.standard.set(keepAwakeEnabled, forKey: "keepAwake"); updateKeepAwake() }
    }
    @Published var buzzMode: BuzzMode {
        didSet { UserDefaults.standard.set(buzzMode.rawValue, forKey: "buzzMode") }
    }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    let ble = BLEPeripheral()
    let presence = PresenceMonitor()
    let keepAwake = KeepAwake()
    let socket = SocketServer()
    let weather = WeatherService()
    let opener = SessionOpener()
    @Published private(set) var settings = SettingsModel(AppModel.loadSettings())
    private var tracker = SessionTracker()
    private var commands = CommandTracker()
    private var queue = AlertQueue()
    private var tick: Timer?
    private var focusTick: Timer?
    private var lastSessionsWire: [WireSession] = []
    /// Host whose selected tab is being read; its alerts' delayed buzzes wait (always-buzz).
    private var tabCheckHost: String?
    /// Delayed buzzes that came due while the watch was disconnected, sent after the next snapshot.
    private var buzzOnReconnect: Set<UInt8> = []
    /// Opens the Watch settings window (set by the app delegate).
    var showSettings: (() -> Void)?

    init() {
        keepAwakeEnabled = UserDefaults.standard.object(forKey: "keepAwake") as? Bool ?? true
        buzzMode = BuzzMode(rawValue: UserDefaults.standard.integer(forKey: "buzzMode")) ?? .always
    }

    func start() {
        Log.info("---- garminy companion start, protocol \(protocolVersion) ----")
        ProcessInfo.processInfo.disableAutomaticTermination("garminy companion")
        _ = ProcessInfo.processInfo.beginActivity(options: [.userInitiated], reason: "garminy watch link")
        ble.onConnectionChange = { [weak self] c in self?.watchConnected = c }
        ble.onStateChange = { [weak self] in self?.refreshBluetoothNote() }
        ble.onMessage = { [weak self] m in self?.handle(m) }
        ble.start()
        socket.onEvent = { [weak self] e in self?.handle(e) }
        socket.log = { Log.info($0) }
        do { try socket.start() } catch { Log.info("socket failed: \(error)") }
        presence.onChange = { [weak self] in self?.periodic() }
        presence.onWake = { [weak self] in
            Log.info("mac woke")
            self?.ble.advertise()
            self?.weather.didWake()
        }
        weather.onUpdate = { [weak self] in self?.sendWeather() }
        weather.start()
        presence.onSleep = { Log.info("mac will sleep") }
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.periodic() }
        focusTick = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.sendDueBuzzes()
            self?.clearFocused()
        }
    }

    // MARK: Watch messages

    func handle(_ m: WatchMessage) {
        switch m {
        case .hello(let v):
            Log.info("watch hello, protocol \(v)")
            sendSnapshot()
        case .ack(let id):
            queue.acknowledge(id: id)
            publish()
        case .open(let id):
            // Look the alert up before acknowledging removes it.
            let a = queue.alerts.first { $0.id == id }
            queue.acknowledge(id: id)
            publish()
            if let a, a.openable, let loc = tracker.location(source: a.source) {
                opener.open(loc, label: a.label)
            } else {
                Log.info("open \(id): nothing to open")
            }
        case .settings(let w):
            if settings.adoptFromWatch(w) {
                saveSettings()
                Log.info("adopted watch settings")
            }
        }
    }

    // MARK: Weather and settings

    func sendWeather() {
        guard let w = weather.latest, let c = weather.coordinate else { return }
        ble.send(.weather(w))
        ble.send(.location(lat: c.lat, lon: c.lon))
    }

    /// A change made in the Watch settings window.
    func editSettings(_ change: (inout WireSettings) -> Void) {
        settings.edit(now: Date(), change)
        saveSettings()
        ble.send(.settings(settings.value))
    }

    /// Test on watch: plays a needs-you signal with the current settings.
    func testSignal() {
        ble.send(.settings(settings.value))
        ble.send(.testSignal(kind: .needsYou))
    }

    func setCard(_ i: Int, _ on: Bool) {
        settings.setCard(i, on, now: Date())
        saveSettings()
        ble.send(.settings(settings.value))
    }

    static func loadSettings() -> WireSettings {
        guard let d = UserDefaults.standard.dictionary(forKey: "watchSettings") else { return SettingsModel.defaults }
        func n(_ k: String) -> Int { d[k] as? Int ?? 0 }
        return WireSettings(changedAt: UInt32(n("changedAt")), cards: UInt16(n("cards")), interval: UInt8(n("interval")),
                            cities: (d["cities"] as? [Int] ?? [0, 33, 9]).map { Int8($0) }, units: UInt8(n("units")),
                            backlight: UInt8(n("backlight")), companion: d["companion"] as? Bool ?? true,
                            chargerSignal: UInt8(d["chargerSignal"] as? Int ?? 1), beepSound: UInt8(n("beepSound")),
                            quietHours: d["quietHours"] as? Bool ?? true, quietStart: UInt8(d["quietStart"] as? Int ?? 18),
                            quietEnd: UInt8(d["quietEnd"] as? Int ?? 9))
    }

    func saveSettings() {
        let v = settings.value
        UserDefaults.standard.set(["changedAt": Int(v.changedAt), "cards": Int(v.cards), "interval": Int(v.interval),
                                   "cities": v.cities.map { Int($0) }, "units": Int(v.units), "backlight": Int(v.backlight),
                                   "companion": v.companion, "chargerSignal": Int(v.chargerSignal), "beepSound": Int(v.beepSound),
                                   "quietHours": v.quietHours, "quietStart": Int(v.quietStart), "quietEnd": Int(v.quietEnd)], forKey: "watchSettings")
    }

    func sendSnapshot() {
        ble.send(.helloReply(version: protocolVersion, macTime: UInt32(Date().timeIntervalSince1970)))
        lastSessionsWire = []
        publish(force: true)
        sendWeather()
        ble.send(.settings(settings.value))
        for id in buzzOnReconnect where queue.alerts.contains(where: { $0.id == id }) {
            ble.send(.buzz(id: id))
            Log.info("buzz \(id) (late, after reconnect)")
        }
        buzzOnReconnect = []
        ble.send(.snapshotEnd)
    }

    // MARK: Hook events

    func handle(_ e: HookEvent) {
        Log.info("event \(e.src) \(e.event ?? e.phase ?? "?") \(e.tool ?? e.cmd ?? "")")
        let now = Date()
        var effects = tracker.apply(e, now: now)
        if let c = commands.apply(e, now: now) { effects.append(c) }
        let p = presence.snapshot
        for fx in effects {
            switch fx {
            case let .raise(kind, label, detail, source, term):
                // Replace an older alert of the same kind from the same source.
                queue.resolve(source: source, kinds: [kind])
                var a = queue.add(kind: kind, label: label, detail: detail, source: source, term: term, now: now)
                a.openable = tracker.location(source: source)?.app != nil
                queue.update(a)
                let decision = PresencePolicy.buzzOnRaise(term: term, presence: p, mode: buzzMode)
                switch decision {
                case .now:
                    a.buzzOnShow = true; a.buzzes = 1; a.lastBuzz = now
                    Log.info("buzz \(a.id) (\(buzzMode.title): now)")
                case let .after(d):
                    a.buzzAt = now.addingTimeInterval(d)
                    Log.info("buzz \(a.id) (\(buzzMode.title): in \(Int(d)) s)")
                case .never:
                    Log.info("buzz \(a.id) (\(buzzMode.title): silent)")
                }
                queue.update(a)
            case let .resolve(source, kinds):
                queue.resolve(source: source, kinds: kinds)
            }
        }
        publish()
        updateKeepAwake()
    }

    // MARK: Periodic work

    func periodic() {
        let now = Date()
        _ = tracker.expire(now: now)
        commands.expire(now: now)
        queue.expire(now: now)
        let p = presence.snapshot
        for var a in queue.alerts where PresencePolicy.repeatDue(a, presence: p, now: now) {
            a.buzzes += 1; a.lastBuzz = now
            queue.update(a)
            ble.send(.buzz(id: a.id))
            Log.info("repeat buzz \(a.id) (\(a.buzzes))")
        }
        publish()
        updateKeepAwake()
    }

    /// Sends Smart buzzes whose 20 s have passed (always-buzz). Runs before the focus-clear and
    /// ignores its activity guard, so an idle user still gets the buzz.
    func sendDueBuzzes() {
        let now = Date()
        var sent = false
        for var a in queue.alerts {
            let checking = tabCheckHost != nil && tracker.location(source: a.source)?.app == tabCheckHost
            guard PresencePolicy.delayedDue(a, now: now, checking: checking) else { continue }
            a.buzzes = 1; a.lastBuzz = now
            queue.update(a)
            if ble.connected {
                ble.send(.buzz(id: a.id))
                Log.info("buzz \(a.id) (Smart: late)")
            } else {
                buzzOnReconnect.insert(a.id)
                Log.info("buzz \(a.id) (Smart: late, watch offline)")
            }
            sent = true
        }
        if sent { publish() }
    }

    /// Withdraws alerts of the session the user is working in (open-agent-session).
    func clearFocused() {
        let loc = { [tracker] (s: String) in tracker.location(source: s) }
        guard let host = FocusPolicy.hostToCheck(alerts: queue.alerts, location: loc, presence: presence.snapshot) else { return }
        let resolve = { [weak self] (selected: SessionLocation?) in
            guard let self else { return }
            let loc = { [tracker = self.tracker] (s: String) in tracker.location(source: s) }
            let sources = FocusPolicy.inFront(alerts: self.queue.alerts, location: loc, host: host, selected: selected)
            guard !sources.isEmpty else { return }
            for s in sources { self.queue.resolve(source: s) }
            Log.info("cleared \(sources.count) alert(s): user is in the session")
            self.publish()
        }
        if FocusPolicy.tabHosts.contains(host) {
            tabCheckHost = host
            opener.selectedTab(in: host) { [weak self] in
                self?.tabCheckHost = nil
                resolve($0)
            }
        } else {
            resolve(nil)
        }
    }

    func updateKeepAwake() {
        keepAwake.set(keepAwakeEnabled && (tracker.anyWorking || commands.anyLongRunning(now: Date())))
    }

    /// Pushes sessions and alerts to the menu and, when they changed, to the watch.
    func publish(force: Bool = false) {
        let now = Date()
        sessions = tracker.ordered
        alerts = queue.ordered
        let s = tracker.wire(now: now)
        if force || s.sessions != lastSessionsWire {
            lastSessionsWire = s.sessions
            ble.send(.sessions(s.sessions, hidden: s.hidden))
        }
        let a = queue.wire()
        ble.send(.alerts(a.alerts, total: a.total))
        // A buzz flag goes out once. The watch forgets ids that leave its list, so a resent flag would buzz again.
        if ble.connected {
            for var q in queue.alerts where q.buzzOnShow && a.alerts.contains(where: { $0.id == q.id }) {
                q.buzzOnShow = false
                queue.update(q)
            }
        }
    }

    // MARK: Menu actions

    func acknowledge(_ id: UInt8) {
        queue.acknowledge(id: id)
        publish()
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.info("launch at login: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    static let shellLine = #"eval "$(~/.local/bin/garminy-hook shell-init zsh)""#

    /// Copies the line to add to ~/.zshrc.
    func copyShellSetup() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.shellLine, forType: .string)
    }

    func refreshBluetoothNote() {
        switch ble.authorization {
        case .denied, .restricted: bluetoothNote = "Bluetooth access is needed"
        default: bluetoothNote = ble.poweredOn ? nil : "Bluetooth is off"
        }
    }

    func openBluetoothSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
    }
}
