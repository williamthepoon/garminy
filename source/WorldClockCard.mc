import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

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
        drawTitle(dc, l, "WORLD CLOCK");
        var n = _cities.size();
        if (n == 0) {
            drawMessage(dc, l, "Choose cities in Garmin Connect");
            return;
        }
        var now = Time.now().value();
        var today = Dates.localTodayDays();
        var rowH = l.boxH * 3 / 4 / 3;
        var top = l.cy - (n * rowH) / 2 + l.h / 40;
        // Rows sit near the vertical centre, where the circle is widest.
        var left = (l.w * 0.10).toNumber();
        var right = l.w - left;
        for (var i = 0; i < n; i++) {
            var c = _cities[i];
            var t = TimeZones.cityTime(c, now);
            var y = top + i * rowH + rowH / 2;
            var isDay = t[0] >= 6 && t[0] < 18;
            drawDayNight(dc, left + 6, y, isDay);

            dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + 16, y, Graphics.FONT_XTINY, TimeZones.NAMES[c],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            var time = Ui.formatHm(t[0], t[1]);
            var diff = t[2] - today;
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(right, y, Graphics.FONT_TINY, time,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            if (diff != 0) {
                var tw = dc.getTextWidthInPixels(time, Graphics.FONT_TINY);
                dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(right - tw - 3, y, Graphics.FONT_XTINY, (diff > 0 ? "+" : "") + diff.toString(),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    function drawDayNight(dc as Graphics.Dc, x as Number, y as Number, isDay as Boolean) as Void {
        if (isDay) {
            dc.setColor(Ui.YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 4);
        } else {
            dc.setColor(Ui.BLUE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 5);
            dc.setColor(Ui.BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + 3, y - 2, 4);
        }
    }
}
