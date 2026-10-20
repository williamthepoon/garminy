# Design

## Context

The Mac companion fetches weather over HTTPS (`WeatherService`) and pushes it as a multi-part message (`Wire.encode(.weather)` → `Proto.decode(WEATHER)` → `MacWeather.save`). Each frame carries 17 payload bytes and a 4-bit part count, so a message holds at most 255 bytes. `Proto.decode` returns null for unknown types. The watch's `Proto.Assembler` handles one message at a time, and the Mac sends each message's frames back to back from a single FIFO `outbox` (`BLEPeripheral.swift`). The heartbeat runs every 5 s, and any received frame resets the watch's liveness timer.

Cards implement `Card` (`id`, `refresh`, `draw`). The carousel builds companion cards conditionally and reloads from `onTick` when one should appear. Card toggles reach the Mac as a `u16` mask (`Settings.cardBits`): bit 0 is Agents, and bits 1–8 follow `CARD_KEYS`. The Mac's default mask is `0x1FF`, and `Settings.applyRemote` writes every bit. `Ui.drawFitted` returns false and draws nothing when the text can't fit at `minFont`.

## Goals / Non-Goals

**Goals:**
- One wire message, staging path, storage format and card base for all Mac-fed text, so the `fresh-daily-cards` change only adds channels and providers.
- Keep protocol version 1 and stay compatible in both directions.

**Non-Goals:**
- Quote, fortune and on-this-day providers. Those belong to `fresh-daily-cards`; this change only reserves their channel numbers.

## Decisions

### `FEED` message, one item per message
Type `0x0B`, sent from the Mac to the watch:

| field | type | notes |
|---|---|---|
| channel | u8 | 0 news. Reserved: 1 quote, 2 fortune, 3 on-this-day |
| batch | u32 | Mac time the set was built; identifies the set |
| index | u8 | 0-based |
| count | u8 | 1–12 |
| stamp | u32 | Mac time (news publish time), or a channel-defined number. 0 means none |
| source | str | ≤ 20 bytes, may be empty |
| text | str | ≤ 140 bytes |

The worst case is 4+1+1+4+21+141 = 172 bytes, or 11 frames. One item per message keeps every message well under 255 bytes, and a lost frame costs only that item's set, never the link.
*Alternative considered:* a type per content kind (`NEWS`, `QUOTES` and so on). Rejected because it means three decoders and three sets of vectors in two languages that must stay in sync.

### Watch staging and storage
`Companion` holds `_feedStage = {channel: [batch, items[]]}`.
- A message with a new `batch` for a channel replaces that channel's stage.
- A duplicate index is ignored.
- When all `count` items are present, the set is committed with `Feeds.save(channel, …)` and the stage is cleared.
- `linkDown` clears every stage.

Each channel is stored in its own Application.Storage key (`feed0`, `feed1`, …): `{batch, receivedAt, items: [[stamp|null, source, text], …]}`. When `stamp` is not 0 it's converted to watch time with `macOffset`; 0 is stored as null. `Feeds` is not `(:glance)`. A news set is about 1.2 KB; 12 quotes are about 2 KB.

### Low-priority lane on the Mac
`BLEPeripheral` gets a second queue, `feedOutbox`, filled by `sendFeed(_:)`. `flush()` drains `outbox` first, and takes the next feed message only when `outbox` is empty and no other message is partly sent. Messages are never interleaved at the frame level, because the Assembler handles one message at a time. When a new set is queued for a channel, any unsent messages of an older set for that channel are dropped. This meets "alert within 2 s": one feed message is at most 11 frames, so an alert waits for at most that one message.

### Feeds go after the snapshot
`AppModel.sendSnapshot()` sends `.snapshotEnd` first and then queues each channel's current set on the low lane. `FeedService` remembers the last set sent per channel and sends only when the texts change.

### Card toggle: bit 9 inverted
Bit 9 of `cards` means **News off**. Existing Mac settings (`0x1FF`) and older watch builds send 0 in bit 9, which reads as On, so no migration is needed. `Settings.cardBits` sets bit 9 when `cardNews` is false, and `applyRemote` sets `cardNews = (bits & 1<<9) == 0`. On the Mac, `SettingsModel` replaces `cardNames` with a display-order table of `(name, bit, inverted)`, so News shows second in the Watch settings window.
*Alternative considered:* a one-time Mac migration with a `newsMigrated` flag. Rejected because restamping `changedAt` could override newer watch settings.

### RSS on the Mac with `XMLParser` (`GarminyCore/News.swift`)
`News.parse(data)` reads `rss/channel/title` and each `item/title` and `item/pubDate` (RFC 822, `en_US_POSIX`). It returns nil when the root isn't `rss`, which covers Atom. Entities and CDATA are decoded by `XMLParser`, and whitespace is collapsed. `Feeds.trim(_:maxBytes:)` cuts at a `Character` boundary and adds "…". `News.sourceName(channelTitle:)` takes the text after the last " | " or " - ". The presets are constants:
- Sky News Home: `https://feeds.skynews.com/feeds/rss/home.xml`, source "Sky News"
- Sky News World: `https://feeds.skynews.com/feeds/rss/world.xml`, source "Sky News"
- BBC News: `https://feeds.bbci.co.uk/news/rss.xml`, source "BBC News"

`NewsService` mirrors `WeatherService`:
- Refreshes every 15 min, retries after 5 min on failure, and refreshes 30 s after wake and on a feed change.
- Requires a 200 status and rejects bodies over 512 KB.
- Stores the choice in `UserDefaults` (`newsFeed`: `skyHome`, `skyWorld`, `bbc` or `custom`; plus `newsFeedURL`).

### Card hooks
`Card` gains `shown()`, called from `CarouselView.show()` (rotation and UP/DOWN), and `tick() as Boolean`, called once per interval while the card is pinned or is the only card and no alert is showing. It uses its own counter, separate from the rotation branch at `CarouselView.mc:134`. `FeedCard` is the base class: it holds a module-level cursor per channel in `Feeds`, which survives `reload()`, and advances it in `shown()` and `tick()`. `NewsCard extends FeedCard`.
*Alternative considered:* advancing the cursor in `refresh()`. Rejected because `refresh()` also runs every minute.

### Fitting with a cut fallback
`FeedCard` draws the text using `Ui.drawFitted(…, FONT_SMALL)` in the box above the meta line. If that returns false, it drops the last word and appends "…" until it fits, caching the result per item. The meta line is a single `Ui.fitLine` at SMALL, in white: `"<source> · <age>"`, the source alone, or `"Out of date"` in the alert colour once `receivedAt` is more than 12 h old.

## Risks / Trade-offs

- [A feed changes its markup or goes away] → Only `item/title` is required. The last set is kept and the error shows in the Mac app, and the user can switch preset.
- [Cutting long headlines loses the end] → This is rare at 120 bytes. Simulator task 6.1 checks the longest current Sky headline.
- [Feed messages make the first sync slower] → They go after `snapshotEnd` on the low lane, so the agent state and alerts arrive first.
- [Mac and watch clocks differ] → Times are converted with `macOffset`, as for weather.

## Migration Plan

The change is additive. The new message type and the inverted bit 9 need no data migration. Mac and watch can ship in either order.
