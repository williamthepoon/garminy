import Toybox.Graphics;
import Toybox.Lang;
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

    // [text, attribution]
    function quote(days as Number) as Array<String> {
        return entry(quoteChunks(), indexFor(days, QUOTE_COUNT)) as Array<String>;
    }

    // [year, text]
    function onThisDay(month as Number, day as Number) as Array {
        var arr = WatchUi.loadResource(monthChunks()[month - 1]) as Array;
        return arr[day - 1] as Array;
    }
}

// Shared base: refresh when the local date changes, then draw wrapped text.
class TextCard extends Card {
    var _day as Number = -1;
    var _title as String = "";
    var _text as String = "";
    var _sub as String? = null;

    function initialize(title as String) {
        Card.initialize();
        _title = title;
    }

    function refresh() as Void {
        var today = Dates.localTodayDays();
        if (today != _day) {
            _day = today;
            load(today);
        }
    }

    function load(days as Number) as Void {
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        drawTitle(dc, l, _title);
        var top = l.boxY + l.h / 14;
        var subH = _sub != null ? l.h / 10 : 0;
        Ui.drawFitted(dc, _text, l.boxX, top, l.boxW, l.boxY + l.boxH - top - subH, Ui.FG);
        if (_sub != null) {
            dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, l.boxY + l.boxH - subH / 2, Graphics.FONT_XTINY, _sub as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

class FortuneCard extends TextCard {
    function initialize() {
        TextCard.initialize("FORTUNE");
    }

    function id() as String {
        return "fortune";
    }

    function load(days as Number) as Void {
        _text = Daily.fortune(days);
    }
}

class QuoteCard extends TextCard {
    function initialize() {
        TextCard.initialize("QUOTE OF THE DAY");
    }

    function id() as String {
        return "quote";
    }

    function load(days as Number) as Void {
        var q = Daily.quote(days);
        _text = "\"" + q[0] + "\"";
        _sub = "- " + q[1];
    }
}

class OnThisDayCard extends TextCard {
    function initialize() {
        TextCard.initialize("ON THIS DAY");
    }

    function id() as String {
        return "onthisday";
    }

    function load(days as Number) as Void {
        var t = Dates.localToday();
        var e = Daily.onThisDay(t[1], t[2]);
        _text = e[1] as String;
        _sub = (e[0] as Number).toString();
    }
}
