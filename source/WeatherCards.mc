import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

const NO_WEATHER = "No weather - pair a phone or run the Mac companion";
const STALE_SECS = 3 * 3600;

// "Updated 5h ago" when the observation is older than 3 hours, else null.
function staleNote(observed as Number?, now as Number) as String? {
    if (observed == null || now - observed <= STALE_SECS) {
        return null;
    }
    return "Updated " + ((now - observed) / 3600).toString() + "h ago";
}

function observationTime() as Number? {
    return WeatherSource.observed();
}

function drawStale(dc as Graphics.Dc, l as Layout, note as String?) as Void {
    if (note != null) {
        dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.boxY + l.boxH - 4, Graphics.FONT_XTINY, note,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class UmbrellaCard extends Card {
    var _data as Array<Number>? = null;
    var _stale as String? = null;

    function initialize() {
        Card.initialize();
    }

    function id() as String {
        return "umbrella";
    }

    function refresh() as Void {
        _data = Umbrella.read();
        _stale = staleNote(observationTime(), Time.now().value());
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        drawTitle(dc, l, "UMBRELLA?");
        if (_data == null) {
            drawMessage(dc, l, NO_WEATHER);
            return;
        }
        var d = _data as Array<Number>;
        var colors = [Ui.FG, Ui.YELLOW, Ui.BLUE];
        dc.setColor(colors[d[0]], Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.cy - l.h / 20, Graphics.FONT_LARGE, Umbrella.LABELS[d[0]],
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var detail = d[1].toString() + "%";
        if (d[2] >= 0) {
            // The forecast hour may already have started: say "now" rather than a past time.
            detail += d[2] <= Time.now().value() ? " now" : " at " + Ui.formatMoment(new Time.Moment(d[2]));
        }
        dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.cy + l.h / 9, Graphics.FONT_SMALL, detail,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawStale(dc, l, _stale);
    }
}

class WeatherCard extends Card {
    // [condition, high, low] per day, entries may be null.
    var _today as Array? = null;
    var _tomorrow as Array? = null;
    var _current as Numeric? = null;
    var _has as Boolean = false;
    var _stale as String? = null;

    function initialize() {
        Card.initialize();
    }

    function id() as String {
        return "weather";
    }

    function refresh() as Void {
        var w = WeatherSource.mac();
        if (w != null) {
            // The Mac sends [high, low, condition]; the card uses [condition, high, low].
            var d = w["today"] as Array;
            var t = w["tomorrow"] as Array;
            _today = [d[2], d[0], d[1]];
            _tomorrow = [t[2], t[0], t[1]];
            _current = w["temp"] as Numeric?;
            _has = true;
            _stale = staleNote(w["observed"] as Number, Time.now().value());
            return;
        }
        var cc = Weather.getCurrentConditions();
        _has = cc != null;
        _today = null;
        _tomorrow = null;
        _current = null;
        if (cc != null) {
            _current = cc.temperature;
            _today = [cc.condition, cc.highTemperature, cc.lowTemperature];
        }
        var daily = Weather.getDailyForecast();
        if (daily != null) {
            var todayStart = Time.today().value();
            for (var i = 0; i < daily.size(); i++) {
                var f = daily[i];
                if (f.forecastTime == null) {
                    continue;
                }
                var t = (f.forecastTime as Time.Moment).value();
                var entry = [f.condition, f.highTemperature, f.lowTemperature];
                if (t >= todayStart && t < todayStart + 86400) {
                    _today = entry;
                    _has = true;
                } else if (t >= todayStart + 86400 && t < todayStart + 2 * 86400) {
                    _tomorrow = entry;
                    _has = true;
                }
            }
        }
        _stale = staleNote(observationTime(), Time.now().value());
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        drawTitle(dc, l, "WEATHER");
        if (!_has) {
            drawMessage(dc, l, NO_WEATHER);
            return;
        }
        var colW = l.boxW / 2;
        drawDay(dc, l, l.boxX + colW / 2, "Today", _today, _current);
        drawDay(dc, l, l.boxX + colW + colW / 2, "Tomorrow", _tomorrow, null);
        dc.setColor(Ui.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(l.cx, l.boxY + l.boxH / 5, l.cx, l.boxY + l.boxH * 4 / 5);
        drawStale(dc, l, _stale);
    }

    function drawDay(dc as Graphics.Dc, l as Layout, x as Number, label as String,
                     day as Array?, current as Numeric?) as Void {
        var y = l.boxY + l.boxH / 5;
        dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (day == null) {
            dc.drawText(x, l.cy, Graphics.FONT_SMALL, "--", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var size = l.w / 13;
        WeatherIcons.draw(dc, x, l.cy - l.h / 40, size, WeatherIcons.group(day[0] as Number?));
        var lineY = l.cy + l.h / 8;
        if (current != null) {
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, lineY, Graphics.FONT_SMALL, Settings.formatTemp(current),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            lineY += l.h / 11;
        }
        dc.setColor(current != null ? Ui.DIM : Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, lineY, Graphics.FONT_XTINY,
            Settings.formatTemp(day[1] as Numeric?) + " / " + Settings.formatTemp(day[2] as Numeric?),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
