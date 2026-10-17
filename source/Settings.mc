import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Reads the user's Garmin Connect settings (resources/settings).
module Settings {
    // Fixed display order of the cards.
    const CARD_IDS = ["fortune", "quote", "umbrella", "weather", "daylight", "moon", "world", "onthisday"];
    const CARD_KEYS = ["cardFortune", "cardQuote", "cardUmbrella", "cardWeather",
                       "cardDaylight", "cardMoon", "cardWorld", "cardOnThisDay"];
    const INTERVALS = [5, 10, 20, 30, 60];
    const UNITS_DEVICE = 0;
    const UNITS_C = 1;
    const UNITS_F = 2;

    function get(key as String, fallback) {
        try {
            var v = Application.Properties.getValue(key);
            return v == null ? fallback : v;
        } catch (e) {
            return fallback;
        }
    }

    function enabledIds() as Array<String> {
        var ids = [] as Array<String>;
        for (var i = 0; i < CARD_IDS.size(); i++) {
            if (get(CARD_KEYS[i], true) == true) {
                ids.add(CARD_IDS[i]);
            }
        }
        return ids;
    }

    function interval() as Number {
        var v = get("interval", 10);
        return INTERVALS.indexOf(v) >= 0 ? v as Number : 10;
    }

    // City indexes into TimeZones; -1 means "None".
    function cities() as Array<Number> {
        var out = [] as Array<Number>;
        var keys = ["city1", "city2", "city3"];
        var defaults = [TimeZones.SAN_FRANCISCO, TimeZones.SINGAPORE, TimeZones.MONTREAL];
        for (var i = 0; i < keys.size(); i++) {
            var c = get(keys[i], defaults[i]) as Number;
            if (c >= 0 && c < TimeZones.NAMES.size()) {
                out.add(c);
            }
        }
        return out;
    }

    function useFahrenheit() as Boolean {
        var u = get("units", UNITS_DEVICE);
        if (u == UNITS_F) {
            return true;
        } else if (u == UNITS_C) {
            return false;
        }
        return System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE;
    }

    // Weather temperatures arrive in Celsius.
    function formatTemp(celsius as Numeric?) as String {
        if (celsius == null) {
            return "--";
        }
        var t = useFahrenheit() ? celsius.toFloat() * 9.0 / 5.0 + 32.0 : celsius.toFloat();
        return Math.round(t).toNumber().toString() + "°";
    }
}
