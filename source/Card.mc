import Toybox.Graphics;
import Toybox.Lang;

// Base class for every carousel card.
class Card {
    function initialize() {
    }

    // Stable identifier used to keep the current card across settings changes.
    function id() as String {
        return "";
    }

    // Re-read data. Called when the card is shown and on every minute tick.
    function refresh() as Void {
    }

    // Draw inside the layout's content area (the header is drawn by the carousel).
    function draw(dc as Graphics.Dc, l as Layout) as Void {
    }
}

// Shows a centred, wrapped message below the card title. Used for empty and no-data states.
function drawMessage(dc as Graphics.Dc, l as Layout, text as String) as Void {
    var top = l.boxY + l.h / 14;
    Ui.drawFitted(dc, text, l.boxX, top, l.boxW, l.boxY + l.boxH - top, Ui.DIM);
}

// Small title line at the top of the content area.
function drawTitle(dc as Graphics.Dc, l as Layout, text as String) as Void {
    dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
    dc.drawText(l.cx, l.boxY, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
}

function makeCard(id as String) as Card? {
    if (id.equals("fortune")) {
        return new FortuneCard();
    } else if (id.equals("quote")) {
        return new QuoteCard();
    } else if (id.equals("umbrella")) {
        return new UmbrellaCard();
    } else if (id.equals("weather")) {
        return new WeatherCard();
    } else if (id.equals("daylight")) {
        return new DaylightCard();
    } else if (id.equals("moon")) {
        return new MoonCard();
    } else if (id.equals("world")) {
        return new WorldClockCard();
    } else if (id.equals("onthisday")) {
        return new OnThisDayCard();
    }
    return null;
}
