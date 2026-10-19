import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

const CLOCK_GAP = 6;

class WorldClockCard extends Card {
    var _cities as Array<Number> = [] as Array<Number>;

    function initialize() {
        Card.initialize();
    }

    function id() as String {
        return "world";
    }

    function refresh() as Void {
        _cities = Settings.cities();
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        var n = _cities.size();
        if (n == 0) {
            drawMessage(dc, l, "Choose cities in Garmin Connect");
            return;
        }
        var now = Time.now().value();
        var today = Dates.localTodayDays();
        var rowH = l.boxH / 3;
        var top = l.boxY + (l.boxH - n * rowH) / 2;
        var icon = rowH / 8;

        var codes = [] as Array<String>;
        var times = [] as Array<Array<String>>;
        var diffs = [] as Array<Number>;
        var day = [] as Array<Boolean>;
        // Rows share the left and right edges of the narrowest row.
        var avail = l.w;
        for (var i = 0; i < n; i++) {
            var c = _cities[i];
            var t = TimeZones.cityTime(c, now);
            codes.add(TimeZones.CODES[c]);
            times.add(Ui.splitAmPm(Ui.formatHm(t[0], t[1])));
            diffs.add(t[2] - today);
            day.add(t[0] >= 6 && t[0] < 18);
            var rowTop = top + i * rowH;
            var w = Ui.lineWidth(l, rowTop, rowH);
            avail = w < avail ? w : avail;
        }
        var lead = 2 * icon + CLOCK_GAP;
        var font = timeFont(dc, codes, times, diffs, avail - lead);
        var left = l.cx - avail / 2;
        var right = l.cx + avail / 2;
        for (var i = 0; i < n; i++) {
            var y = top + i * rowH + rowH / 2;
            drawDayNight(dc, left + icon, y, icon, day[i]);
            var x = left + lead;
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_SMALL, codes[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            if (diffs[i] != 0) {
                x += dc.getTextWidthInPixels(codes[i], Graphics.FONT_SMALL) + 3;
                dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, y, Graphics.FONT_SMALL, dayMarker(diffs[i]), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            var tr = right;
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            if (times[i][1].length() > 0) {
                dc.drawText(tr, y, Graphics.FONT_SMALL, times[i][1], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                tr -= dc.getTextWidthInPixels(times[i][1], Graphics.FONT_SMALL) + 2;
            }
            dc.drawText(tr, y, font, times[i][0], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawDayNight(dc as Graphics.Dc, x as Number, y as Number, r as Number, isDay as Boolean) as Void {
        if (isDay) {
            dc.setColor(Ui.YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r * 4 / 5);
        } else {
            dc.setColor(Ui.BLUE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
            dc.setColor(Ui.BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + r * 3 / 5, y - r * 2 / 5, r * 4 / 5);
        }
    }
}

function dayMarker(diff as Number) as String {
    return (diff > 0 ? "+" : "") + diff.toString();
}

// One font for every row's time: the large numerals if every row fits in avail
// pixels (code, day marker, time digits and am/pm), else MEDIUM, else SMALL.
function timeFont(dc as Graphics.Dc, codes as Array<String>, times as Array<Array<String>>,
                  diffs as Array<Number>, avail as Number) as Graphics.FontDefinition {
    var fs = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM];
    for (var f = 0; f < fs.size(); f++) {
        var fits = true;
        for (var i = 0; i < codes.size() && fits; i++) {
            var w = dc.getTextWidthInPixels(codes[i], Graphics.FONT_SMALL) + CLOCK_GAP
                + dc.getTextWidthInPixels(times[i][0], fs[f]);
            if (diffs[i] != 0) {
                w += dc.getTextWidthInPixels(dayMarker(diffs[i]), Graphics.FONT_SMALL) + 3;
            }
            if (times[i][1].length() > 0) {
                w += dc.getTextWidthInPixels(times[i][1], Graphics.FONT_SMALL) + 2;
            }
            fits = w <= avail;
        }
        if (fits) {
            return fs[f];
        }
    }
    return Graphics.FONT_SMALL;
}
