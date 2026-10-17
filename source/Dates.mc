import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Calendar arithmetic on plain integers (testable, no time-zone surprises).
(:glance)
module Dates {
    // Days since 1970-01-01 for a proleptic Gregorian date (H. Hinnant's algorithm).
    function daysFromCivil(y as Number, m as Number, d as Number) as Number {
        if (m <= 2) {
            y -= 1;
        }
        var era = (y >= 0 ? y : y - 399) / 400;
        var yoe = y - era * 400;
        var mp = (m + 9) % 12;
        var doy = (153 * mp + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // 0 = Sunday ... 6 = Saturday.
    function weekday(days as Number) as Number {
        return ((days % 7) + 11) % 7;
    }

    // Day number of the n-th (1-based) Sunday of a month.
    function nthSunday(y as Number, m as Number, n as Number) as Number {
        var first = daysFromCivil(y, m, 1);
        return first + (7 - weekday(first)) % 7 + (n - 1) * 7;
    }

    function lastSunday(y as Number, m as Number) as Number {
        var nextFirst = m == 12 ? daysFromCivil(y + 1, 1, 1) : daysFromCivil(y, m + 1, 1);
        var last = nextFirst - 1;
        return last - weekday(last);
    }

    // Floor division that behaves for negative values.
    function floorDiv(a as Number, b as Number) as Number {
        var q = a / b;
        if ((a % b != 0) && ((a < 0) != (b < 0))) {
            q -= 1;
        }
        return q;
    }

    // Today's local calendar date as [year, month, day].
    function localToday() as Array<Number> {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return [info.year as Number, info.month as Number, info.day as Number];
    }

    function localTodayDays() as Number {
        var t = localToday();
        return daysFromCivil(t[0], t[1], t[2]);
    }
}
