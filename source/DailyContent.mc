import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Bundled daily text, loaded one small chunk at a time to stay within
// the memory limits of older devices.
module Daily {
    const CHUNK = 40;
    const FORTUNE_COUNT = 120;
    const QUOTE_COUNT = 120;

    // Stable for a whole day, different on consecutive days, full cycle before repeating.
    function indexFor(days as Number, n as Number) as Number {
        return ((days % n) + n) % n;
    }

    function fortuneChunks() as Array<ResourceId> {
        return [Rez.JsonData.fortunes0, Rez.JsonData.fortunes1, Rez.JsonData.fortunes2] as Array<ResourceId>;
    }

    function quoteChunks() as Array<ResourceId> {
        return [Rez.JsonData.quotes0, Rez.JsonData.quotes1, Rez.JsonData.quotes2] as Array<ResourceId>;
    }

    function monthChunks() as Array<ResourceId> {
        return [Rez.JsonData.otd01, Rez.JsonData.otd02, Rez.JsonData.otd03, Rez.JsonData.otd04,
                Rez.JsonData.otd05, Rez.JsonData.otd06, Rez.JsonData.otd07, Rez.JsonData.otd08,
                Rez.JsonData.otd09, Rez.JsonData.otd10, Rez.JsonData.otd11, Rez.JsonData.otd12] as Array<ResourceId>;
    }

    function entry(chunks as Array<ResourceId>, idx as Number) {
        var arr = WatchUi.loadResource(chunks[idx / CHUNK]) as Array;
        return arr[idx % CHUNK];
    }

    function fortune(days as Number) as String {
        return entry(fortuneChunks(), indexFor(days, FORTUNE_COUNT)) as String;
    }

    function quote(days as Number) as String {
        return entry(quoteChunks(), indexFor(days, QUOTE_COUNT)) as String;
    }

    // [year, text]
    function onThisDay(month as Number, day as Number) as Array {
        var arr = WatchUi.loadResource(monthChunks()[month - 1]) as Array;
        return arr[day - 1] as Array;
    }
}

const DAILY_FRESH = 36 * 3600;

// A text card fed by the Mac's daily set for its channel, falling back to the bundled
// content when there is none from the last 36 hours. Either way it moves to the next
// item each time it is shown (fresh-daily-cards).
class DailyCard extends FeedCard {
    var _seedDay as Number = -1;
    var _cacheIdx as Number = -1;
    var _cacheText as String = "";

    function initialize(channel as Number) {
        FeedCard.initialize(channel, Graphics.FONT_TINY);
    }

    // The Mac's set when it is fresh enough, else null.
    function macSet() as Dictionary? {
        var s = Feeds.get(_channel);
        if (s == null || Time.now().value() - (s["receivedAt"] as Number) > DAILY_FRESH) {
            return null;
        }
        return s;
    }

    function count() as Number {
        var s = macSet();
        return s != null ? (s["items"] as Array).size() : fallbackCount();
    }

    function itemAt(i as Number) as Array {
        var s = macSet();
        if (s != null) {
            return (s["items"] as Array)[i] as Array;
        }
        if (i != _cacheIdx) {
            _cacheIdx = i;
            _cacheText = fallbackText(i);
        }
        return [null, "", _cacheText];
    }

    // With bundled content, the first showing of each day starts at that day's entry.
    function seed() as Boolean {
        if (macSet() != null) {
            return false;
        }
        var today = Dates.localTodayDays();
        if (today == _seedDay) {
            return false;
        }
        _seedDay = today;
        Feeds.setCursor(_channel, Daily.indexFor(today, fallbackCount()));
        return true;
    }

    function shown() as Void {
        if (!seed()) {
            FeedCard.shown();
        }
    }

    function current() as Array? {
        seed();
        return FeedCard.current();
    }

    function meta(item as Array) as Array? {
        var src = item[1] as String;
        return src.length() > 0 ? [src, Ui.FG] : null;
    }

    function fallbackCount() as Number {
        return 1;
    }

    function fallbackText(i as Number) as String {
        return "";
    }
}

class FortuneCard extends DailyCard {
    function initialize() {
        DailyCard.initialize(Feeds.FORTUNE);
    }

    function id() as String {
        return "fortune";
    }

    function fallbackCount() as Number {
        return Daily.FORTUNE_COUNT;
    }

    function fallbackText(i as Number) as String {
        return Daily.entry(Daily.fortuneChunks(), i) as String;
    }
}

class QuoteCard extends DailyCard {
    function initialize() {
        DailyCard.initialize(Feeds.QUOTE);
    }

    function id() as String {
        return "quote";
    }

    function fallbackCount() as Number {
        return Daily.QUOTE_COUNT;
    }

    function fallbackText(i as Number) as String {
        return Daily.entry(Daily.quoteChunks(), i) as String;
    }
}

// Wikipedia's events for today from the Mac, or the bundled fact for the date, with the year above.
class OnThisDayCard extends DailyCard {
    function initialize() {
        DailyCard.initialize(Feeds.ON_THIS_DAY);
    }

    function id() as String {
        return "onthisday";
    }

    // Only a set built for today's date counts.
    function macSet() as Dictionary? {
        var s = DailyCard.macSet();
        if (s == null || !s.hasKey("batchAt") || Dates.localDays(s["batchAt"] as Number) != Dates.localTodayDays()) {
            return null;
        }
        return s;
    }

    function itemAt(i as Number) as Array {
        if (macSet() != null) {
            return DailyCard.itemAt(i);
        }
        var t = Dates.localToday();
        var e = Daily.onThisDay(t[1], t[2]);
        return [e[0], "", e[1]];
    }

    function seed() as Boolean {
        return false;
    }

    function header(dc as Graphics.Dc, l as Layout, item as Array) as Number {
        var y = item[0];
        if (!(y instanceof Number)) {
            return l.boxY;
        }
        dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.boxY + l.h / 10, Graphics.FONT_NUMBER_MILD, yearText(y),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        return l.boxY + l.h / 5;
    }
}

// "1969", or "-44" for 44 BC: NUMBER fonts have no letters, but they do have the minus sign.
function yearText(y as Number) as String {
    return y.toString();
}
