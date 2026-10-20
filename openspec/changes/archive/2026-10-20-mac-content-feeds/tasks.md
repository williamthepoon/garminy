# Tasks

## 1. Mac: feed core and news parsing (GarminyCore)

- [x] 1.1 Add `GarminyCore/Feeds.swift`: `FeedItem` (stamp, source, text), `FeedChannel` (news = 0; reserve 1 quote, 2 fortune, 3 on-this-day), `Feeds.trim(_:maxBytes:)` (Character-safe, adds "…")
- [x] 1.2 Add `GarminyCore/News.swift`:
  - presets with URLs and source names
  - `News.parse(data)` with `XMLParser`: root must be `rss`; reads the channel title, then the first 8 non-empty `item/title` with their `pubDate`
  - whitespace collapse, 120-byte trim
  - `News.sourceName(channelTitle:)`
- [x] 1.3 Save fixtures under `mac/Tests/GarminyCoreTests/Fixtures/`: Sky Home, BBC, an Atom feed, and a hand-made RSS feed with entities, CDATA, a 200-byte title, a missing pubDate and 40 items
- [x] 1.4 Add `NewsTests.swift`: fixtures parse, only 8 are kept, entities decode, the trim is byte-safe, the source-name rules hold, Atom and non-XML are rejected

## 2. Mac: wire and settings

- [x] 2.1 Add `MacMessage.feed(channel:batch:index:count:stamp:source:text:)` and `Kind.feed = 0x0B` to `Wire.swift`, with encode and decode
- [x] 2.2 Document `FEED` in `mac/Tests/vectors.md` with a shared vector. Add a `WireTests` case for the vector and for the 11-frame worst case
- [x] 2.3 Replace `SettingsModel.cardNames` with a display-order table of `(name, bit, inverted)`, and add News as inverted bit 9, shown second. Test that `0x1FF` reads as News On and that toggling News off sets bit 9

## 3. Mac: transport, service and UI

- [x] 3.1 Add a low-priority `feedOutbox` and `sendFeed` to `BLEPeripheral`:
  - drain it only when `outbox` is empty and between messages
  - drop unsent older-batch messages for a channel when a newer set is queued
  - put the lane-selection logic in a testable `GarminyCore` type, and add a test that an alert queued mid-feed goes next
- [x] 3.2 Add `GarminyCompanion/NewsService.swift`:
  - refresh every 15 min, retry after 5 min, refresh 30 s after wake and on a feed change
  - require HTTP 200 and a body of at most 512 KB
  - publish `status`
  - call `onUpdate` only when the texts change
- [x] 3.3 Wire it into `AppModel`: start the service, call `didWake`, send the set on update, and queue every channel's set after `.snapshotEnd` in `sendSnapshot()`
- [x] 3.4 Add the feed picker to `SettingsView` (three presets plus Custom with a URL field). Reject non-HTTPS URLs with a message and keep the previous feed. Persist `newsFeed` and `newsFeedURL`
- [x] 3.5 Show the news status (last update or error) in the Watch settings window, next to the weather status
- [x] 3.6 Run `swift test --package-path mac` and make sure it passes

## 4. Watch: protocol, staging and storage

- [x] 4.1 Add `Proto.FEED = 0x0B` and decode `{channel, batch, index, count, stamp, source, text}`
- [x] 4.2 Add `source/companion/Feeds.mc` (not `(:glance)`):
  - `save` and `get` per channel in key `feed<N>`; a non-zero stamp is converted with `macOffset`, and 0 is stored as null
  - a per-channel cursor with `advance()`
- [x] 4.3 Add staging in `Companion.handle`:
  - a new batch replaces that channel's stage
  - duplicates are ignored
  - the set is committed when complete
  - `linkDown` clears every stage
  - unknown channels are ignored
- [x] 4.4 Add `(:test)` cases in `tests/CompanionTests.mc`:
  - the shared vector, and an 11-frame reassembly
  - out-of-order and duplicate indexes
  - an incomplete set never commits, and a new batch overtakes an older one
  - a stamp of 0 becomes null
  - the cursor wraps

## 5. Watch: settings and cards

- [x] 5.1 Add the `cardNews` property (default true), its setting and strings in `resources/settings/`, inverted bit 9 in `Settings.cardBits` and `applyRemote`, and `"news"` after `"agents"` in `enabledIds()`. Add a `(:test)` that a `cards` value without bit 9 leaves News On
- [x] 5.2 Add `shown()` and `tick()` to `Card`. Call `shown()` from `CarouselView.show()`, and call `tick()` from its own per-interval counter while the card is pinned or is the only card and no alert is showing
- [x] 5.3 Add `source/companion/FeedCard.mc`: the cursor per channel, text through `Ui.drawFitted` at the SMALL floor with a cut-at-word "…" fallback (cached), and the meta line through `Ui.fitLine`
- [x] 5.4 Add `source/companion/NewsCard.mc` extending `FeedCard`, with the meta line as `source · age`, the source alone, or "Out of date" in the alert colour after 12 h since `receivedAt`
- [x] 5.5 In `CarouselView`, build the News card only when `Feeds.get(0) != null`, and reload in `onTick` when the first news set commits
- [x] 5.6 Run `scripts/build.sh` and `scripts/test.sh` and make sure they pass

## 6. Verification

- [x] 6.1 (2026-10-20: all five cases checked. Ages shortened to "25m" so the meta line fits; a watchdog crash in the cut fallback was fixed with a binary search at minFont, with a test) Simulator, News card: use a temporary preview build to inject (a) the longest current Sky headline, (b) a short headline, (c) a missing publish time, (d) a set 13 h old, and (e) a headline that needs the "…" cut. Screenshot each, check against desk-legibility, then restore the sources
- [x] 6.2 (Only-card interval advance seen in the simulator; per-showing advance and absence without a set are covered by `testNewsCardCyclesAndMeta` and `showNews`) Simulator: the card advances on each showing and on UP/DOWN, advances every interval while pinned, and is absent when no set has been saved
- [x] 6.3 (2026-10-20: Sky News headlines verified on the watch; BBC switch, alert-during-transfer and offline checks waived by the user) Device: sideload and run the companion. Headlines appear within one refresh. Switching to BBC News changes the source. An alert raised during a snapshot arrives within 2 s. Quitting the companion keeps the saved headlines with their ages and a grey dot
- [x] 6.4 Run `openspec validate mac-content-feeds --strict`
