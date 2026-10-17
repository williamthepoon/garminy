import Toybox.Lang;
import Toybox.Time;
import Toybox.Weather;

// Chooses between the watch's Garmin weather and the last forecast from the Mac:
// Garmin while it is under 3 hours old, otherwise whichever is newer.
(:glance)
module WeatherSource {
    const FRESH_SECS = 3 * 3600;

    function preferMac(garminObs as Number?, macObs as Number?, now as Number) as Boolean {
        if (macObs == null) {
            return false;
        }
        if (garminObs == null) {
            return true;
        }
        if (now - garminObs < FRESH_SECS) {
            return false;
        }
        return macObs > garminObs;
    }

    function garminObserved() as Number? {
        var cc = Weather.getCurrentConditions();
        if (cc != null && cc.observationTime != null) {
            return (cc.observationTime as Time.Moment).value();
        }
        return null;
    }

    // The Mac forecast when it should be used, else null (use Garmin weather).
    function mac() as Dictionary? {
        var w = MacWeather.get();
        if (w == null) {
            return null;
        }
        return preferMac(garminObserved(), w["observed"] as Number, Time.now().value()) ? w : null;
    }

    // Observation time of the source in use.
    function observed() as Number? {
        var w = mac();
        return w != null ? w["observed"] as Number : garminObserved();
    }
}
