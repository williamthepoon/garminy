import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Colour and word for session states and alert kinds.
module Look {
    const STATE_WORDS = ["working", "needs you", "done", "error"];
    const STATE_COLORS = [Ui.BLUE, Ui.ACCENT, Ui.GREEN, Ui.RED];
    const KIND_WORDS = ["NEEDS YOU", "FAILED", "DONE"];
    const KIND_COLORS = [Ui.ACCENT, Ui.RED, Ui.GREEN];

    function stateColor(s as Number) as Number {
        return s >= 0 && s < STATE_COLORS.size() ? STATE_COLORS[s] : Ui.DIM;
    }

    function kindColor(k as Number) as Number {
        return k >= 0 && k < KIND_COLORS.size() ? KIND_COLORS[k] : Ui.DIM;
    }

    // Cuts text with "…" until it fits maxW pixels.
    function truncate(dc as Graphics.Dc, text as String, font as Graphics.FontType, maxW as Number) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        for (var n = text.length() - 1; n > 0; n--) {
            var t = text.substring(0, n) + "…";
            if (dc.getTextWidthInPixels(t, font) <= maxW) {
                return t;
            }
        }
        return "…";
    }

    // Width of the round screen at height y, less a margin.
    function chord(l as Layout, y as Number, margin as Number) as Number {
        var dy = (y - l.cy).abs();
        if (dy >= l.r) {
            return 0;
        }
        return (2 * Math.sqrt(l.r * l.r - dy * dy)).toNumber() - 2 * margin;
    }
}

// Claude Code sessions on the Mac, most urgent first (agent-status).
class AgentsCard extends Card {
    const ROWS = 3;
    var _c as Companion;

    function initialize(c as Companion) {
        Card.initialize();
        _c = c;
    }

    function id() as String {
        return "agents";
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        drawTitle(dc, l, "AGENTS");
        if (_c.versionMismatch) {
            drawMessage(dc, l, "Update garminy");
            return;
        }
        if (!_c.connected) {
            drawMessage(dc, l, "Mac offline");
            return;
        }
        var list = _c.sessions;
        if (list.size() == 0) {
            drawMessage(dc, l, "No agents running");
            return;
        }
        var top = l.boxY + l.h / 20;
        var rowH = (l.dotsY - 30 - top) / ROWS;
        var labelH = dc.getFontHeight(Graphics.FONT_TINY);
        var n = list.size() < ROWS ? list.size() : ROWS;
        var more = _c.moreSessions + list.size() - n;
        for (var i = 0; i < n; i++) {
            var s = list[i] as Array;
            var state = s[0] as Number;
            var y = top + i * rowH;
            var color = Look.stateColor(state);
            var label = Look.truncate(dc, s[2] as String, Graphics.FONT_TINY, Look.chord(l, y + labelH / 2, 14) - 14);
            var lw = dc.getTextWidthInPixels(label, Graphics.FONT_TINY);
            var x = l.cx - lw / 2;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 9, y + labelH / 2, 4);
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_LEFT);
            var word = state >= 0 && state < Look.STATE_WORDS.size() ? Look.STATE_WORDS[state] : "?";
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, y + labelH - 4, Graphics.FONT_XTINY,
                word + " · " + Ui.formatDuration((s[1] as Number) * 60), Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (more > 0) {
            dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, top + n * rowH - 2, Graphics.FONT_XTINY, "+" + more + " more", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

// Full-screen alert drawn over the current card (desk-alerts).
module AlertOverlay {
    function draw(dc as Graphics.Dc, l as Layout, c as Companion) as Void {
        var a = c.current();
        if (a == null) {
            return;
        }
        var kind = a[1] as Number;
        var color = Look.kindColor(kind);
        // Clear everything below the clock header and ring the screen in the kind's colour.
        dc.setColor(Ui.BG, Ui.BG);
        dc.fillRectangle(0, l.headerY + 16, l.w, l.h);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawCircle(l.cx, l.cy, l.r - 4);
        dc.setPenWidth(1);

        var word = kind >= 0 && kind < Look.KIND_WORDS.size() ? Look.KIND_WORDS[kind] : "ALERT";
        dc.drawText(l.cx, l.boxY - 4, Graphics.FONT_SMALL, word, Graphics.TEXT_JUSTIFY_CENTER);
        Ui.drawFitted(dc, a[3] as String, l.boxX, l.boxY + l.boxH / 5, l.boxW, l.boxH * 2 / 5, Ui.FG);
        var detail = a[4] as String;
        if (detail.length() > 0) {
            dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, l.boxY + l.boxH * 3 / 5 + 4, Graphics.FONT_XTINY, detail, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var foot = c.connected ? "Tap to dismiss" : "Mac offline";
        if (c.alertTotal > 1) {
            foot = "+" + (c.alertTotal - 1) + "  ·  " + foot;
        }
        dc.setColor(c.connected ? Ui.FAINT : Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.boxY + l.boxH - 18, Graphics.FONT_XTINY, foot, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
