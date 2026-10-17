import Toybox.Application;
import Toybox.Lang;

// Last forecast and location from the Mac, saved so they survive restarts and
// reach the glance. Times are stored in watch-clock seconds.
(:glance)
module MacWeather {
    function save(d as Dictionary, macOffset as Number) as Void {
        Application.Storage.setValue("macWx", {
            "observed" => (d[:observed] as Number) - macOffset,
            "temp" => d[:temp],
            "cond" => d[:cond],
            "today" => d[:today],
            "tomorrow" => d[:tomorrow],
            "base" => (d[:base] as Number) - macOffset,
            "chances" => d[:chances]
        });
    }

    function saveLocation(lat as Float, lon as Float) as Void {
        Application.Storage.setValue("macLoc", [lat, lon]);
    }

    function get() as Dictionary? {
        var w = Application.Storage.getValue("macWx");
        return w instanceof Dictionary ? w : null;
    }

    // [lat, lon] in degrees, or null.
    function location() as Array? {
        var l = Application.Storage.getValue("macLoc");
        return l instanceof Array && l.size() == 2 ? l : null;
    }
}
