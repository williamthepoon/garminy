import Toybox.Lang;

// Curated city list with standard UTC offsets and daylight-saving rules.
// The index of each city is what the settings store, so only append to these lists.
module TimeZones {
    const NONE = 0;
    const US = 1;    // 2nd Sun Mar 02:00 local -> 1st Sun Nov 02:00 local (US & Canada)
    const EU = 2;    // last Sun Mar 01:00 UTC -> last Sun Oct 01:00 UTC
    const AU = 3;    // 1st Sun Oct 02:00 std -> 1st Sun Apr 03:00 daylight
    const NZ = 4;    // last Sun Sep 02:00 std -> 1st Sun Apr 03:00 daylight

    const NAMES = [
        "San Francisco", "Los Angeles", "Seattle", "Vancouver", "Denver", "Phoenix",
        "Chicago", "Mexico City", "Toronto", "Montreal", "New York", "Boston",
        "Halifax", "Sao Paulo", "Buenos Aires", "Reykjavik", "London", "Dublin",
        "Lisbon", "Paris", "Berlin", "Madrid", "Amsterdam", "Stockholm",
        "Rome", "Athens", "Helsinki", "Johannesburg", "Istanbul", "Moscow",
        "Dubai", "Mumbai", "Bangkok", "Singapore", "Hong Kong", "Shanghai",
        "Perth", "Tokyo", "Seoul", "Brisbane", "Sydney", "Melbourne",
        "Auckland", "Honolulu", "Anchorage"
    ];
    // Three-letter code shown on the card, parallel to NAMES (settings keep the full names).
    const CODES = [
        "SFO", "LAX", "SEA", "YVR", "DEN", "PHX",
        "CHI", "MEX", "TOR", "MTL", "NYC", "BOS",
        "YHZ", "SAO", "BUE", "REK", "LON", "DUB",
        "LIS", "PAR", "BER", "MAD", "AMS", "STO",
        "ROM", "ATH", "HEL", "JNB", "IST", "MOW",
        "DXB", "BOM", "BKK", "SIN", "HKG", "SHA",
        "PER", "TYO", "SEL", "BNE", "SYD", "MEL",
        "AKL", "HNL", "ANC"
    ];
    // Standard (winter) offset from UTC in minutes.
    const STD = [
        -480, -480, -480, -480, -420, -420,
        -360, -360, -300, -300, -300, -300,
        -240, -180, -180, 0, 0, 0,
        0, 60, 60, 60, 60, 60,
        60, 120, 120, 120, 180, 180,
        240, 330, 420, 480, 480, 480,
        480, 540, 540, 600, 600, 600,
        720, -600, -540
    ];
    const RULE = [
        US, US, US, US, US, NONE,
        US, NONE, US, US, US, US,
        US, NONE, NONE, NONE, EU, EU,
        EU, EU, EU, EU, EU, EU,
        EU, EU, EU, NONE, NONE, NONE,
        NONE, NONE, NONE, NONE, NONE, NONE,
        NONE, NONE, NONE, NONE, AU, AU,
        NZ, NONE, US
    ];

    const SAN_FRANCISCO = 0;
    const MONTREAL = 9;
    const SINGAPORE = 33;

    const DAY = 86400;
    const HOUR = 3600;

    // Current UTC offset in minutes for a city at the given UTC instant.
    function offsetMinutes(city as Number, utc as Number) as Number {
        var std = STD[city];
        return isDst(RULE[city], std, utc) ? std + 60 : std;
    }

    function isDst(rule as Number, std as Number, utc as Number) as Boolean {
        if (rule == NONE) {
            return false;
        }
        var y = yearOf(utc);
        var stdSecs = std * 60;
        var start;
        var end;
        if (rule == US) {
            start = Dates.nthSunday(y, 3, 2) * DAY + 2 * HOUR - stdSecs;
            end = Dates.nthSunday(y, 11, 1) * DAY + 2 * HOUR - (stdSecs + HOUR);
            return utc >= start && utc < end;
        } else if (rule == EU) {
            start = Dates.lastSunday(y, 3) * DAY + HOUR;
            end = Dates.lastSunday(y, 10) * DAY + HOUR;
            return utc >= start && utc < end;
        }
        // Southern hemisphere: daylight time spans the new year.
        end = Dates.nthSunday(y, 4, 1) * DAY + 3 * HOUR - (stdSecs + HOUR);
        start = rule == AU
            ? Dates.nthSunday(y, 10, 1) * DAY + 2 * HOUR - stdSecs
            : Dates.lastSunday(y, 9) * DAY + 2 * HOUR - stdSecs;
        return utc < end || utc >= start;
    }

    // UTC calendar year of a Unix time.
    function yearOf(utc as Number) as Number {
        var days = Dates.floorDiv(utc, DAY);
        // Estimate, then correct by checking 1 Jan boundaries.
        var y = 1970 + days / 365;
        while (Dates.daysFromCivil(y, 1, 1) > days) {
            y -= 1;
        }
        while (Dates.daysFromCivil(y + 1, 1, 1) <= days) {
            y += 1;
        }
        return y;
    }

    // City wall-clock as [hour, minute, dayNumber since 1970].
    function cityTime(city as Number, utc as Number) as Array<Number> {
        var t = utc + offsetMinutes(city, utc) * 60;
        var days = Dates.floorDiv(t, DAY);
        var secs = t - days * DAY;
        return [secs / HOUR, (secs % HOUR) / 60, days];
    }
}
