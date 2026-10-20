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
        var t = _cut.hasKey(text) ? _cut[text] as String : text;
        while (!Ui.drawFitted(dc, l, t, top, bottom, Ui.FG, _minFont)) {
            var sp = lastSpace(t.substring(0, t.length() - 1) as String);
            if (sp <= 0) {
                return;
            }
            t = (t.substring(0, sp) as String) + "…";
            if (_cut.size() >= 4) {
                _cut = {};
            }
            _cut[text] = t;
        }
    }

    function lastSpace(s as String) as Number {
        var chars = s.toCharArray();
        for (var i = chars.size() - 1; i > 0; i--) {
            if (chars[i] == ' ') {
                return i;
            }
        }
        return -1;
    }
}

// Ages like "25 min ago", "3 h ago" or "2 d ago".
function ageText(seconds as Number) as String {
    var m = seconds / 60;
    if (m < 1) {
        return "just now";
    } else if (m < 60) {
        return m + " min ago";
    } else if (m < 48 * 60) {
        return (m / 60) + " h ago";
    }
    return (m / 1440) + " d ago";
}
