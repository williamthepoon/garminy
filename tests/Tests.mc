import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Unit tests: scripts/test.sh runs them in the simulator.

// Helpers (not tests). The module annotation keeps them out of release builds.
(:test)
module T {
    function utc(y as Number, m as Number, d as Number, h as Number, min as Number) as Number {
        return Dates.daysFromCivil(y, m, d) * 86400 + h * 3600 + min * 60;
    }

    function near(logger as Test.Logger, label as String, actual as Number, expected as Number, tol as Number) as Boolean {
        var ok = (actual - expected).abs() <= tol;
        if (!ok) {
            logger.error(label + ": got " + actual + " expected " + expected + " +/- " + tol);
        }
        return ok;
    }

    // A drawing context the size of the fenix 7 screen, for measuring text.
    function dc() as Graphics.Dc {
        return (Graphics.createBufferedBitmap({:width => 260, :height => 260}).get() as Graphics.BufferedBitmap).getDc();
    }

    function check(logger as Test.Logger, label as String, ok as Boolean) as Boolean {
        if (!ok) {
            logger.error("failed: " + label);
        }
        return ok;
    }
}

// ---- Layout ----

(:test)
function testLayoutFitsRoundScreens(logger as Test.Logger) as Boolean {
    var sizes = [218, 240, 260, 280, 390, 416, 454];
    var ok = true;
    for (var i = 0; i < sizes.size(); i++) {
        ok = T.check(logger, "box inside circle at " + sizes[i], boxInsideCircle(sizes[i], sizes[i])) && ok;
        var l = new Layout(sizes[i], sizes[i]);
        for (var y = l.boxY; y <= l.boxY + l.boxH; y += 4) {
            ok = T.check(logger, "chord positive at " + y, l.chord(y, Ui.MARGIN) > 0) && ok;
        }
    }
    return ok;
}

// ---- Dates ----

(:test)
function testDates(logger as Test.Logger) as Boolean {
    var ok = T.check(logger, "epoch", Dates.daysFromCivil(1970, 1, 1) == 0);
    ok = T.check(logger, "2000-03-01", Dates.daysFromCivil(2000, 3, 1) == 11017) && ok;
    ok = T.check(logger, "epoch is Thursday", Dates.weekday(0) == 4) && ok;
    ok = T.check(logger, "1969-12-31 is Wednesday", Dates.weekday(-1) == 3) && ok;
    ok = T.check(logger, "2nd Sun Mar 2026 = 8th", Dates.nthSunday(2026, 3, 2) == Dates.daysFromCivil(2026, 3, 8)) && ok;
    ok = T.check(logger, "1st Sun Nov 2026 = 1st", Dates.nthSunday(2026, 11, 1) == Dates.daysFromCivil(2026, 11, 1)) && ok;
    ok = T.check(logger, "last Sun Mar 2026 = 29th", Dates.lastSunday(2026, 3) == Dates.daysFromCivil(2026, 3, 29)) && ok;
    ok = T.check(logger, "last Sun Oct 2026 = 25th", Dates.lastSunday(2026, 10) == Dates.daysFromCivil(2026, 10, 25)) && ok;
    ok = T.check(logger, "last Sun Dec 2026 = 27th", Dates.lastSunday(2026, 12) == Dates.daysFromCivil(2026, 12, 27)) && ok;
    ok = T.check(logger, "floorDiv", Dates.floorDiv(-1, 86400) == -1 && Dates.floorDiv(86399, 86400) == 0) && ok;
    return ok;
}

// ---- Daily selection and content ----

(:test)
function testDailySelection(logger as Test.Logger) as Boolean {
    var n = Daily.FORTUNE_COUNT;
    var start = Dates.daysFromCivil(2026, 10, 17);
    var ok = T.check(logger, "same day stable", Daily.indexFor(start, n) == Daily.indexFor(start, n));
    var seen = {};
    for (var d = start; d < start + n; d++) {
        ok = T.check(logger, "consecutive days differ", Daily.indexFor(d, n) != Daily.indexFor(d + 1, n)) && ok;
        seen.put(Daily.indexFor(d, n), true);
    }
    ok = T.check(logger, "full cycle before repeat", seen.size() == n) && ok;
    ok = T.check(logger, "negative days", Daily.indexFor(-5, n) >= 0) && ok;
    return ok;
}

(:test)
function testFortuneAndQuoteContent(logger as Test.Logger) as Boolean {
    var ok = true;
    var f = Daily.fortuneChunks();
    var q = Daily.quoteChunks();
    var fc = 0;
    var qc = 0;
    for (var i = 0; i < f.size(); i++) {
        var arr = WatchUi.loadResource(f[i]) as Array;
        fc += arr.size();
        for (var j = 0; j < arr.size(); j++) {
            ok = T.check(logger, "fortune length", (arr[j] as String).length() <= 90) && ok;
        }
    }
    for (var i = 0; i < q.size(); i++) {
        var arr = WatchUi.loadResource(q[i]) as Array;
        qc += arr.size();
        for (var j = 0; j < arr.size(); j++) {
            ok = T.check(logger, "quote is text only", arr[j] instanceof String) && ok;
            ok = T.check(logger, "quote length", (arr[j] as String).length() <= 90) && ok;
        }
    }
    ok = T.check(logger, "fortune count", fc == Daily.FORTUNE_COUNT) && ok;
    ok = T.check(logger, "quote count", qc == Daily.QUOTE_COUNT) && ok;
    return ok;
}

(:test)
function testOnThisDayCoversEveryDate(logger as Test.Logger) as Boolean {
    var lengths = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var ok = true;
    for (var m = 1; m <= 12; m++) {
        var arr = WatchUi.loadResource(Daily.monthChunks()[m - 1]) as Array;
        ok = T.check(logger, "days in month " + m, arr.size() == lengths[m - 1]) && ok;
        for (var d = 0; d < arr.size(); d++) {
            var e = arr[d] as Array;
            ok = T.check(logger, "year " + m + "/" + (d + 1), (e[0] as Number) > 0) && ok;
            ok = T.check(logger, "text " + m + "/" + (d + 1), (e[1] as String).length() <= 90) && ok;
        }
    }
    var leap = Daily.onThisDay(2, 29);
    ok = T.check(logger, "29 Feb entry", (leap[1] as String).length() > 0) && ok;
    return ok;
}

// ---- Umbrella ----

(:test)
function testUmbrellaVerdict(logger as Test.Logger) as Boolean {
    var ok = T.check(logger, "60 yes", Umbrella.verdict(60) == Umbrella.YES);
    ok = T.check(logger, "50 yes", Umbrella.verdict(50) == Umbrella.YES) && ok;
    ok = T.check(logger, "49 maybe", Umbrella.verdict(49) == Umbrella.MAYBE) && ok;
    ok = T.check(logger, "35 maybe", Umbrella.verdict(35) == Umbrella.MAYBE) && ok;
    ok = T.check(logger, "30 maybe", Umbrella.verdict(30) == Umbrella.MAYBE) && ok;
    ok = T.check(logger, "29 no", Umbrella.verdict(29) == Umbrella.NO) && ok;
    ok = T.check(logger, "0 no", Umbrella.verdict(0) == Umbrella.NO) && ok;
    return ok;
}

(:test)
function testUmbrellaPeakWindow(logger as Test.Logger) as Boolean {
    var now = T.utc(2026, 10, 17, 9, 30);
    var h = 3600;
    // Current hour (started 09:00), +5h, +11h, +13h (outside), -2h (past).
    var times = [now - 1800, now + 5 * h, now + 11 * h, now + 13 * h, now - 2 * h];
    var chances = [10, 60, 20, 90, 95] as Array<Number?>;
    var p = Umbrella.peak(times, chances, now);
    var ok = T.check(logger, "peak found", p != null);
    if (p != null) {
        ok = T.check(logger, "peak ignores outside window", p[0] == 60) && ok;
        ok = T.check(logger, "peak time", p[1] == now + 5 * h) && ok;
    }
    var none = Umbrella.peak([now + 20 * h], [80] as Array<Number?>, now);
    ok = T.check(logger, "nothing in window", none == null) && ok;
    var nulls = Umbrella.peak([now + h], [null] as Array<Number?>, now);
    ok = T.check(logger, "null chances skipped", nulls == null) && ok;
    return ok;
}

(:test)
function testStaleNote(logger as Test.Logger) as Boolean {
    var now = T.utc(2026, 10, 17, 12, 0);
    var ok = T.check(logger, "fresh", staleNote(now - 3600, now) == null);
    ok = T.check(logger, "exactly 3h fresh", staleNote(now - 3 * 3600, now) == null) && ok;
    var s = staleNote(now - 5 * 3600, now);
    ok = T.check(logger, "5h stale", s != null && (s as String).equals("Updated 5h ago")) && ok;
    ok = T.check(logger, "no observation", staleNote(null, now) == null) && ok;
    return ok;
}

(:test)
function testHighLowText(logger as Test.Logger) as Boolean {
    Application.Properties.setValue("units", Settings.UNITS_C);
    var ok = T.check(logger, "22/13", hiLo(22, 13).equals("22/13"));
    ok = T.check(logger, "negative", hiLo(-3, -12).equals("-3/-12")) && ok;
    ok = T.check(logger, "missing", hiLo(null, null).equals("--/--")) && ok;
    Application.Properties.setValue("units", Settings.UNITS_F);
    ok = T.check(logger, "fahrenheit", hiLo(22, 13).equals("72/55")) && ok;
    Application.Properties.setValue("units", Settings.UNITS_DEVICE);
    return ok;
}

// ---- Sun ----

(:test)
function testSunLondonSummerSolstice(logger as Test.Logger) as Boolean {
    // 04:43 BST / 21:21 BST
    var r = SunCalc.compute(2026, 6, 21, 51.5074d, -0.1278d);
    var ok = T.check(logger, "normal", r[0] == SunCalc.NORMAL);
    ok = T.near(logger, "London rise", r[1], T.utc(2026, 6, 21, 3, 43), 300) && ok;
    ok = T.near(logger, "London set", r[2], T.utc(2026, 6, 21, 20, 21), 300) && ok;
    return ok;
}

(:test)
function testSunSydneyWinterSolstice(logger as Test.Logger) as Boolean {
    // 07:00 AEST / 16:54 AEST (UTC+10)
    var r = SunCalc.compute(2026, 6, 21, -33.8688d, 151.2093d);
    var ok = T.check(logger, "normal", r[0] == SunCalc.NORMAL);
    ok = T.near(logger, "Sydney rise", r[1], T.utc(2026, 6, 20, 21, 0), 300) && ok;
    ok = T.near(logger, "Sydney set", r[2], T.utc(2026, 6, 21, 6, 54), 300) && ok;
    return ok;
}

(:test)
function testSunSanFranciscoNewYear(logger as Test.Logger) as Boolean {
    // 07:25 PST / 17:01 PST (UTC-8)
    var r = SunCalc.compute(2026, 1, 1, 37.7749d, -122.4194d);
    var ok = T.near(logger, "SF rise", r[1], T.utc(2026, 1, 1, 15, 25), 300);
    ok = T.near(logger, "SF set", r[2], T.utc(2026, 1, 2, 1, 1), 300) && ok;
    return ok;
}

(:test)
function testSunPolar(logger as Test.Logger) as Boolean {
    var summer = SunCalc.compute(2026, 6, 21, 69.6492d, 18.9553d);
    var winter = SunCalc.compute(2026, 12, 21, 69.6492d, 18.9553d);
    var ok = T.check(logger, "Tromso midnight sun", summer[0] == SunCalc.SUN_UP_ALL_DAY);
    ok = T.check(logger, "Tromso polar night", winter[0] == SunCalc.NO_SUNRISE) && ok;
    return ok;
}

(:test)
function testDaylightLine(logger as Test.Logger) as Boolean {
    var rise = 1000000;
    var set = rise + 12 * 3600;
    var ok = T.check(logger, "day", daylightLine(set - (3 * 3600 + 12 * 60), rise, set, 0).equals("3h 12m left"));
    ok = T.check(logger, "before sunrise", daylightLine(rise - 300, rise, set, 0).equals("Sunrise in 5m")) && ok;
    ok = T.check(logger, "after sunset",
        daylightLine(set + 60, rise, set, set + 60 + 10 * 3600).equals("Sunrise in 10h 0m")) && ok;
    ok = T.check(logger, "no sunrise tomorrow", daylightLine(set + 60, rise, set, 0).equals("No sunrise tomorrow")) && ok;
    return ok;
}

(:test)
function testLocationFallbackOrder(logger as Test.Logger) as Boolean {
    var a = [1.0d, 2.0d];
    var b = [3.0d, 4.0d];
    var ok = T.check(logger, "first wins", LocationSource.choose([a, b]) == a);
    ok = T.check(logger, "skips null", LocationSource.choose([null, b]) == b) && ok;
    ok = T.check(logger, "all null", LocationSource.choose([null, null]) == null) && ok;
    ok = T.check(logger, "rejects 0,0", LocationSource.valid([0.0d, 0.0d]) == null) && ok;
    return ok;
}

// ---- Moon ----

(:test)
function testMoonFullMoons2026(logger as Test.Logger) as Boolean {
    // Published full-moon instants (UTC).
    var fulls = [T.utc(2026, 1, 3, 10, 3), T.utc(2026, 3, 3, 11, 38), T.utc(2026, 8, 28, 4, 18), T.utc(2026, 10, 26, 4, 12)];
    var ok = true;
    for (var i = 0; i < fulls.size(); i++) {
        var predicted = MoonCalc.nextFullMoon(fulls[i] - 5 * 86400);
        ok = T.near(logger, "next full moon " + i, predicted, fulls[i], 86400) && ok;
        var a = MoonCalc.age(fulls[i]);
        ok = T.check(logger, "full name " + i, MoonCalc.phaseIndex(a) == 4) && ok;
        ok = T.check(logger, "full illumination " + i, MoonCalc.illumination(a) >= 0.98d) && ok;
    }
    return ok;
}

(:test)
function testMoonPhaseNamesFollowIllumination(logger as Test.Logger) as Boolean {
    var p = MoonCalc.SYNODIC;
    var ok = T.check(logger, "36% waxing is crescent", MoonCalc.phaseIndex(p * 0.205d) == 1);
    ok = T.check(logger, "50% waxing is first quarter", MoonCalc.phaseIndex(p * 0.25d) == 2) && ok;
    ok = T.check(logger, "75% waxing is gibbous", MoonCalc.phaseIndex(p * 0.33d) == 3) && ok;
    ok = T.check(logger, "50% waning is last quarter", MoonCalc.phaseIndex(p * 0.75d) == 6) && ok;
    ok = T.check(logger, "new", MoonCalc.phaseIndex(0.1d) == 0) && ok;
    return ok;
}

(:test)
function testMoonWaxingCrescent(logger as Test.Logger) as Boolean {
    // New moon 2026-01-18 19:52 UTC, three days later.
    var a = MoonCalc.age(T.utc(2026, 1, 21, 19, 52));
    var ok = T.check(logger, "waxing crescent", MoonCalc.phaseIndex(a) == 1);
    ok = T.check(logger, "thin", MoonCalc.illumination(a) < 0.25d) && ok;
    return ok;
}

(:test)
function testFullMoonLine(logger as Test.Logger) as Boolean {
    var m = new Time.Moment(T.utc(2026, 10, 24, 12, 0));
    var info = Gregorian.info(m, Time.FORMAT_MEDIUM);
    var expected = "Full " + info.day_of_week + " " + info.day.toString();
    var line = fullMoonLine(m);
    return T.check(logger, "full moon line " + line, line.equals(expected) && line.find(info.month as String) == null);
}

// ---- Time zones ----

(:test)
function testTimeZoneOffsets(logger as Test.Logger) as Boolean {
    var jan = T.utc(2026, 1, 15, 12, 0);
    var jul = T.utc(2026, 7, 1, 12, 0);
    var ok = T.check(logger, "SF July -7", TimeZones.offsetMinutes(TimeZones.SAN_FRANCISCO, jul) == -420);
    ok = T.check(logger, "SF Jan -8", TimeZones.offsetMinutes(TimeZones.SAN_FRANCISCO, jan) == -480) && ok;
    ok = T.check(logger, "Montreal July -4", TimeZones.offsetMinutes(TimeZones.MONTREAL, jul) == -240) && ok;
    ok = T.check(logger, "Montreal Jan -5", TimeZones.offsetMinutes(TimeZones.MONTREAL, jan) == -300) && ok;
    ok = T.check(logger, "Singapore Jan +8", TimeZones.offsetMinutes(TimeZones.SINGAPORE, jan) == 480) && ok;
    ok = T.check(logger, "Singapore Jul +8", TimeZones.offsetMinutes(TimeZones.SINGAPORE, jul) == 480) && ok;
    ok = T.check(logger, "London Jan 0", TimeZones.offsetMinutes(16, jan) == 0) && ok;
    ok = T.check(logger, "London Jul +1", TimeZones.offsetMinutes(16, jul) == 60) && ok;
    ok = T.check(logger, "Sydney Jan +11", TimeZones.offsetMinutes(40, jan) == 660) && ok;
    ok = T.check(logger, "Sydney Jul +10", TimeZones.offsetMinutes(40, jul) == 600) && ok;
    ok = T.check(logger, "Auckland Jan +13", TimeZones.offsetMinutes(42, jan) == 780) && ok;
    ok = T.check(logger, "Phoenix Jul -7", TimeZones.offsetMinutes(5, jul) == -420) && ok;
    return ok;
}

(:test)
function testTimeZoneTransitions(logger as Test.Logger) as Boolean {
    // US 2026: starts 8 Mar 02:00 PST (10:00 UTC), ends 1 Nov 02:00 PDT (09:00 UTC).
    var sf = TimeZones.SAN_FRANCISCO;
    var ok = T.check(logger, "SF before start", TimeZones.offsetMinutes(sf, T.utc(2026, 3, 8, 9, 59)) == -480);
    ok = T.check(logger, "SF at start", TimeZones.offsetMinutes(sf, T.utc(2026, 3, 8, 10, 0)) == -420) && ok;
    ok = T.check(logger, "SF before end", TimeZones.offsetMinutes(sf, T.utc(2026, 11, 1, 8, 59)) == -420) && ok;
    ok = T.check(logger, "SF at end", TimeZones.offsetMinutes(sf, T.utc(2026, 11, 1, 9, 0)) == -480) && ok;
    // Montreal: starts 8 Mar 07:00 UTC.
    ok = T.check(logger, "Montreal at start", TimeZones.offsetMinutes(TimeZones.MONTREAL, T.utc(2026, 3, 8, 7, 0)) == -240) && ok;
    // EU 2026: 29 Mar 01:00 UTC to 25 Oct 01:00 UTC.
    ok = T.check(logger, "London before", TimeZones.offsetMinutes(16, T.utc(2026, 3, 29, 0, 59)) == 0) && ok;
    ok = T.check(logger, "London after", TimeZones.offsetMinutes(16, T.utc(2026, 3, 29, 1, 0)) == 60) && ok;
    ok = T.check(logger, "London Oct end", TimeZones.offsetMinutes(16, T.utc(2026, 10, 25, 1, 0)) == 0) && ok;
    // Sydney: ends 5 Apr 2026 03:00 AEDT (4 Apr 16:00 UTC).
    ok = T.check(logger, "Sydney before end", TimeZones.offsetMinutes(40, T.utc(2026, 4, 4, 15, 59)) == 660) && ok;
    ok = T.check(logger, "Sydney after end", TimeZones.offsetMinutes(40, T.utc(2026, 4, 4, 16, 0)) == 600) && ok;
    return ok;
}

(:test)
function testCityTimeAndDayOffset(logger as Test.Logger) as Boolean {
    // 2026-07-01 15:30 UTC: SF 08:30, Singapore 23:30, Montreal 11:30.
    var t = T.utc(2026, 7, 1, 15, 30);
    var sf = TimeZones.cityTime(TimeZones.SAN_FRANCISCO, t);
    var sg = TimeZones.cityTime(TimeZones.SINGAPORE, t);
    var ok = T.check(logger, "SF 08:30", sf[0] == 8 && sf[1] == 30);
    ok = T.check(logger, "Singapore 23:30", sg[0] == 23 && sg[1] == 30) && ok;
    // 17:00 UTC: Singapore is already on the next day.
    var later = TimeZones.cityTime(TimeZones.SINGAPORE, T.utc(2026, 7, 1, 17, 0));
    ok = T.check(logger, "Singapore next day", later[2] == Dates.daysFromCivil(2026, 7, 2)) && ok;
    ok = T.check(logger, "Singapore 01:00", later[0] == 1) && ok;
    return ok;
}

(:test)
function testCityCodes(logger as Test.Logger) as Boolean {
    var codes = TimeZones.CODES;
    var ok = T.check(logger, "one code per city", codes.size() == TimeZones.NAMES.size());
    var seen = {} as Dictionary<String, Boolean>;
    for (var i = 0; i < codes.size(); i++) {
        var c = codes[i];
        var upper = c.length() == 3;
        var chars = c.toCharArray();
        for (var j = 0; j < chars.size(); j++) {
            upper = upper && chars[j] >= 'A' && chars[j] <= 'Z';
        }
        ok = T.check(logger, "three capitals: " + c, upper) && ok;
        ok = T.check(logger, "unique: " + c, !seen.hasKey(c)) && ok;
        seen[c] = true;
    }
    ok = T.check(logger, "defaults", codes[TimeZones.SAN_FRANCISCO].equals("SFO")
        && codes[TimeZones.SINGAPORE].equals("SIN") && codes[TimeZones.MONTREAL].equals("MTL")) && ok;
    return ok;
}

(:test)
function testWorldClockTimeFont(logger as Test.Logger) as Boolean {
    var dc = T.dc();
    var l = new Layout(260, 260);
    var codes = ["SFO", "JNB", "SIN"];
    var times = [["12:45", "pm"], ["9:45", "pm"], ["3:45", "am"]] as Array<Array<String>>;
    var diffs = [0, 0, 1];
    var narrowest = Ui.lineWidth(l, l.boxY + l.boxH * 2 / 3, l.boxH / 3) - 2 * (l.boxH / 3 / 8) - CLOCK_GAP;
    var ok = T.check(logger, "large numerals fit with codes",
        timeFont(dc, codes, times, diffs, narrowest) == Graphics.FONT_NUMBER_MILD);
    ok = T.check(logger, "falls back when narrow",
        timeFont(dc, codes, times, diffs, 120) != Graphics.FONT_NUMBER_MILD) && ok;
    return ok;
}

// ---- Text fit (fenix7 260x260 content box, same maths as TextCard.draw) ----

(:test)
function testAllBundledTextFitsTheScreen(logger as Test.Logger) as Boolean {
    var l = new Layout(260, 260);
    var dc = T.dc();
    var bottom = l.boxY + l.boxH;
    var yearTop = l.boxY + l.h / 5;
    var ok = true;
    var chunks = [Daily.fortuneChunks(), Daily.quoteChunks()];
    for (var c = 0; c < chunks.size(); c++) {
        for (var i = 0; i < chunks[c].size(); i++) {
            var arr = WatchUi.loadResource(chunks[c][i]) as Array;
            for (var j = 0; j < arr.size(); j++) {
                ok = T.check(logger, "fits at TINY or larger: " + arr[j],
                    Ui.fit(dc, l, arr[j] as String, l.boxY, bottom, Graphics.FONT_TINY) != null) && ok;
            }
        }
    }
    for (var m = 0; m < 12; m++) {
        var arr = WatchUi.loadResource(Daily.monthChunks()[m]) as Array;
        for (var d = 0; d < arr.size(); d++) {
            var e = arr[d] as Array;
            ok = T.check(logger, "on this day fits: " + e[1],
                Ui.fit(dc, l, e[1] as String, yearTop, bottom, Graphics.FONT_TINY) != null) && ok;
        }
    }
    return ok;
}

// ---- Text fitting ----

(:test)
function testFontLadder(logger as Test.Logger) as Boolean {
    var dc = T.dc();
    var fs = Ui.fonts(56, Graphics.FONT_TINY);
    var ok = T.check(logger, "ladder ends at TINY", fs[fs.size() - 1] == Graphics.FONT_TINY);
    for (var i = 0; i < fs.size(); i++) {
        ok = T.check(logger, "no XTINY", fs[i] != Graphics.FONT_XTINY) && ok;
        if (i > 0) {
            ok = T.check(logger, "descending at " + i, dc.getFontHeight(fs[i]) < dc.getFontHeight(fs[i - 1])) && ok;
        }
    }
    var small = Ui.fonts(56, Graphics.FONT_SMALL);
    ok = T.check(logger, "SMALL floor", small[small.size() - 1] == Graphics.FONT_SMALL) && ok;
    ok = T.check(logger, "vector sizes on fenix7", fs.size() > 4) && ok;
    return ok;
}

(:test)
function testFitToRoundScreen(logger as Test.Logger) as Boolean {
    var l = new Layout(260, 260);
    var dc = T.dc();
    var top = l.boxY;
    var bottom = l.boxY + l.boxH;
    var r = Ui.fit(dc, l, "Mac offline", top, bottom, Graphics.FONT_SMALL);
    var ok = T.check(logger, "short text fits", r != null);
    if (r != null) {
        ok = T.check(logger, "short text bigger than SMALL",
            dc.getFontHeight(r[0] as Graphics.FontType) > dc.getFontHeight(Graphics.FONT_SMALL)) && ok;
        ok = T.check(logger, "cache hit returns same lines", Ui.fit(dc, l, "Mac offline", top, bottom, Graphics.FONT_SMALL) == r) && ok;
    }
    ok = T.check(logger, "unbreakable word does not fit",
        Ui.fit(dc, l, "Pneumonoultramicroscopicsilicovolcanoconiosis", top, bottom, Graphics.FONT_TINY) == null) && ok;
    var text = "It is not that we have a short time to live, but that we waste a lot of it.";
    var f = Ui.fit(dc, l, text, top, bottom, Graphics.FONT_TINY);
    ok = T.check(logger, "long text fits", f != null) && ok;
    if (f != null) {
        var font = f[0] as Graphics.FontType;
        var lines = f[1] as Array<String>;
        var lh = dc.getFontHeight(font);
        var y = (top + bottom) / 2 - lines.size() * lh / 2;
        for (var i = 0; i < lines.size(); i++) {
            ok = T.check(logger, "line " + i + " inside circle",
                dc.getTextWidthInPixels(lines[i], font) <= Ui.lineWidth(l, y + i * lh, lh)) && ok;
        }
    }
    return ok;
}

(:test)
function testTwelveHourSplit(logger as Test.Logger) as Boolean {
    var a = Ui.splitAmPm("2:05pm");
    var b = Ui.splitAmPm("14:05");
    return T.check(logger, "12h", a[0].equals("2:05") && a[1].equals("pm"))
        && T.check(logger, "24h", b[0].equals("14:05") && b[1].equals(""));
}

// ---- Carousel + settings (drives Application.Properties directly) ----

(:test)
module TS {
    // A carousel with the companion link switched off, so tests never touch Bluetooth.
    function view() as CarouselView {
        Application.Properties.setValue("companion", false);
        var c = new Companion();
        return new CarouselView(c, new Link(c));
    }

    function setAll(on as Boolean) as Void {
        for (var i = 0; i < Settings.CARD_KEYS.size(); i++) {
            Application.Properties.setValue(Settings.CARD_KEYS[i], on);
        }
    }

    function ids(v as CarouselView) as String {
        var s = "";
        for (var i = 0; i < v._cards.size(); i++) {
            s += (i > 0 ? "," : "") + v._cards[i].id();
        }
        return s;
    }

    function reset() as Void {
        setAll(true);
        Application.Properties.setValue("interval", 10);
        Application.Properties.setValue("city1", TimeZones.SAN_FRANCISCO);
        Application.Properties.setValue("city2", TimeZones.SINGAPORE);
        Application.Properties.setValue("city3", TimeZones.MONTREAL);
        Application.Properties.setValue("units", Settings.UNITS_DEVICE);
        Application.Properties.setValue("backlight", 0);
    }
}

(:test)
function testCarouselDefaultOrderAndInterval(logger as Test.Logger) as Boolean {
    TS.reset();
    var v = TS.view();
    var ok = T.check(logger, "fixed order: " + TS.ids(v),
        TS.ids(v).equals("fortune,quote,umbrella,weather,daylight,moon,world,onthisday"));
    ok = T.check(logger, "default interval 10", v._interval == 10) && ok;
    ok = T.check(logger, "starts on first card", v._idx == 0) && ok;
    return ok;
}

(:test)
function testCarouselRotationNavigationAndPin(logger as Test.Logger) as Boolean {
    TS.reset();
    var v = TS.view();
    for (var i = 0; i < 10; i++) {
        v.onTick();
    }
    var ok = T.check(logger, "advances after interval", v._idx == 1);
    v.prev();
    v.prev();
    ok = T.check(logger, "prev wraps to last", v._idx == 7) && ok;
    v.next();
    ok = T.check(logger, "next wraps to first", v._idx == 0 && v._elapsed == 0) && ok;
    v.togglePin();
    for (var i = 0; i < 30; i++) {
        v.onTick();
    }
    ok = T.check(logger, "pinned card stays", v._idx == 0 && v._pinned) && ok;
    v.next();
    ok = T.check(logger, "navigation clears pin", !v._pinned && v._idx == 1) && ok;
    v.togglePin();
    v.togglePin();
    ok = T.check(logger, "tap again unpins", !v._pinned) && ok;
    return ok;
}

(:test)
function testSettingsLiveReload(logger as Test.Logger) as Boolean {
    TS.reset();
    var v = TS.view();
    v.show(6);  // world clock
    Application.Properties.setValue("cardMoon", false);
    Application.Properties.setValue("interval", 30);
    v.reload();
    var ok = T.check(logger, "moon skipped: " + TS.ids(v),
        TS.ids(v).equals("fortune,quote,umbrella,weather,daylight,world,onthisday"));
    ok = T.check(logger, "keeps current card", v._cards[v._idx].id().equals("world")) && ok;
    ok = T.check(logger, "interval applied", v._interval == 30) && ok;
    Application.Properties.setValue("interval", 7);
    v.reload();
    ok = T.check(logger, "invalid interval falls back to 10", v._interval == 10) && ok;
    TS.reset();
    return ok;
}

(:test)
function testAllCardsDisabledIsEmpty(logger as Test.Logger) as Boolean {
    TS.reset();
    TS.setAll(false);
    var v = TS.view();
    var ok = T.check(logger, "no cards", v._cards.size() == 0);
    v.onTick();
    v.next();
    v.togglePin();
    ok = T.check(logger, "inputs safe when empty", !v._pinned) && ok;
    TS.reset();
    return ok;
}

(:test)
function testCitiesAndUnitsSettings(logger as Test.Logger) as Boolean {
    TS.reset();
    var c = Settings.cities();
    var ok = T.check(logger, "default cities", c.size() == 3 && c[0] == TimeZones.SAN_FRANCISCO
        && c[1] == TimeZones.SINGAPORE && c[2] == TimeZones.MONTREAL);
    Application.Properties.setValue("city3", -1);
    ok = T.check(logger, "None removes a city", Settings.cities().size() == 2) && ok;
    Application.Properties.setValue("units", Settings.UNITS_F);
    ok = T.check(logger, "fahrenheit: " + Settings.formatTemp(20), Settings.formatTemp(20).equals("68°")) && ok;
    Application.Properties.setValue("units", Settings.UNITS_C);
    ok = T.check(logger, "celsius", Settings.formatTemp(20).equals("20°")) && ok;
    ok = T.check(logger, "missing temp", Settings.formatTemp(null).equals("--")) && ok;
    TS.reset();
    return ok;
}

(:test)
function testDailyCardsChangeWithTheDate(logger as Test.Logger) as Boolean {
    var ok = true;
    var cards = [new FortuneCard(), new QuoteCard(), new OnThisDayCard()] as Array<TextCard>;
    for (var i = 0; i < cards.size(); i++) {
        var c = cards[i];
        c.refresh();
        var today = c._text;
        c.refresh();
        ok = T.check(logger, c.id() + " stable within the day", c._text.equals(today)) && ok;
        // Pretend the card was last loaded yesterday: refresh must reload.
        c._day -= 1;
        c._text = "";
        c.refresh();
        ok = T.check(logger, c.id() + " reloads on date change", c._text.equals(today)) && ok;
    }
    var f = new FortuneCard();
    var d = Dates.localTodayDays();
    f.load(d);
    var a = f._text;
    f.load(d + 1);
    ok = T.check(logger, "fortune differs tomorrow", !f._text.equals(a)) && ok;
    var q = new QuoteCard();
    q.load(d);
    var qa = q._text;
    q.load(d + 1);
    ok = T.check(logger, "quote differs tomorrow", !q._text.equals(qa)) && ok;
    return ok;
}

(:test)
function testBacklightSetting(logger as Test.Logger) as Boolean {
    TS.reset();
    var ok = T.check(logger, "default off", Settings.backlightLevel() == 0.0);
    var expected = [0.0, 0.3, 0.6, 1.0];
    for (var i = 0; i < 4; i++) {
        Application.Properties.setValue("backlight", i);
        ok = T.check(logger, "level " + i, Settings.backlightLevel() == expected[i]) && ok;
    }
    Application.Properties.setValue("backlight", 9);
    ok = T.check(logger, "out of range is off", Settings.backlightLevel() == 0.0) && ok;
    Application.Properties.setValue("backlight", 2);
    var v = TS.view();
    ok = T.check(logger, "view holds medium", v._backlight == 0.6) && ok;
    v.onTick();
    Application.Properties.setValue("backlight", 0);
    v.reload();
    ok = T.check(logger, "switching off releases it", v._backlight == 0.0) && ok;
    TS.reset();
    return ok;
}
