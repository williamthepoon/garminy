import Foundation
import Testing
@testable import GarminyCore

func xmlFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func parsesSkyAndBBC() throws {
    let sky = try #require(News.parse(try xmlFixture("sky-home")))
    #expect(!sky.items.isEmpty && sky.items.count <= 8)
    #expect(sky.items.allSatisfy { !$0.title.isEmpty && $0.published != nil })
    #expect(News.sourceName(channelTitle: sky.title) == "Sky News")
    let bbc = try #require(News.parse(try xmlFixture("bbc-news")))
    #expect(bbc.items.count == 8)
}

@Test func handmadeFeedRules() throws {
    let f = try #require(News.parse(try xmlFixture("handmade")))
    #expect(f.items.count == 8)  // 40 items, one with an empty title
    #expect(f.items[0].title == "Smith & Jones ‘agree’ deal")
    #expect(f.items[0].published == Date(timeIntervalSince1970: 1_792_484_100))
    #expect(f.items[1].title == "Café owners cheer new rules")
    #expect(f.items[1].published == nil)
    #expect(f.items[3].title == "Story 4")
    let items = News.items(f, source: News.sourceName(channelTitle: f.title))
    #expect(items[0].source == "Example Times")
    #expect(items[1].stamp == 0)
    let long = items[2].text
    #expect(long.utf8.count <= 120 && long.hasSuffix("…"))
}

@Test func rejectsNonRSS() throws {
    #expect(News.parse(try xmlFixture("atom")) == nil)
    #expect(News.parse(Data("<html><body>nope</body></html>".utf8)) == nil)
    #expect(News.parse(Data("not xml at all".utf8)) == nil)
}

@Test func trimIsCharacterSafe() {
    let s = String(repeating: "é", count: 100)  // 200 bytes
    let t = Feeds.trim(s, maxBytes: 120)
    #expect(t.utf8.count <= 120 && t.hasSuffix("…"))
    #expect(Feeds.trim("short", maxBytes: 120) == "short")
    #expect(News.sourceName(channelTitle: "BBC News - Home") == "Home")
    #expect(News.sourceName(channelTitle: "Plain Title") == "Plain Title")
}

@Test func customFeedMustBeHTTPS() {
    #expect(News.customURL("https://example.com/rss.xml") != nil)
    #expect(News.customURL("http://example.com/rss.xml") == nil)
    #expect(News.customURL("example.com/rss") == nil)
}
