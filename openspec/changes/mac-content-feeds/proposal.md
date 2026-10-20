# Proposal

## Why

The desk watch has nothing about what is happening in the world, and its text cards (Fortune, Quote, On this day) only show bundled content that changes once a day, so the same text comes back about every 90 seconds. The Mac companion can fetch fresh text and already pushes weather over the same link. This change builds one shared way to send text items from the Mac to the watch and uses it first for news headlines (Sky News by default). The follow-up change `fresh-daily-cards` moves Fortune, Quote and On this day onto the same pipeline.

## What Changes

- A generic **content feed** pipeline from the Mac to the watch. A new `FEED` wire message (`0x0B`) carries one text item per message, tagged with a channel. The watch stages each channel's set and shows it only once complete, saves it so it survives restarts, and keeps it while the Mac is offline. Older watches ignore the unknown type, so the protocol version stays at 1.
- Feed traffic never delays alerts. The Mac sends feed messages only when no alert, buzz or state message is waiting, and sends feeds after the initial snapshot.
- **News channel:**
  - The Mac fetches a public RSS feed about every 15 minutes over HTTPS, with no account or key, and keeps the top 8 headlines.
  - The default feed is Sky News Home (`https://feeds.skynews.com/feeds/rss/home.xml`). The other presets are Sky News World and BBC News, or the user can enter a custom HTTPS RSS URL. This choice is Mac-only.
- **News card:**
  - It shows one headline per showing, with a line below for the source and age ("Sky News · 25 min ago").
  - It moves to the next headline each time it is shown, and every interval while pinned or when it is the only card.
  - It shows "Out of date" after 12 hours without new headlines.
- A new **News** card toggle, default On, in Garmin Connect and in the Mac's Watch settings window. The card appears only after headlines have arrived, so watches without a Mac never see it. Macs and watches that saved settings before News existed read it as On.

## Capabilities

### New Capabilities
- `mac-content-feeds`: the shared Mac-to-watch text feed: channels, whole-set delivery, storage, offline behaviour, and priority below alerts.
- `news-headlines`: fetching the chosen RSS feed on the Mac, and the News card.

### Modified Capabilities
- `app-settings`: Card selection and order gains the News card. There are now ten cards, with News after Agents. News shows only once headlines have been received, and it defaults to On even for settings saved before it existed.

## Out of scope

- Fresh Fortune, Quote and On-this-day content. That's the follow-up change `fresh-daily-cards`, which adds channels to this pipeline.
- Interrupting the carousel, buzzing or beeping for new or breaking headlines.
- Fetching on the watch or phone (`makeWebRequest`).
- Article summaries, images, or opening articles.
- More than one news feed at once, keyword filtering, Atom or JSON feeds.
- Desk extras considered and not chosen: a new-headline dot, a headline in the glance, tap to show the next item, and spacing text cards apart.

## Impact

- Watch:
  - `source/companion/Proto.mc` (decode `FEED`)
  - `Companion.mc` (staging)
  - new `source/companion/Feeds.mc` (storage, not part of the glance) and `NewsCard.mc`
  - `Card.mc` (`shown`/`tick` hooks), `CarouselView.mc`
  - `Settings.mc` (`cardNews`, inverted card bit 9), `resources/settings/*`
  - `tests/`
- Mac:
  - new `GarminyCore/Feeds.swift` (item types, trimming) and `GarminyCore/News.swift` (RSS parsing, presets)
  - `Wire.swift` (`.feed`), `Weather.swift` (`SettingsModel` card table)
  - `BLEPeripheral.swift` (low-priority lane)
  - new `GarminyCompanion/NewsService.swift`, `AppModel.swift`, `SettingsView.swift`, `CompanionApp.swift` (status line)
  - `mac/Tests/vectors.md` and tests
- Network: one HTTPS GET to the chosen feed host every 15 minutes. No personal data is sent.
