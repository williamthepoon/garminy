import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

const NO_WEATHER = "No weather - pair a phone or run the Mac companion";
const STALE_SECS = 3 * 3600;

// "72/55": high and low without degree signs, "--" for a missing value.
function hiLo(high as Numeric?, low as Numeric?) as String {
    return tempDigits(high) + "/" + tempDigits(low);
}

function tempDigits(celsius as Numeric?) as String {
    var t = Settings.formatTemp(celsius);
    return celsius == null ? t : t.substring(0, t.length() - 1) as String;
}

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
        dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.boxY + l.boxH - l.h / 16, Graphics.FONT_SMALL, note,
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
        var iconY = l.boxY + l.h / 11;
        if (_data == null) {
            WeatherIcons.drawUmbrella(dc, l.cx, iconY, l.h / 11, Ui.FG);
            Ui.drawFitted(dc, l, NO_WEATHER, iconY + l.h / 10, l.boxY + l.boxH, Ui.FG, Graphics.FONT_SMALL);
            return;
        }
        var d = _data as Array<Number>;
        var colors = [Ui.FG, Ui.YELLOW, Ui.BLUE];
        WeatherIcons.drawUmbrella(dc, l.cx, iconY, l.h / 11, colors[d[0]]);
        Ui.drawLine(dc, l, Umbrella.LABELS[d[0]], l.cy - l.h / 40, Ui.fonts(64, Graphics.FONT_LARGE), colors[d[0]]);

        var detail = d[1].toString() + "%";
        if (d[2] >= 0) {
            // The forecast hour may already have started: say "now" rather than a past time.
            detail += d[2] <= Time.now().value() ? " now" : " at " + Ui.formatMoment(new Time.Moment(d[2]));
        }
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.cy + l.h / 7, Graphics.FONT_MEDIUM, detail,
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
        if (!_has) {
            drawMessage(dc, l, NO_WEATHER);
            return;
        }
        var colW = l.boxW / 2;
        drawDay(dc, l, l.boxX + colW / 2, "Today", _today, _current);
        drawDay(dc, l, l.boxX + colW + colW / 2, "Tomorrow", _tomorrow, null);
        dc.setColor(Ui.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(l.cx, l.boxY + l.h / 20, l.cx, l.cy + l.h / 4);
        drawStale(dc, l, _stale);
    }

    function drawDay(dc as Graphics.Dc, l as Layout, x as Number, label as String,
                     day as Array?, current as Numeric?) as Void {
        var colW = l.boxW / 2 - 4;
        if (dc.getTextWidthInPixels(label, Graphics.FONT_SMALL) > colW) {
            label = label.equals("Tomorrow") ? "Tmrw" : label;
        }
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, l.boxY + l.h / 16, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (day == null) {
            dc.drawText(x, l.cy, Graphics.FONT_MEDIUM, "--", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        WeatherIcons.draw(dc, x, l.cy - l.h / 8, l.w / 11, WeatherIcons.group(day[0] as Number?));
        var lineY = l.cy + l.h / 24;
        if (current != null) {
            var t = Settings.formatTemp(current);
            var f = dc.getTextWidthInPixels(t, Graphics.FONT_NUMBER_MILD) <= colW ? Graphics.FONT_NUMBER_MILD : Graphics.FONT_MEDIUM;
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, lineY, f, t, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            lineY += l.h / 7;
        }
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, lineY, Graphics.FONT_MEDIUM, hiLo(day[1] as Numeric?, day[2] as Numeric?),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
