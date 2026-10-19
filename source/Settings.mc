import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

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

    function agentsEnabled() as Boolean {
        return get("cardAgents", true) == true;
    }

    // Enabled card ids in display order. "agents" is included when its toggle and the
    // companion are on; the carousel drops it until a Mac has connected.
    function enabledIds() as Array<String> {
        var ids = [] as Array<String>;
        if (agentsEnabled() && companion()) {
            ids.add("agents");
        }
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

    const BACKLIGHT_LEVELS = [0.0, 0.3, 0.6, 1.0];

    // Brightness to hold the backlight at; 0.0 means leave it to the device.
    function backlightLevel() as Float {
        var v = get("backlight", 0);
        return (v instanceof Number && v >= 0 && v < BACKLIGHT_LEVELS.size()) ? BACKLIGHT_LEVELS[v] as Float : 0.0;
    }

    function companion() as Boolean {
        return get("companion", true) == true;
    }

    // Card toggle bits for the wire: bit 0 Agents, then CARD_KEYS in order.
    function cardBits() as Number {
        var bits = get("cardAgents", true) == true ? 1 : 0;
        for (var i = 0; i < CARD_KEYS.size(); i++) {
            if (get(CARD_KEYS[i], true) == true) {
                bits |= 1 << (i + 1);
            }
        }
        return bits;
    }

    // Every setting, in the layout Proto.settings sends to the Mac.
    function snapshot() as Dictionary {
        var at = Application.Storage.getValue("settingsChangedAt");
        return {
            :changedAt => at instanceof Number ? at : 0,
            :cards => cardBits(),
            :interval => interval(),
            :cities => [get("city1", TimeZones.SAN_FRANCISCO), get("city2", TimeZones.SINGAPORE), get("city3", TimeZones.MONTREAL)],
            :units => get("units", UNITS_DEVICE),
            :backlight => get("backlight", 0),
            :companion => companion(),
            :chargerSignal => get("chargerSignal", 1),
            :beepSound => get("beepSound", 0)
        };
    }

    // Applies settings sent by the Mac when they are newer than the watch's own.
    // Returns true when anything was written.
    function applyRemote(d as Dictionary) as Boolean {
        var at = d[:changedAt] as Number;
        var mine = Application.Storage.getValue("settingsChangedAt");
        if (mine instanceof Number && at <= mine) {
            return false;
        }
        var bits = d[:cards] as Number;
        Application.Properties.setValue("cardAgents", (bits & 1) != 0);
        for (var i = 0; i < CARD_KEYS.size(); i++) {
            Application.Properties.setValue(CARD_KEYS[i], (bits & (1 << (i + 1))) != 0);
        }
        Application.Properties.setValue("interval", d[:interval] as Number);
        var cities = d[:cities] as Array;
        var keys = ["city1", "city2", "city3"];
        for (var i = 0; i < 3; i++) {
            Application.Properties.setValue(keys[i], cities[i] as Number);
        }
        Application.Properties.setValue("units", d[:units] as Number);
        Application.Properties.setValue("backlight", d[:backlight] as Number);
        Application.Properties.setValue("companion", d[:companion] as Boolean);
        Application.Properties.setValue("chargerSignal", d[:chargerSignal] as Number);
        Application.Properties.setValue("beepSound", d[:beepSound] as Number);
        Application.Storage.setValue("settingsChangedAt", at);
        return true;
    }

    // Records a change made in Garmin Connect, in Mac-comparable seconds.
    function markChanged(macOffset as Number) as Void {
        Application.Storage.setValue("settingsChangedAt", Time.now().value() + macOffset);
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
