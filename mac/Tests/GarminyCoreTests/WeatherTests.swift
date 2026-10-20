import Foundation
import Testing
@testable import GarminyCore

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func wmoMapping() {
    #expect(WeatherMapper.condition(wmo: 0) == 0)
    #expect(WeatherMapper.condition(wmo: 3) == 20)
    #expect(WeatherMapper.condition(wmo: 61) == 14)
    #expect(WeatherMapper.condition(wmo: 65) == 15)
    #expect(WeatherMapper.condition(wmo: 95) == 6)
    #expect(WeatherMapper.condition(wmo: 1234) == 53)
}

@Test func locationRoundsToTwoDecimals() {
    #expect(WeatherMapper.round2(45.508843) == 45.51)
    #expect(WeatherMapper.round2(-73.587812) == -73.59)
    let q = WeatherMapper.forecastURL(lat: 45.508843, lon: -73.587812).query ?? ""
    #expect(q.contains("latitude=45.51") && q.contains("longitude=-73.59"))
    #expect(q.contains("hourly=precipitation_probability") && q.contains("timeformat=unixtime"))
    #expect(!q.contains("apikey"))
}

@Test func parsesLiveMontrealForecast() throws {
    let data = try fixture("montreal-forecast")
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let current = obj["current"] as! [String: Any]
    let observed = current["time"] as! Int
    let w = try #require(WeatherMapper.parse(data, now: Date(timeIntervalSince1970: Double(observed) + 600)))
    #expect(w.observed == UInt32(observed))
    #expect(w.chances.count == 12)
    #expect(w.hourlyBase <= UInt32(observed + 600) && UInt32(observed + 600) < w.hourlyBase + 3600)
    #expect(w.today.high >= w.today.low)
    // Round-trips through the wire.
    var r = Reassembler()
    var out: (type: UInt8, payload: Data)?
    for f in Wire.encode(.weather(w), msgId: 1) { out = r.feed(f) }
    #expect(out.flatMap { Wire.decodeMac(type: $0.type, payload: $0.payload) } == .weather(w))
}

@Test func settingsNewerWins() {
    var m = SettingsModel()
    var watch = SettingsModel.defaults
    watch.interval = 30
    let a1 = m.adoptFromWatch(watch)            // fresh Mac shows the watch's values
    #expect(a1)
    #expect(m.value.interval == 30)
    m.edit(now: Date(timeIntervalSince1970: 1_760_000_000)) { $0.interval = 60 }
    var older = watch; older.changedAt = 1_750_000_000
    let a2 = m.adoptFromWatch(older)            // older watch change loses
    #expect(!a2)
    #expect(m.value.interval == 60)
    var newer = watch; newer.changedAt = 1_770_000_000; newer.interval = 5
    let a3 = m.adoptFromWatch(newer)            // newer Garmin Connect change wins
    #expect(a3)
    #expect(m.value.interval == 5)
    m.setCard(2, false, now: Date(timeIntervalSince1970: 1_780_000_000))  // Fortune, bit 1
    #expect(!m.card(2) && m.card(0) && m.value.cards & 0b10 == 0)
    #expect(SettingsModel.cities.count == 45 && SettingsModel.cities[33] == "Singapore")
}

@Test func newsCardBitIsInverted() {
    var m = SettingsModel()
    #expect(SettingsModel.cards[1].name == "News")
    #expect(m.value.cards == 0x1FF && m.card(1))  // settings saved before News existed: On
    m.setCard(1, false, now: Date(timeIntervalSince1970: 1_780_000_000))
    #expect(!m.card(1) && m.value.cards & (1 << 9) != 0)
    m.setCard(1, true, now: Date(timeIntervalSince1970: 1_780_000_001))
    #expect(m.card(1) && m.value.cards == 0x1FF)
}
