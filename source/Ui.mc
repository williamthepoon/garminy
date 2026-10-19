import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Shared drawing and formatting helpers. Colours stay on the MIP 64-colour grid.
module Ui {
    const BG = Graphics.COLOR_BLACK;
    const FG = Graphics.COLOR_WHITE;
    const DIM = 0xAAAAAA;
    const FAINT = 0x555555;
    const ACCENT = 0xFFAA00;
    const BLUE = 0x55AAFF;
    const YELLOW = 0xFFFF55;
    const GREEN = 0x55FF55;
    const RED = 0xFF5555;

    // Vector text sizes go above the built-in fonts; set false to use built-in fonts only.
    const USE_VECTOR = true;
    const VECTOR_FACE = "RobotoCondensedBold";
    const VECTOR_MIN = 42;      // first size above FONT_LARGE's 40 px line
    const FIT_MAX = 56;         // largest size wrapped text starts from
    const MARGIN = 6;           // gap kept from the bezel

    var _vectors as Dictionary<Number, Graphics.VectorFont> = {} as Dictionary<Number, Graphics.VectorFont>;
    var _noVector as Boolean = false;
    var _fits as Dictionary<String, Array> = {} as Dictionary<String, Array>;

    function vector(px as Number) as Graphics.VectorFont? {
        if (!USE_VECTOR || _noVector || !(Graphics has :getVectorFont)) {
            return null;
        }
        var f = _vectors[px];
        if (f == null) {
            f = Graphics.getVectorFont({:face => VECTOR_FACE, :size => px});
            if (f == null) {
                _noVector = true;
                return null;
            }
            _vectors[px] = f;
        }
        return f;
    }

    // Candidate fonts, largest first: vector sizes from maxPx down to VECTOR_MIN,
    // then the built-in LARGE, MEDIUM, SMALL and, if minFont allows, TINY.
    function fonts(maxPx as Number, minFont as Graphics.FontDefinition) as Array<Graphics.FontType> {
        var out = [] as Array<Graphics.FontType>;
        for (var px = maxPx; px >= VECTOR_MIN; px -= 2) {
            var v = vector(px);
            if (v == null) {
                break;
            }
            out.add(v);
        }
        var builtIn = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY];
        for (var i = 0; i < builtIn.size(); i++) {
            if (builtIn[i] >= minFont) {
                out.add(builtIn[i]);
            }
        }
        return out;
    }

    function words(text as String) as Array<String> {
        var out = [] as Array<String>;
        var s = text;
        var i = s.find(" ");
        while (i != null) {
            if (i > 0) {
                out.add(s.substring(0, i) as String);
            }
            s = s.substring(i + 1, s.length()) as String;
            i = s.find(" ");
        }
        if (s.length() > 0) {
            out.add(s);
        }
        return out;
    }

    // Usable width for a line of height lh whose top is at y: the narrower of
    // the chords near its top and bottom.
    function lineWidth(l as Layout, y as Number, lh as Number) as Number {
        var a = l.chord(y + lh / 5, MARGIN);
        var b = l.chord(y + lh * 4 / 5, MARGIN);
        return a < b ? a : b;
    }

    // Wraps text into lines that each fit the round screen, with the block
    // centred between top and bottom. Never splits a word. Null if it cannot fit.
    function wrapRound(dc as Graphics.Dc, l as Layout, text as String, font as Graphics.FontType,
                       top as Number, bottom as Number) as Array<String>? {
        var lh = dc.getFontHeight(font);
        var maxK = (bottom - top) / lh;
        var ws = words(text);
        for (var k = 1; k <= maxK; k++) {
            var y0 = (top + bottom) / 2 - k * lh / 2;
            var lines = greedy(dc, l, ws, font, k, y0, lh);
            if (lines != null) {
                return lines;
            }
        }
        return null;
    }

    function greedy(dc as Graphics.Dc, l as Layout, ws as Array<String>, font as Graphics.FontType,
                    k as Number, y0 as Number, lh as Number) as Array<String>? {
        var lines = [] as Array<String>;
        var cur = "";
        for (var i = 0; i < ws.size(); i++) {
            var cand = cur.length() == 0 ? ws[i] : cur + " " + ws[i];
            if (dc.getTextWidthInPixels(cand, font) <= lineWidth(l, y0 + lines.size() * lh, lh)) {
                cur = cand;
                continue;
            }
            if (cur.length() == 0) {
                return null;
            }
            lines.add(cur);
            if (lines.size() >= k) {
                return null;
            }
            cur = ws[i];
            if (dc.getTextWidthInPixels(cur, font) > lineWidth(l, y0 + lines.size() * lh, lh)) {
                return null;
            }
        }
        if (cur.length() > 0) {
            lines.add(cur);
        }
        return lines;
    }

    // [font, lines] for the largest font at which text wraps between top and bottom, or null.
    function fit(dc as Graphics.Dc, l as Layout, text as String, top as Number, bottom as Number,
                 minFont as Graphics.FontDefinition) as Array? {
        var key = text + "|" + top + "|" + bottom + "|" + minFont;
        var hit = _fits[key];
        if (hit != null) {
            return hit;
        }
        var fs = fonts(FIT_MAX, minFont);
        for (var i = 0; i < fs.size(); i++) {
            var lines = wrapRound(dc, l, text, fs[i], top, bottom);
            if (lines != null) {
                if (_fits.size() >= 8) {
                    _fits = {} as Dictionary<String, Array>;
                }
                var r = [fs[i], lines];
                _fits[key] = r;
                return r;
            }
        }
        return null;
    }

    // Draws text wrapped to the round screen between top and bottom, using the
    // largest font that fits whole. Returns false if even minFont cannot fit it.
    function drawFitted(dc as Graphics.Dc, l as Layout, text as String, top as Number, bottom as Number,
                        color as Number, minFont as Graphics.FontDefinition) as Boolean {
        var r = fit(dc, l, text, top, bottom, minFont);
        if (r == null) {
            return false;
        }
        var font = r[0] as Graphics.FontType;
        var lines = r[1] as Array<String>;
        var lh = dc.getFontHeight(font);
        var y = (top + bottom) / 2 - lines.size() * lh / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(l.cx, y + i * lh, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        return true;
    }

    // Largest of fonts in which text fits the screen width on one line centred at y,
    // else the last (smallest) one.
    function fitLine(dc as Graphics.Dc, l as Layout, text as String, y as Number,
                     fs as Array<Graphics.FontType>) as Graphics.FontType {
        for (var i = 0; i < fs.size(); i++) {
            var lh = dc.getFontHeight(fs[i]);
            if (dc.getTextWidthInPixels(text, fs[i]) <= lineWidth(l, y - lh / 2, lh)) {
                return fs[i];
            }
        }
        return fs[fs.size() - 1];
    }

    // One line centred at y in the largest font that fits.
    function drawLine(dc as Graphics.Dc, l as Layout, text as String, y as Number,
                      fs as Array<Graphics.FontType>, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, y, fitLine(dc, l, text, y, fs), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function is24h() as Boolean {
        return System.getDeviceSettings().is24Hour;
    }

    // "14:05" or "2:05 pm" following the device setting.
    function formatHm(hour as Number, min as Number) as String {
        if (is24h()) {
            return hour.format("%02d") + ":" + min.format("%02d");
        }
        var h12 = hour % 12;
        if (h12 == 0) {
            h12 = 12;
        }
        return h12.toString() + ":" + min.format("%02d") + (hour < 12 ? "am" : "pm");
    }

    // ["2:05", "pm"] for a 12-hour time, ["14:05", ""] otherwise.
    function splitAmPm(t as String) as Array<String> {
        var n = t.length();
        if (n > 2 && (t.substring(n - 2, n).equals("am") || t.substring(n - 2, n).equals("pm"))) {
            return [t.substring(0, n - 2) as String, t.substring(n - 2, n) as String];
        }
        return [t, ""];
    }

    function formatMoment(m as Time.Moment) as String {
        var info = Gregorian.info(m, Time.FORMAT_SHORT);
        return formatHm(info.hour as Number, info.min as Number);
    }

    // "3h 12m" for a duration in seconds.
    function formatDuration(secs as Number) as String {
        if (secs < 0) {
            secs = 0;
        }
        var mins = secs / 60;
        var h = mins / 60;
        var m = mins % 60;
        return h > 0 ? h.toString() + "h " + m.toString() + "m" : m.toString() + "m";
    }
}
