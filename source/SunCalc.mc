import Toybox.Lang;
import Toybox.Math;

// Sunrise/sunset from the sunrise equation (NOAA-style approximations).
// Accurate to about a minute at most latitudes.
module SunCalc {
    const NORMAL = 0;
    const SUN_UP_ALL_DAY = 1;
    const NO_SUNRISE = 2;

    const RAD = Math.PI / 180.0d;
    const J2000 = 2451545.0d;
    const UNIX_EPOCH_JD = 2440587.5d;

    // Returns [status, sunriseUnix, sunsetUnix] for the given calendar day.
    // Times are 0 when status is not NORMAL. Longitude is east-positive.
    function compute(y as Number, m as Number, d as Number, lat as Double, lon as Double) as Array<Number> {
        var days = Dates.daysFromCivil(y, m, d);
        var n = (days + UNIX_EPOCH_JD + 0.5d - J2000 + 0.0008d).toNumber().toDouble();
        var jStar = n - lon / 360.0d;
        var mDeg = fmod(357.5291d + 0.98560028d * jStar, 360.0d);
        var mRad = mDeg * RAD;
        var c = 1.9148d * Math.sin(mRad) + 0.02d * Math.sin(2.0d * mRad) + 0.0003d * Math.sin(3.0d * mRad);
        var lambda = fmod(mDeg + c + 180.0d + 102.9372d, 360.0d) * RAD;
        var jTransit = J2000 + jStar + 0.0053d * Math.sin(mRad) - 0.0069d * Math.sin(2.0d * lambda);
        var sinDec = Math.sin(lambda) * Math.sin(23.4397d * RAD);
        var cosDec = Math.sqrt(1.0d - sinDec * sinDec);
        var phi = lat * RAD;
        var cosW = (Math.sin(-0.833d * RAD) - Math.sin(phi) * sinDec) / (Math.cos(phi) * cosDec);
        if (cosW < -1.0d) {
            return [SUN_UP_ALL_DAY, 0, 0];
        } else if (cosW > 1.0d) {
            return [NO_SUNRISE, 0, 0];
        }
        var w = Math.acos(cosW) / RAD;
        var rise = jTransit - w / 360.0d;
        var set = jTransit + w / 360.0d;
        return [NORMAL, toUnix(rise), toUnix(set)];
    }

    function toUnix(jd as Double) as Number {
        return Math.round((jd - UNIX_EPOCH_JD) * 86400.0d).toNumber();
    }

    function fmod(a as Double, b as Double) as Double {
        var r = a - b * Math.floor(a / b);
        return r;
    }
}
