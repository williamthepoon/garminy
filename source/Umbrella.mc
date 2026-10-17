import Toybox.Lang;
import Toybox.Time;
import Toybox.Weather;

// Umbrella verdict from the highest hourly rain chance in the next 12 hours.
(:glance)
module Umbrella {
    const NO = 0;
    const MAYBE = 1;
    const YES = 2;
    const LABELS = ["NO", "MAYBE", "YES"];
    const WINDOW_SECS = 12 * 3600;

    function verdict(chance as Number) as Number {
        if (chance >= 50) {
            return YES;
        } else if (chance >= 30) {
            return MAYBE;
        }
        return NO;
    }

    // Highest chance among forecasts whose hour overlaps [now, now + 12h).
    // Returns [chance, forecastTime] or null when no forecast is in the window.
    function peak(times as Array<Number>, chances as Array<Number?>, now as Number) as Array<Number>? {
        var best = null as Array<Number>?;
        for (var i = 0; i < times.size(); i++) {
            var t = times[i];
            var c = chances[i];
            if (c == null || t + 3600 <= now || t >= now + WINDOW_SECS) {
                continue;
            }
            if (best == null || c > best[0]) {
                best = [c, t];
            }
        }
        return best;
    }

    // [verdict, chance, peakTime or -1], or null when there is no weather data.
    function read() as Array<Number>? {
        var now = Time.now().value();
        var hourly = Weather.getHourlyForecast();
        if (hourly != null) {
            var times = [] as Array<Number>;
            var chances = [] as Array<Number?>;
            for (var i = 0; i < hourly.size(); i++) {
                var f = hourly[i];
                if (f.forecastTime != null) {
                    times.add((f.forecastTime as Time.Moment).value());
                    chances.add(f.precipitationChance);
                }
            }
            var p = peak(times, chances, now);
            if (p != null) {
                return [verdict(p[0]), p[0], p[1]];
            }
        }
        var cc = Weather.getCurrentConditions();
        if (cc != null && cc.precipitationChance != null) {
            var c = cc.precipitationChance as Number;
            return [verdict(c), c, -1];
        }
        return null;
    }
}
