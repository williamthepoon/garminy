import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance: app name plus today's umbrella verdict (or a launch hint).
// Tapping it opens the carousel, which is how the app starts without START.
(:glance)
class GarminyGlance extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 4, Graphics.FONT_GLANCE, "GARMINY", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var summary = "Tap to open";
        var u = Umbrella.read();
        if (u != null) {
            summary = "Umbrella: " + Umbrella.LABELS[u[0]] + " · " + u[1].toString() + "%";
        }
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 3 / 4, Graphics.FONT_GLANCE, summary, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
