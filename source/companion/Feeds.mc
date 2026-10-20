import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Text sets from the Mac, one per channel, saved so they survive restarts (mac-content-feeds).
// Not part of the glance. Times are stored in watch-clock seconds; a missing time is null.
module Feeds {
    const NEWS = 0;
    const QUOTE = 1;
    const FORTUNE = 2;
    const ON_THIS_DAY = 3;
    const CHANNELS = [NEWS, QUOTE, FORTUNE, ON_THIS_DAY];
    const MAX_ITEMS = 12;

    var _cache as Dictionary = {};
    var _cursor as Dictionary = {};

    // items: [[stamp, source, text], ...]. News stamps are Mac times (0 = none) and are converted to
    // watch time; on other channels the stamp is a plain number (on-this-day: the year).
    function save(channel as Number, batch as Number, items as Array, macOffset as Number) as Void {
        var out = [];
        for (var i = 0; i < items.size(); i++) {
            var it = items[i] as Array;
            var stamp = it[0];
            if (stamp instanceof Long) {
                stamp = stamp.toNumber();
            }
            if (channel == NEWS) {
                stamp = stamp == 0 ? null : (stamp as Number) - macOffset;
            }
            out.add([stamp, it[1], it[2]]);
        }
        var set = { "batch" => batch, "batchAt" => batch - macOffset, "receivedAt" => Time.now().value(), "items" => out };
        Application.Storage.setValue("feed" + channel, set);
        _cache[channel] = set;
    }

    // {"batch", "receivedAt", "items"} or null.
    function get(channel as Number) as Dictionary? {
        if (!_cache.hasKey(channel)) {
            var s = Application.Storage.getValue("feed" + channel);
            _cache[channel] = s instanceof Dictionary ? s : false;
        }
        var c = _cache[channel];
        return c instanceof Dictionary ? c : null;
    }

    // Moves the channel's cursor to the next item and returns it, wrapping after the last.
    function advance(channel as Number, n as Number) as Number {
        var i = _cursor.hasKey(channel) ? (_cursor[channel] as Number) + 1 : 0;
        i = n > 0 ? i % n : 0;
        _cursor[channel] = i;
        return i;
    }

    function setCursor(channel as Number, i as Number) as Void {
        _cursor[channel] = i;
    }

    function cursor(channel as Number) as Number {
        return _cursor.hasKey(channel) ? _cursor[channel] as Number : 0;
    }

    // Tests only.
    function reset(channel as Number) as Void {
        _cache.remove(channel);
        _cursor.remove(channel);
        Application.Storage.deleteValue("feed" + channel);
    }
}
