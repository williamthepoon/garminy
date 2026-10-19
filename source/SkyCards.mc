import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Last known location: GPS fix, then weather observation, then cached value.
module LocationSource {
    const STORAGE_KEY = "loc";

    // First non-null candidate wins.
    function choose(candidates as Array<Array<Double>?>) as Array<Double>? {
        for (var i = 0; i < candidates.size(); i++) {
            if (candidates[i] != null) {
                return candidates[i];
            }
        }
        return null;
    }

    function fromPosition() as Array<Double>? {
        var info = Position.getInfo();
        if (info == null || info.position == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
            return null;
        }
        return valid((info.position as Position.Location).toDegrees());
    }

    function fromWeather() as Array<Double>? {
        var cc = Weather.getCurrentConditions();
        if (cc == null || cc.observationLocationPosition == null) {
            return null;
        }
        return valid((cc.observationLocationPosition as Position.Location).toDegrees());
    }

    function fromStorage() as Array<Double>? {
        var v = Application.Storage.getValue(STORAGE_KEY);
        if (v instanceof Array && v.size() == 2) {
            return [(v[0] as Numeric).toDouble(), (v[1] as Numeric).toDouble()];
        }
        return null;
    }

    function valid(deg as Array) as Array<Double>? {
        var lat = (deg[0] as Numeric).toDouble();
        var lon = (deg[1] as Numeric).toDouble();
        if ((lat == 0.0d && lon == 0.0d) || lat.abs() > 90.0d || lon.abs() > 180.0d) {
            return null;
        }
        return [lat, lon];
    }

    function get() as Array<Double>? {
        var live = choose([fromPosition(), fromWeather()]);
        if (live != null) {
            // Only write when the location moves (~1 km), to spare flash storage.
            var cached = fromStorage();
            if (cached == null || (cached[0] - live[0]).abs() > 0.01d || (cached[1] - live[1]).abs() > 0.01d) {
                Application.Storage.setValue(STORAGE_KEY, [live[0].toFloat(), live[1].toFloat()]);
            }
            return live;
        }
        return choose([fromStorage(), fromMac()]);
    }

    // Last location sent by the Mac companion.
    function fromMac() as Array<Double>? {
        var m = MacWeather.location();
        return m == null ? null : valid(m);
    }
}

// "Xh Ym left" by day, "Sunrise in Xh Ym" at night (nextRise 0 = none tomorrow).
function daylightLine(now as Number, rise as Number, set as Number, nextRise as Number) as String {
    if (now >= rise && now < set) {
        return Ui.formatDuration(set - now) + " left";
    }
    var target = now < rise ? rise : nextRise;
    return target > 0 ? "Sunrise in " + Ui.formatDuration(target - now) : "No sunrise tomorrow";
}

// "Full Fri 24": the next full moon is always less than a month away.
function fullMoonLine(m as Time.Moment) as String {
    var full = Gregorian.info(m, Time.FORMAT_MEDIUM);
    return "Full " + full.day_of_week + " " + full.day.toString();
}

class DaylightCard extends Card {
    var _status as Number = -1;    // -1 = unknown location
    var _rise as Number = 0;
    var _set as Number = 0;
    var _nextRise as Number = 0;

    function initialize() {
        Card.initialize();
    }

    function id() as String {
        return "daylight";
    }

    function refresh() as Void {
        var loc = LocationSource.get();
        if (loc == null) {
            _status = -1;
            return;
        }
        var t = Dates.localToday();
        var r = SunCalc.compute(t[0], t[1], t[2], loc[0], loc[1]);
        _status = r[0];
        _rise = r[1];
        _set = r[2];
        // Tomorrow's sunrise for the evening "Sunrise in" line.
        var tm = Gregorian.info(Time.today().add(new Time.Duration(86400 + 3600)), Time.FORMAT_SHORT);
        var r2 = SunCalc.compute(tm.year as Number, tm.month as Number, tm.day as Number, loc[0], loc[1]);
        _nextRise = r2[0] == SunCalc.NORMAL ? r2[1] : 0;
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        if (_status == -1) {
            drawMessage(dc, l, "Location unknown - get a GPS fix or run the Mac companion");
            return;
        }
        if (_status == SunCalc.SUN_UP_ALL_DAY) {
            drawMessage(dc, l, "Sun up all day");
            return;
        }
        if (_status == SunCalc.NO_SUNRISE) {
            drawMessage(dc, l, "No sunrise today");
            return;
        }

        var now = Time.now().value();
        var ar = (l.h * 0.27).toNumber();
        var ay = l.cy + l.h / 20;
        var day = now >= _rise && now < _set;

        // Horizon and arc.
        dc.setColor(Ui.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(l.cx - ar - 6, ay, l.cx + ar + 6, ay);
        dc.setColor(day ? Ui.ACCENT : Ui.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(l.cx, ay, ar, Graphics.ARC_CLOCKWISE, 180, 0);
        dc.setPenWidth(1);

        if (day) {
            var frac = (now - _rise).toFloat() / (_set - _rise).toFloat();
            var a = Math.PI * (1.0 - frac);
            var sx = l.cx + (ar * Math.cos(a)).toNumber();
            var sy = ay - (ar * Math.sin(a)).toNumber();
            dc.setColor(Ui.YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, 8);
        }

        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        var ty = ay + l.h / 14;
        dc.drawText(l.cx - ar, ty, Graphics.FONT_SMALL, Ui.formatMoment(new Time.Moment(_rise)),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(l.cx + ar, ty, Graphics.FONT_SMALL, Ui.formatMoment(new Time.Moment(_set)),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        Ui.drawLine(dc, l, daylightLine(now, _rise, _set, _nextRise), ty + l.h / 7,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>, Ui.FG);
    }
}

class MoonCard extends Card {
    var _age as Double = 0.0d;
    var _nextFull as Number = 0;

    function initialize() {
        Card.initialize();
    }

    function id() as String {
        return "moon";
    }

    function refresh() as Void {
        var now = Time.now().value();
        _age = MoonCalc.age(now);
        _nextFull = MoonCalc.nextFullMoon(now);
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        var mr = l.h / 8;
        var my = l.cy - l.h / 8;
        drawMoon(dc, l.cx - l.w / 6, my, mr, _age);

        var illum = Math.round(MoonCalc.illumination(_age) * 100.0d).toNumber();
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx + l.w / 6, my, Graphics.FONT_NUMBER_MILD, illum.toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var ny = my + mr + l.h / 10;
        Ui.drawLine(dc, l, MoonCalc.NAMES[MoonCalc.phaseIndex(_age)], ny,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>, Ui.FG);
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, ny + l.h / 7, Graphics.FONT_SMALL, fullMoonLine(new Time.Moment(_nextFull)),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Dark disc plus the lit region bounded by the limb and the terminator
    // ellipse. Northern-hemisphere view: waxing is lit on the right.
    function drawMoon(dc as Graphics.Dc, x as Number, y as Number, r as Number, a as Double) as Void {
        dc.setColor(Ui.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        var phase = 2.0d * Math.PI * a / MoonCalc.SYNODIC;
        var k = Math.cos(phase);
        var waxing = a < MoonCalc.SYNODIC / 2.0d;
        var steps = 20;
        var right = [] as Array<[Numeric, Numeric]>;
        var left = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i <= steps; i++) {
            var yy = -r + 2.0d * r * i / steps;
            var half = Math.sqrt(r * r - yy * yy);
            var x1 = waxing ? k * half : -half;
            var x2 = waxing ? half : -k * half;
            right.add([x + x2.toNumber(), y + yy.toNumber()]);
            left.add([x + x1.toNumber(), y + yy.toNumber()]);
        }
        var pts = right;
        for (var i = left.size() - 1; i >= 0; i--) {
            pts.add(left[i]);
        }
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
    }
}
