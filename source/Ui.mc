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

    const TEXT_FONTS = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];

    // Draws text wrapped into the box using the largest font that fits whole.
    // Returns false if even the smallest font cannot fit it.
    function drawFitted(dc as Graphics.Dc, text as String, x as Number, y as Number,
                        w as Number, h as Number, color as Number) as Boolean {
        for (var i = 0; i < TEXT_FONTS.size(); i++) {
            var font = TEXT_FONTS[i];
            var fitted = Graphics.fitTextToArea(text, font, w, h, false);
            if (fitted != null) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x + w / 2, y + h / 2, font, fitted,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return true;
            }
        }
        return false;
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
