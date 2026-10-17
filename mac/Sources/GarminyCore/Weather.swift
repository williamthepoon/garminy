import Foundation

/// Open-Meteo requests and responses, mapped to what the watch understands (companion-weather).
public enum WeatherMapper {
    /// Garmin `Weather.CONDITION_*` values.
    public enum Garmin {
        public static let clear: UInt8 = 0, partlyCloudy: UInt8 = 1, rain: UInt8 = 3, snow: UInt8 = 4
        public static let thunderstorms: UInt8 = 6, fog: UInt8 = 8, lightRain: UInt8 = 14, heavyRain: UInt8 = 15
        public static let lightSnow: UInt8 = 16, heavySnow: UInt8 = 17, cloudy: UInt8 = 20, mostlyClear: UInt8 = 23
        public static let lightShowers: UInt8 = 24, showers: UInt8 = 25, heavyShowers: UInt8 = 26
        public static let drizzle: UInt8 = 31, flurries: UInt8 = 48, freezingRain: UInt8 = 49, unknown: UInt8 = 53
    }

    /// WMO weather interpretation code (Open-Meteo `weather_code`) to a Garmin condition.
    public static func condition(wmo: Int) -> UInt8 {
        switch wmo {
        case 0: return Garmin.clear
        case 1: return Garmin.mostlyClear
        case 2: return Garmin.partlyCloudy
        case 3: return Garmin.cloudy
        case 45, 48: return Garmin.fog
        case 51, 53, 55: return Garmin.drizzle
        case 56, 57, 66, 67: return Garmin.freezingRain
        case 61: return Garmin.lightRain
        case 63: return Garmin.rain
        case 65: return Garmin.heavyRain
        case 71: return Garmin.lightSnow
        case 73, 85: return Garmin.snow
        case 75, 86: return Garmin.heavySnow
        case 77: return Garmin.flurries
        case 80: return Garmin.lightShowers
        case 81: return Garmin.showers
        case 82: return Garmin.heavyShowers
        case 95, 96, 99: return Garmin.thunderstorms
        default: return Garmin.unknown
        }
    }

    /// Rounds to 2 decimal places (about 1 km), the most precision sent to the watch.
    public static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    public static func forecastURL(lat: Double, lon: Double) -> URL {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(format: "%.2f", round2(lat))),
            .init(name: "longitude", value: String(format: "%.2f", round2(lon))),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "hourly", value: "precipitation_probability"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            .init(name: "forecast_days", value: "2"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
        ]
        return c.url!
    }

    struct Forecast: Decodable {
        struct Current: Decodable { let time: Int; let temperature_2m: Double; let weather_code: Int }
        struct Hourly: Decodable { let time: [Int]; let precipitation_probability: [Int?] }
        struct Daily: Decodable {
            let weather_code: [Int?]; let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?]
        }
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    /// Parses an Open-Meteo forecast into the watch's weather message.
    public static func parse(_ json: Data, now: Date) -> WireWeather? {
        guard let f = try? JSONDecoder().decode(Forecast.self, from: json), f.daily.weather_code.count >= 2 else { return nil }
        func t(_ v: Double?) -> Int8 { Int8(clamping: Int((v ?? 0).rounded())) }
        func day(_ i: Int) -> WireDay {
            WireDay(high: t(f.daily.temperature_2m_max[i]), low: t(f.daily.temperature_2m_min[i]),
                    condition: condition(wmo: f.daily.weather_code[i] ?? -1))
        }
        // 12 hours starting with the hour that contains `now`.
        let nowSecs = Int(now.timeIntervalSince1970)
        let start = f.hourly.time.lastIndex { $0 <= nowSecs } ?? 0
        let hours = f.hourly.time.indices.dropFirst(start).prefix(12)
        var chances = hours.map { UInt8(clamping: f.hourly.precipitation_probability[$0] ?? 255) }
        chances += Array(repeating: 255, count: 12 - chances.count)
        let base = hours.first.map { f.hourly.time[$0] } ?? nowSecs
        return WireWeather(observed: UInt32(f.current.time), temperature: t(f.current.temperature_2m),
                           condition: condition(wmo: f.current.weather_code),
                           today: day(0), tomorrow: day(1), hourlyBase: UInt32(base), chances: chances)
    }
}

/// garminy's watch settings as the Mac edits them (app-settings).
public struct SettingsModel: Equatable, Sendable {
    public static let cardNames = ["Agents", "Fortune", "Motivational quote", "Umbrella?", "Weather",
                                   "Daylight", "Moon phase", "World clock", "On this day"]
    public static let intervals: [UInt8] = [5, 10, 20, 30, 60]
    /// World clock cities, in the watch's order (source/TimeZones.mc).
    public static let cities = [
        "San Francisco", "Los Angeles", "Seattle", "Vancouver", "Denver", "Phoenix",
        "Chicago", "Mexico City", "Toronto", "Montreal", "New York", "Boston",
        "Halifax", "Sao Paulo", "Buenos Aires", "Reykjavik", "London", "Dublin",
        "Lisbon", "Paris", "Berlin", "Madrid", "Amsterdam", "Stockholm",
        "Rome", "Athens", "Helsinki", "Johannesburg", "Istanbul", "Moscow",
        "Dubai", "Mumbai", "Bangkok", "Singapore", "Hong Kong", "Shanghai",
        "Perth", "Tokyo", "Seoul", "Brisbane", "Sydney", "Melbourne",
        "Auckland", "Honolulu", "Anchorage",
    ]

    public var value: WireSettings

    public static let defaults = WireSettings(changedAt: 0, cards: 0x1FF, interval: 10, cities: [0, 33, 9],
                                              units: 0, backlight: 0, companion: true)

    public init(_ value: WireSettings = SettingsModel.defaults) { self.value = value }

    /// The watch's settings replace the Mac's when they are as new or newer (so a fresh Mac shows the watch's values).
    public mutating func adoptFromWatch(_ w: WireSettings) -> Bool {
        guard w.changedAt >= value.changedAt, w != value else { return false }
        value = w
        return true
    }

    /// A change made in the Mac app: stamp it so the watch applies it.
    public mutating func edit(now: Date, _ change: (inout WireSettings) -> Void) {
        change(&value)
        value.changedAt = UInt32(now.timeIntervalSince1970)
    }

    public func card(_ i: Int) -> Bool { value.cards & (1 << i) != 0 }

    public mutating func setCard(_ i: Int, _ on: Bool, now: Date) {
        edit(now: now) { on ? ($0.cards |= 1 << i) : ($0.cards &= ~(1 << i)) }
    }
}
