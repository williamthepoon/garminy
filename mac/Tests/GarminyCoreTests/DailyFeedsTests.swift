import Foundation
import Testing
@testable import GarminyCore

@Test func parsesFeaturedFacts() throws {
    let f = try #require(DailyFeeds.parseFeatured(try fixture("wiki-featured")))
    #expect(f.facts.count >= 8)
    #expect(f.facts.allSatisfy { $0.hasPrefix("Did you know that ") && $0.utf8.count <= 140 })
    #expect(f.facts.allSatisfy { $0.hasSuffix("?") })
    #expect(f.facts.contains("Did you know that a Michigan TV station once broadcast out of a former student cafeteria?"))
    #expect(f.facts.contains { $0.hasSuffix("…?") })  // the 166-byte one is cut at a word
}

@Test func parsesOnThisDayWithBCYear() throws {
    let f = try #require(DailyFeeds.parseFeatured(try fixture("wiki-featured")))
    #expect(f.events.count == 12)
    #expect(f.events.allSatisfy { $0.text.utf8.count <= 140 && !$0.text.contains("<") })
    // The fixture's BC entry is the 18th, past the 12 kept; parse it directly.
    let bc = try #require(DailyFeeds.parseFeatured(Data(#"{"onthisday":[{"text":"Caesar &amp; co","year":-44}]}"#.utf8)))
    #expect(bc.events.first?.year == -44 && bc.events.first?.text == "Caesar & co")
    let items = DailyFeeds.eventSet([(year: -44, text: "Caesar & co")])
    #expect(Int32(bitPattern: items[0].stamp) == -44 && items[0].source == "Wikipedia")
}

@Test func featuredWithoutFacts() throws {
    let f = try #require(DailyFeeds.parseFeatured(try fixture("wiki-featured-nodyk")))
    #expect(f.facts.isEmpty && !f.events.isEmpty)
    #expect(DailyFeeds.parseFeatured(Data("nope".utf8)) == nil)
}

@Test func factRewriting() {
    #expect(DailyFeeds.fact("... that <b>bees</b> &amp; wasps (pictured) dance?") == "Did you know that bees & wasps dance?")
    #expect(DailyFeeds.fact("Not a DYK item") == nil)
    let long = "... that " + String(repeating: "word ", count: 60) + "end?"
    let cut = DailyFeeds.fact(long)
    #expect(cut != nil && cut!.utf8.count <= 140 && cut!.hasSuffix("…?"))
}

@Test func jokesAndFortuneMix() throws {
    let a = try #require(DailyFeeds.parseJoke(try fixture("joke1")))
    let b = try #require(DailyFeeds.parseJoke(try fixture("joke2")))
    #expect(a.id != b.id && !a.text.isEmpty)
    let facts = (1...8).map { "Did you know that \($0)?" }
    let set = DailyFeeds.fortuneSet(facts: facts, jokes: ["j1", "j2", "j3", "j4", "j5"])
    #expect(set.count == 12)
    #expect(set.filter { $0.source == "Wikipedia" }.count == 8)
    #expect(set[2].text == "j1" && set[5].text == "j2")  // spread out
    #expect(DailyFeeds.fortuneSet(facts: [], jokes: ["j1", "j2"]).map(\.text) == ["j1", "j2"])
    #expect(DailyFeeds.fortuneSet(facts: ["f"], jokes: []).map(\.text) == ["f"])
}

@Test func quotesNeverRepeatWithinThirtyDays() {
    var p = QuotePicker()
    var rng = SeededRNG(seed: 7)
    var seen = Set<Int>()
    for d in 0..<30 {
        let day = Date(timeIntervalSince1970: 1_800_000_000 + Double(d) * 86400)
        let picks = p.pick(count: 1000, now: day, rng: &rng)
        #expect(picks.count == 12 && Set(picks).count == 12)
        #expect(seen.isDisjoint(with: picks))
        seen.formUnion(picks)
    }
    // After the window, history is pruned.
    _ = p.pick(count: 1000, now: Date(timeIntervalSince1970: 1_800_000_000 + 61 * 86400), rng: &rng)
    #expect(p.history.count == 12)
}

@Test func smallPoolStillPicks() {
    var p = QuotePicker()
    var rng = SeededRNG(seed: 1)
    for d in 0..<5 {
        let picks = p.pick(count: 20, now: Date(timeIntervalSince1970: Double(d) * 86400), rng: &rng)
        #expect(picks.count == 12 && Set(picks).count == 12)
    }
}

@Test func quotePoolIsPublicDomainAndFits() {
    let pool = QuotePool.all
    #expect(pool.count >= 400)
    #expect(pool.allSatisfy { $0.count == 3 && !$0[2].isEmpty })
    #expect(pool.allSatisfy { $0[0].utf8.count <= 100 })  // fits the round screen uncut
    #expect(Set(pool.map { $0[0].lowercased() }).count == pool.count)
    for q in pool where q[1] != "Proverb" {
        let died = QuotePool.authorDeaths[q[1]]
        #expect(died != nil && died! < 1955, "\(q[1]) is not on the public-domain allow-list")
    }
}
