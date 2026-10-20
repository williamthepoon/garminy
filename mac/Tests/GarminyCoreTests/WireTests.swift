import Foundation
import Testing
@testable import GarminyCore

// Every case here mirrors an entry in mac/Tests/vectors.md.

func hex(_ frames: [Data]) -> [String] { frames.map { $0.map { String(format: "%02x", $0) }.joined() } }

func unhex(_ s: String) -> Data {
    var d = Data()
    var i = s.startIndex
    while i < s.endIndex {
        let j = s.index(i, offsetBy: 2)
        d.append(UInt8(s[i..<j], radix: 16)!)
        i = j
    }
    return d
}

let sampleSettings = WireSettings(changedAt: 1_760_000_000, cards: 0x01FF, interval: 10, cities: [0, 33, 9], units: 0, backlight: 0, companion: true)
let sampleWeather = WireWeather(observed: 1_760_000_000, temperature: 12, condition: 1,
                                today: WireDay(high: 15, low: 6, condition: 3),
                                tomorrow: WireDay(high: 9, low: 2, condition: 3),
                                hourlyBase: 1_759_998_600, chances: [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 255])
let sampleAlert = WireAlert(id: 1, kind: .needsYou, buzz: true, label: "garminy", detail: "Allow Bash")
let sampleSessions = [
    WireSession(state: .needsYou, minutes: 0, label: "garminy"),
    WireSession(state: .working, minutes: 12, label: "api-svc"),
    WireSession(state: .done, minutes: 3, label: "website"),
]

struct MacVector: @unchecked Sendable {
    let message: MacMessage
    let msgId: UInt8
    let frames: [String]
}

let macVectors: [MacVector] = [
    MacVector(message: .heartbeat, msgId: 7, frames: ["090701"]),
    MacVector(message: .helloReply(version: 1, macTime: 1_760_000_000), msgId: 1, frames: ["0101010168e77800"]),
    MacVector(message: .buzz(id: 2), msgId: 4, frames: ["04040102"]),
    MacVector(message: .snapshotEnd, msgId: 8, frames: ["080801"]),
    MacVector(message: .location(lat: 45.50, lon: -73.57), msgId: 9, frames: ["06090111c6e343"]),
    MacVector(message: .settings(sampleSettings), msgId: 10, frames: ["070a0268e7780001ff0a00210900000101000112", "070a1209"]),
    MacVector(message: .testSignal(kind: .needsYou), msgId: 15, frames: ["0a0f0100"]),
    MacVector(message: .weather(sampleWeather), msgId: 11,
              frames: ["050b0268e778000c010f060309020368e7728800", "050b120a141e28323c46505a64ff"]),
    MacVector(message: .alerts([sampleAlert], total: 1), msgId: 12,
              frames: ["030c020101010001076761726d696e790a416c6c", "030c126f772042617368"]),
    MacVector(message: .alerts([WireAlert(id: 2, kind: .done, buzz: false, label: "garminy", detail: "4m", openable: true)], total: 1),
              msgId: 14, frames: ["030e010101020202076761726d696e7902346d"]),
    MacVector(message: .feed(channel: 0, batch: 1_760_000_000, index: 0, count: 8,
                             item: FeedItem(stamp: 1_759_999_000, source: "Sky News", text: "Storm named")),
              msgId: 16, frames: ["0b10020068e77800000868e7741808536b79204e", "0b10126577730b53746f726d206e616d6564"]),
    MacVector(message: .sessions(sampleSessions, hidden: 0), msgId: 13,
              frames: ["020d030300010000076761726d696e7900000c07", "020d136170692d73766302000307776562736974", "020d2365"]),
]

@Test(arguments: macVectors.indices)
func macVectorEncodes(_ i: Int) {
    let v = macVectors[i]
    #expect(hex(Wire.encode(v.message, msgId: v.msgId)) == v.frames)
}

@Test(arguments: macVectors.indices)
func macVectorDecodes(_ i: Int) throws {
    let v = macVectors[i]
    var r = Reassembler()
    var out: (type: UInt8, payload: Data)?
    for f in v.frames { out = r.feed(unhex(f)) }
    let done = try #require(out)
    #expect(Wire.decodeMac(type: done.type, payload: done.payload) == v.message)
}

@Test func watchVectors() {
    #expect(hex(Wire.encode(WatchMessage.hello(version: 1), msgId: 0)) == ["41000101"])
    #expect(hex(Wire.encode(WatchMessage.ack(id: 5), msgId: 3)) == ["42030105"])
    #expect(Wire.decodeWatch(type: 0x42, payload: Data([5])) == .ack(id: 5))
    #expect(hex(Wire.encode(WatchMessage.open(id: 5), msgId: 6)) == ["44060105"])
    #expect(Wire.decodeWatch(type: 0x44, payload: Data([5])) == .open(id: 5))
    #expect(Wire.decodeWatch(type: 0x43, payload: unhex("68e7780001ff0a0021090000010100011209")) == .settings(sampleSettings))
    // A 13-byte payload from an older watch decodes with the default charger signal and beep sound.
    #expect(Wire.decodeWatch(type: 0x43, payload: unhex("68e7780001ff0a002109000001")) == .settings(sampleSettings))
    // A 15-byte payload decodes with the default quiet hours.
    var chime = sampleSettings; chime.chargerSignal = 3; chime.beepSound = 1
    #expect(Wire.decodeWatch(type: 0x43, payload: unhex("68e7780001ff0a0021090000010301")) == .settings(chime))
    var quiet = sampleSettings; quiet.quietHours = false; quiet.quietStart = 20; quiet.quietEnd = 7
    #expect(Wire.decodeWatch(type: 0x43, payload: unhex("68e7780001ff0a0021090000010100001407")) == .settings(quiet))
}

@Test func missingPartDropsMessage() {
    let f = macVectors.last!.frames.map(unhex)
    var r = Reassembler()
    #expect(r.feed(f[0]) == nil)
    #expect(r.feed(f[2]) == nil)  // part 1 lost
    // A fresh message still works afterwards.
    #expect(r.feed(unhex("090701"))?.type == 0x09)
}

@Test func interleavedMessageDropsFirst() {
    let a = macVectors.last!.frames.map(unhex)
    var r = Reassembler()
    _ = r.feed(a[0])
    #expect(r.feed(unhex("030c126f772042617368")) == nil)
    #expect(r.feed(a[1]) == nil)
}

// Task 2.3: no frame over 20 bytes, whatever the input.
@Test func framesNeverExceedTwentyBytes() {
    let long = String(repeating: "é", count: 200)
    let alerts = (0..<9).map { WireAlert(id: UInt8($0), kind: .failed, buzz: true, label: long, detail: long) }
    let sessions = (0..<9).map { _ in WireSession(state: .working, minutes: 65535, label: long) }
    let all = Wire.encode(.alerts(alerts, total: 9), msgId: 1)
        + Wire.encode(.sessions(sessions, hidden: 250), msgId: 2)
        + Wire.frames(type: 0x7F, msgId: 3, payload: Data(repeating: 0xAA, count: 1000))
    #expect(all.allSatisfy { $0.count <= Wire.maxFrame })
    // 5 maximum alerts still fit in one message without being cut.
    let a = Wire.encode(.alerts(alerts, total: 9), msgId: 1)
    var r = Reassembler()
    var out: (type: UInt8, payload: Data)?
    for f in a { out = r.feed(f) }
    if case let .alerts(list, total)? = out.flatMap({ Wire.decodeMac(type: $0.type, payload: $0.payload) }) {
        #expect(list.count == 5 && total == 9)
        #expect(list.allSatisfy { $0.label.utf8.count <= 24 && $0.detail.utf8.count <= 20 })
    } else {
        Issue.record("alerts did not decode")
    }
}

@Test func feedWorstCaseFitsElevenFrames() {
    let item = FeedItem(stamp: 1, source: String(repeating: "s", count: 40), text: String(repeating: "t", count: 300))
    let f = Wire.encode(.feed(channel: 0, batch: 1, index: 0, count: 12, item: item), msgId: 1)
    #expect(f.count == 11)
    #expect(f.allSatisfy { $0.count <= Wire.maxFrame })
    var r = Reassembler()
    var out: (type: UInt8, payload: Data)?
    for x in f { out = r.feed(x) }
    guard let done = out, case let .feed(_, _, _, _, got)? = Wire.decodeMac(type: done.type, payload: done.payload) else {
        Issue.record("no feed"); return
    }
    #expect(got.source.utf8.count == 20 && got.text.utf8.count == 140)
}

@Test func outboxPutsAlertsBeforeFeeds() {
    var o = Outbox()
    o.pushFeed(channel: 0, batch: 1, frames: [Data([1])])
    o.pushFeed(channel: 0, batch: 1, frames: [Data([2])])
    o.push([Data([9])])
    #expect(o.next() == [Data([9])])
    #expect(o.next() == [Data([1])])
    // A newer set drops the unsent rest of the older one.
    o.pushFeed(channel: 0, batch: 2, frames: [Data([3])])
    o.push([Data([8])])
    #expect(o.next() == [Data([8])])
    #expect(o.next() == [Data([3])])
    #expect(o.next() == nil)
}
