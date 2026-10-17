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
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    let ble = BLEPeripheral()
    let presence = PresenceMonitor()
    let keepAwake = KeepAwake()
    let socket = SocketServer()
    let weather = WeatherService()
    @Published private(set) var settings = SettingsModel(AppModel.loadSettings())
    private var tracker = SessionTracker()
    private var commands = CommandTracker()
    private var queue = AlertQueue()
    private var tick: Timer?
    private var lastSessionsWire: [WireSession] = []
    /// Opens the Watch settings window (set by the app delegate).
    var showSettings: (() -> Void)?

    init() {
        keepAwakeEnabled = UserDefaults.standard.object(forKey: "keepAwake") as? Bool ?? true
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
                            backlight: UInt8(n("backlight")), companion: d["companion"] as? Bool ?? true)
    }

    func saveSettings() {
        let v = settings.value
        UserDefaults.standard.set(["changedAt": Int(v.changedAt), "cards": Int(v.cards), "interval": Int(v.interval),
                                   "cities": v.cities.map { Int($0) }, "units": Int(v.units), "backlight": Int(v.backlight),
                                   "companion": v.companion], forKey: "watchSettings")
    }

    func sendSnapshot() {
        ble.send(.helloReply(version: protocolVersion, macTime: UInt32(Date().timeIntervalSince1970)))
        lastSessionsWire = []
        publish(force: true)
        sendWeather()
        ble.send(.settings(settings.value))
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
                if PresencePolicy.buzzOnRaise(term: term, presence: p) {
                    a.buzzOnShow = true; a.buzzes = 1; a.lastBuzz = now
                    queue.update(a)
                }
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
