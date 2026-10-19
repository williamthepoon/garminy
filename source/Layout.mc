import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Screen geometry derived from the display size, so the same code fits
// 218-280 px round screens without hard-coded pixel positions.
class Layout {
    var w as Number;
    var h as Number;
    var cx as Number;
    var cy as Number;
    var r as Number;
    var headerY as Number;   // vertical centre of the clock header
    var boxX as Number;      // content box: inscribed in the circle
    var boxY as Number;
    var boxW as Number;
    var boxH as Number;
    var dotsY as Number;     // page-indicator row

    function initialize(width as Number, height as Number) {
        w = width;
        h = height;
        cx = w / 2;
        cy = h / 2;
        r = (w < h ? w : h) / 2;
        headerY = (h * BOX_HEADER).toNumber();
        boxW = (w * BOX_W).toNumber();
        boxX = (w - boxW) / 2;
        boxY = (h * BOX_TOP).toNumber();
        boxH = (h * (BOX_BOTTOM - BOX_TOP)).toNumber();
        dotsY = (h * 0.88).toNumber();
    }

    // The same layout with the usable circle shrunk by px, e.g. inside the alert ring.
    function inset(px as Number) as Layout {
        var l = new Layout(w, h);
        l.r = r - px;
        return l;
    }

    // Width of the round screen at height y, less a margin on each side.
    function chord(y as Number, margin as Number) as Number {
        var dy = (y - cy).abs();
        if (dy >= r) {
            return 0;
        }
        return (2 * Math.sqrt(r * r - dy * dy)).toNumber() - 2 * margin;
    }
}

const BOX_HEADER = 0.10;
const BOX_W = 0.70;
const BOX_TOP = 0.18;
const BOX_BOTTOM = 0.84;

// True when every corner of the content box lies inside the round display.
function boxInsideCircle(width as Number, height as Number) as Boolean {
    var l = new Layout(width, height);
    var corners = [
        [l.boxX, l.boxY], [l.boxX + l.boxW, l.boxY],
        [l.boxX, l.boxY + l.boxH], [l.boxX + l.boxW, l.boxY + l.boxH]
    ];
    for (var i = 0; i < corners.size(); i++) {
        var dx = (corners[i][0] - l.cx).toFloat();
        var dy = (corners[i][1] - l.cy).toFloat();
        if (dx * dx + dy * dy > (l.r * l.r).toFloat()) {
            return false;
        }
    }
    return true;
}
