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

    // Called each time the card becomes the current one, by rotation or UP/DOWN.
    function shown() as Void {
    }

    // Called once per rotation interval while the card is pinned or the only card.
    // Returns true when the card changed and needs a redraw.
    function tick() as Boolean {
        return false;
    }

    // Draw inside the layout's content area (the header is drawn by the carousel).
    function draw(dc as Graphics.Dc, l as Layout) as Void {
    }
}

// Shows a centred, wrapped message in the content area. Used for empty and no-data states.
function drawMessage(dc as Graphics.Dc, l as Layout, text as String) as Void {
    Ui.drawFitted(dc, l, text, l.boxY, l.boxY + l.boxH, Ui.FG, Graphics.FONT_SMALL);
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
