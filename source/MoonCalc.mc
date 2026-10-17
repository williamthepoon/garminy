import Toybox.Lang;
import Toybox.Math;

// Mean-moon phase model: age within the synodic month since a reference
// new moon. Full-moon dates come out within about half a day.
module MoonCalc {
    const SYNODIC = 29.530588853d;
    const REF_NEW_MOON = 947182440;   // 2000-01-06 18:14 UTC
    const NAMES = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
                   "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"];

    // Age in days, 0 <= age < SYNODIC.
    function age(unix as Number) as Double {
        var days = (unix - REF_NEW_MOON).toDouble() / 86400.0d;
        var a = days - SYNODIC * Math.floor(days / SYNODIC);
        return a;
    }

    // Lit fraction 0..1.
    function illumination(a as Double) as Double {
        return (1.0d - Math.cos(2.0d * Math.PI * a / SYNODIC)) / 2.0d;
    }

    // Index into NAMES from illumination and direction, so "Quarter" only
    // shows when the disc is really about half lit.
    function phaseIndex(a as Double) as Number {
        var lit = illumination(a);
        var waxing = a < SYNODIC / 2.0d;
        if (lit < 0.03d) {
            return 0;
        } else if (lit > 0.97d) {
            return 4;
        } else if (lit < 0.45d) {
            return waxing ? 1 : 7;
        } else if (lit <= 0.55d) {
            return waxing ? 2 : 6;
        }
        return waxing ? 3 : 5;
    }

    function nextFullMoon(unix as Number) as Number {
        var a = age(unix);
        var half = SYNODIC / 2.0d;
        var wait = a < half ? half - a : SYNODIC + half - a;
        return unix + (wait * 86400.0d).toNumber();
    }
}
