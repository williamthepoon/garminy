# Tasks

## 1. Mac: feed core and news parsing (GarminyCore)

- [ ] 1.1 Add `GarminyCore/Feeds.swift`: `FeedItem` (stamp, source, text), `FeedChannel` (news = 0; reserve 1 quote, 2 fortune, 3 on-this-day), `Feeds.trim(_:maxBytes:)` (Character-safe, adds "…")
- [ ] 1.2 Add `GarminyCore/News.swift`:
  - presets with URLs and source names
  - `News.parse(data)` with `XMLParser`: root must be `rss`; reads the channel title, then the first 8 non-empty `item/title` with their `pubDate`
  - whitespace collapse, 120-byte trim
  - `News.sourceName(channelTitle:)`
- [ ] 1.3 Save fixtures under `mac/Tests/GarminyCoreTests/Fixtures/`: Sky Home, BBC, an Atom feed, and a hand-made RSS feed with entities, CDATA, a 200-byte title, a missing pubDate and 40 items
- [ ] 1.4 Add `NewsTests.swift`: fixtures parse, only 8 are kept, entities decode, the trim is byte-safe, the source-name rules hold, Atom and non-XML are rejected

## 2. Mac: wire and settings

- [ ] 2.1 Add `MacMessage.feed(channel:batch:index:count:stamp:source:text:)` and `Kind.feed = 0x0B` to `Wire.swift`, with encode and decode
- [ ] 2.2 Document `FEED` in `mac/Tests/vectors.md` with a shared vector. Add a `WireTests` case for the vector and for the 11-frame worst case
- [ ] 2.3 Replace `SettingsModel.cardNames` with a display-order table of `(name, bit, inverted)`, and add News as inverted bit 9, shown second. Test that `0x1FF` reads as News On and that toggling News off sets bit 9

## 3. Mac: transport, service and UI

- [ ] 3.1 Add a low-priority `feedOutbox` and `sendFeed` to `BLEPeripheral`:
  - drain it only when `outbox` is empty and between messages
  - drop unsent older-batch messages for a channel when a newer set is queued
  - put the lane-selection logic in a testable `GarminyCore` type, and add a test that an alert queued mid-feed goes next
- [ ] 3.2 Add `GarminyCompanion/NewsService.swift`:
  - refresh every 15 min, retry after 5 min, refresh 30 s after wake and on a feed change
  - require HTTP 200 and a body of at most 512 KB
  - publish `status`
  - call `onUpdate` only when the texts change
- [ ] 3.3 Wire it into `AppModel`: start the service, call `didWake`, send the set on update, and queue every channel's set after `.snapshotEnd` in `sendSnapshot()`
- [ ] 3.4 Add the feed picker to `SettingsView` (three presets plus Custom with a URL field). Reject non-HTTPS URLs with a message and keep the previous feed. Persist `newsFeed` and `newsFeedURL`
- [ ] 3.5 Show the news status (last update or error) in the menu next to the weather status
- [ ] 3.6 Run `swift test --package-path mac` and make sure it passes

## 4. Watch: protocol, staging and storage

- [ ] 4.1 Add `Proto.FEED = 0x0B` and decode `{channel, batch, index, count, stamp, source, text}`
- [ ] 4.2 Add `source/companion/Feeds.mc` (not `(:glance)`):
  - `save` and `get` per channel in key `feed<N>`; a non-zero stamp is converted with `macOffset`, and 0 is stored as null
  - a per-channel cursor with `advance()`
- [ ] 4.3 Add staging in `Companion.handle`:
  - a new batch replaces that channel's stage
  - duplicates are ignored
  - the set is committed when complete
  - `linkDown` clears every stage
  - unknown channels are ignored
- [ ] 4.4 Add `(:test)` cases in `tests/CompanionTests.mc`:
  - the shared vector, and an 11-frame reassembly
  - out-of-order and duplicate indexes
  - an incomplete set never commits, and a new batch overtakes an older one
  - a stamp of 0 becomes null
  - the cursor wraps

## 5. Watch: settings and cards

- [ ] 5.1 Add the `cardNews` property (default true), its setting and strings in `resources/settings/`, inverted bit 9 in `Settings.cardBits` and `applyRemote`, and `"news"` after `"agents"` in `enabledIds()`. Add a `(:test)` that a `cards` value without bit 9 leaves News On
- [ ] 5.2 Add `shown()` and `tick()` to `Card`. Call `shown()` from `CarouselView.show()`, and call `tick()` from its own per-interval counter while the card is pinned or is the only card and no alert is showing
- [ ] 5.3 Add `source/companion/FeedCard.mc`: the cursor per channel, text through `Ui.drawFitted` at the SMALL floor with a cut-at-word "…" fallback (cached), and the meta line through `Ui.fitLine`
- [ ] 5.4 Add `source/companion/NewsCard.mc` extending `FeedCard`, with the meta line as `source · age`, the source alone, or "Out of date" in the alert colour after 12 h since `receivedAt`
- [ ] 5.5 In `CarouselView`, build the News card only when `Feeds.get(0) != null`, and reload in `onTick` when the first news set commits
- [ ] 5.6 Run `scripts/build.sh` and `scripts/test.sh` and make sure they pass

## 6. Verification

- [ ] 6.1 Simulator, News card: use a temporary preview build to inject (a) the longest current Sky headline, (b) a short headline, (c) a missing publish time, (d) a set 13 h old, and (e) a headline that needs the "…" cut. Screenshot each, check against desk-legibility, then restore the sources
- [ ] 6.2 Simulator: the card advances on each showing and on UP/DOWN, advances every interval while pinned, and is absent when no set has been saved
- [ ] 6.3 Device: sideload and run the companion. Headlines appear within one refresh. Switching to BBC News changes the source. An alert raised during a snapshot arrives within 2 s. Quitting the companion keeps the saved headlines with their ages and a grey dot
- [ ] 6.4 Run `openspec validate mac-content-feeds --strict`
