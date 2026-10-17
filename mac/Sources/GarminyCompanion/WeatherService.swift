import AppKit
import CoreLocation
import Foundation
import GarminyCore

/// Fetches the forecast for this Mac's location from Open-Meteo (companion-weather).
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let refreshEvery: TimeInterval = 30 * 60
    static let retryAfter: TimeInterval = 5 * 60

    @Published private(set) var status = "Waiting for Location access"
    @Published private(set) var locationDenied = false
    @Published private(set) var locationUndecided = true
    private(set) var latest: WireWeather?
    private var macLocation: CLLocationCoordinate2D?
    private var timer: Timer?
    private let location = CLLocationManager()
    var onUpdate: (() -> Void)?

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        locate()
    }

    /// Where the forecast is for, rounded as sent to the watch.
    var coordinate: (lat: Double, lon: Double)? {
        macLocation.map { (WeatherMapper.round2($0.latitude), WeatherMapper.round2($0.longitude)) }
    }

    /// Fetches soon after the Mac wakes.
    func didWake() {
        schedule(after: 30)
    }

    func openLocationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
    }

    /// Refreshes the location, then the forecast.
    private func locate() {
        locationUndecided = location.authorizationStatus == .notDetermined
        switch location.authorizationStatus {
        case .notDetermined:
            status = "Allow Location access to get weather"
            requestAccess()
        case .denied, .restricted:
            locationDenied = true
            status = "Location access is needed for weather"
        default:
            locationDenied = false
            location.requestLocation()
        }
    }

    /// Asks macOS for Location access. A menu-bar app must be frontmost for the prompt to show.
    func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        location.requestAlwaysAuthorization()
    }

    private func fetch() {
        guard let c = coordinate else { return }
        URLSession.shared.dataTask(with: WeatherMapper.forecastURL(lat: c.lat, lon: c.lon)) { [weak self] data, resp, err in
            DispatchQueue.main.async { self?.finish(data: data, ok: (resp as? HTTPURLResponse)?.statusCode == 200, err: err) }
        }.resume()
    }

    private func finish(data: Data?, ok: Bool, err: Error?) {
        if ok, let data, let w = WeatherMapper.parse(data, now: Date()) {
            latest = w
            let f = DateFormatter(); f.timeStyle = .short
            status = "Updated \(f.string(from: Date()))"
            Log.info("weather updated")
            onUpdate?()
            schedule(after: Self.refreshEvery)
        } else {
            status = "Weather failed: \(err?.localizedDescription ?? "bad response"); retrying in 5 min"
            Log.info(status)
            schedule(after: Self.retryAfter)
        }
    }

    private func schedule(after s: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: s, repeats: false) { [weak self] _ in self?.locate() }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        Log.info("location authorization \(m.authorizationStatus.rawValue)")
        locate()
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let c = locs.last?.coordinate else { return }
        macLocation = c
        fetch()
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Log.info("location failed: \(error.localizedDescription)")
        if macLocation != nil {
            fetch()  // use the last known position
        } else {
            status = "Couldn't find this Mac's location; retrying in 5 min"
            schedule(after: Self.retryAfter)
        }
    }
}
