import Toybox.Graphics;
import Toybox.Lang;

// Colour and word for session states and alert kinds.
module Look {
    const STATE_WORDS = ["busy", "waiting", "done", "error"];
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
}

const AGENT_ROWS = 2;

// Claude Code sessions on the Mac, most urgent first (agent-status).
class AgentsCard extends Card {
    var _c as Companion;

    function initialize(c as Companion) {
        Card.initialize();
        _c = c;
    }

    function id() as String {
        return "agents";
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
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
        var labelH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var stateH = dc.getFontHeight(Graphics.FONT_SMALL);
        var rowH = labelH + stateH;
        var n = shownSessions(list.size());
        var more = hiddenSessions(list.size(), _c.moreSessions);
        var top = l.boxY + (l.boxH - n * rowH - (more > 0 ? stateH : 0)) / 2;
        for (var i = 0; i < n; i++) {
            var s = list[i] as Array;
            var state = s[0] as Number;
            var y = top + i * rowH;
            var color = Look.stateColor(state);
            var label = Look.truncate(dc, s[2] as String, Graphics.FONT_MEDIUM, l.chord(y + labelH / 2, 14) - 20);
            var lw = dc.getTextWidthInPixels(label, Graphics.FONT_MEDIUM);
            var x = l.cx - lw / 2 + 8;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 12, y + labelH / 2, 6);
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_MEDIUM, label, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, y + labelH - 4, Graphics.FONT_SMALL, stateLine(state, s[1] as Number),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (more > 0) {
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, top + n * rowH, Graphics.FONT_SMALL, "+" + more, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

// Rows shown on the Agents card for count sessions received.
function shownSessions(count as Number) as Number {
    return count < AGENT_ROWS ? count : AGENT_ROWS;
}

// Sessions not shown: those received but beyond the rows, plus those the Mac held back.
function hiddenSessions(count as Number, held as Number) as Number {
    return held + count - shownSessions(count);
}

// "waiting · 3m"
function stateLine(state as Number, minutes as Number) as String {
    var word = state >= 0 && state < Look.STATE_WORDS.size() ? Look.STATE_WORDS[state] : "?";
    return word + " · " + Ui.formatDuration(minutes * 60);
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
        // Fit text inside the ring, not the bezel.
        var rl = l.inset(10);
        Ui.drawLine(dc, rl, word, l.boxY + l.h / 14, Ui.fonts(44, Graphics.FONT_SMALL), color);
        var top = l.boxY + l.h / 6;
        var bottom = l.cy + l.h / 15;
        if (!Ui.drawFitted(dc, rl, a[3] as String, top, bottom, Ui.FG, Graphics.FONT_SMALL)) {
            // A long unbroken label: one SMALL line, cut with "…".
            var y = (top + bottom) / 2;
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, y, Graphics.FONT_SMALL,
                Look.truncate(dc, a[3] as String, Graphics.FONT_SMALL, Ui.lineWidth(rl, y - 16, 32)),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var detail = a[4] as String;
        if (detail.length() > 0) {
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(l.cx, l.cy + l.h / 8, Graphics.FONT_SMALL, detail,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var foot = c.connected ? (c.opensOnTap(a) ? "Tap to open" : "Tap to dismiss") : "Mac offline";
        if (c.alertTotal > 1) {
            foot = "+" + (c.alertTotal - 1) + " · " + foot;
        }
        dc.setColor(c.connected ? Ui.DIM : Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.cy + l.h / 4, Graphics.FONT_SMALL, foot,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
