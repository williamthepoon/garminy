import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Text sets from the Mac, one per channel, saved so they survive restarts (mac-content-feeds).
// Not part of the glance. Times are stored in watch-clock seconds; a missing time is null.
module Feeds {
    const NEWS = 0;
    // Channels this build shows. Quote, fortune and on-this-day (1-3) come with fresh-daily-cards.
    const CHANNELS = [NEWS];
    const MAX_ITEMS = 12;

    var _cache as Dictionary = {};
    var _cursor as Dictionary = {};

    // items: [[stamp, source, text], ...] with stamps in Mac time (0 = none).
    function save(channel as Number, batch as Number, items as Array, macOffset as Number) as Void {
        var out = [];
        for (var i = 0; i < items.size(); i++) {
            var it = items[i] as Array;
            var stamp = it[0] as Number;
            out.add([stamp == 0 ? null : stamp - macOffset, it[1], it[2]]);
        }
        var set = { "batch" => batch, "receivedAt" => Time.now().value(), "items" => out };
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
