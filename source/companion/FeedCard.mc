import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

// Shows a Mac feed channel one item at a time, moving on each time it is shown and each
// interval while pinned (mac-content-feeds). Subclasses add the line below the text.
class FeedCard extends Card {
    var _channel as Number;
    var _minFont as Graphics.FontDefinition;
    var _cut as Dictionary = {};   // text -> shortened text that fits, for items too long for minFont

    function initialize(channel as Number, minFont as Graphics.FontDefinition) {
        Card.initialize();
        _channel = channel;
        _minFont = minFont;
    }

    function items() as Array {
        var s = Feeds.get(_channel);
        return s == null ? [] : s["items"] as Array;
    }

    function shown() as Void {
        Feeds.advance(_channel, items().size());
    }

    function tick() as Boolean {
        var n = items().size();
        Feeds.advance(_channel, n);
        return n > 1;
    }

    function current() as Array? {
        var list = items();
        if (list.size() == 0) {
            return null;
        }
        var i = Feeds.cursor(_channel);
        return list[i < list.size() ? i : 0] as Array;
    }

    // [text, colour] for the line below the item, or null for none.
    function meta(item as Array) as Array? {
        return null;
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        var item = current();
        if (item == null) {
            return;
        }
        var bottom = l.boxY + l.boxH;
        var m = meta(item);
        if (m != null) {
            var lh = dc.getFontHeight(Graphics.FONT_SMALL);
            var y = bottom - lh / 2;
            var w = Ui.lineWidth(l, y - lh / 2, lh);
            dc.setColor(m[1] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, y, Graphics.FONT_SMALL, Look.truncate(dc, m[0] as String, Graphics.FONT_SMALL, w),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            bottom -= lh;
        }
        drawText(dc, l, item[2] as String, l.boxY, bottom);
    }

    // The item's text at the largest size that fits; cut at a word with "…" if even minFont is too big.
    function drawText(dc as Graphics.Dc, l as Layout, text as String, top as Number, bottom as Number) as Void {
        if (!_cut.hasKey(text)) {
            if (_cut.size() >= 8) {
                _cut = {};
            }
            _cut[text] = fitsAt(dc, l, text, top, bottom) ? text : cut(dc, l, text, top, bottom);
        }
        Ui.drawFitted(dc, l, _cut[text] as String, top, bottom, Ui.FG, _minFont);
    }

    function fitsAt(dc as Graphics.Dc, l as Layout, text as String, top as Number, bottom as Number) as Boolean {
        return Ui.wrapRound(dc, l, text, _minFont, top, bottom) != null;
    }

    // The most whole words that fit at minFont with "…", found by binary search to stay
    // inside the watchdog's time budget.
    function cut(dc as Graphics.Dc, l as Layout, text as String, top as Number, bottom as Number) as String {
        var ws = Ui.words(text);
        var lo = 1;
        var hi = ws.size() - 1;
        var best = ws.size() > 0 ? ws[0] + "…" : "…";
        while (lo <= hi) {
            var mid = (lo + hi) / 2;
            var t = join(ws, mid) + "…";
            if (fitsAt(dc, l, t, top, bottom)) {
                best = t;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return best;
    }

    function join(ws as Array<String>, n as Number) as String {
        var s = "";
        for (var i = 0; i < n; i++) {
            s += (i > 0 ? " " : "") + ws[i];
        }
        return s;
    }
}

// Short ages that fit the narrow bottom of the round screen: "now", "25m", "3h", "2d".
function ageText(seconds as Number) as String {
    var m = seconds / 60;
    if (m < 1) {
        return "now";
    } else if (m < 60) {
        return m + "m";
    } else if (m < 48 * 60) {
        return (m / 60) + "h";
    }
    return (m / 1440) + "d";
}
