import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Weather;

// Weather condition icons drawn from primitives (no bitmaps, low memory).
module WeatherIcons {
    const CLEAR = 0;
    const PARTLY = 1;
    const CLOUDY = 2;
    const RAIN = 3;
    const SNOW = 4;
    const STORM = 5;
    const FOG = 6;
    const WIND = 7;

    // Maps a Garmin condition code to one of the 8 icon groups.
    function group(c as Number?) as Number {
        if (c == null) {
            return CLOUDY;
        }
        switch (c) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_FAIR:
            case Weather.CONDITION_MOSTLY_CLEAR:
                return CLEAR;
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_PARTLY_CLEAR:
            case Weather.CONDITION_THIN_CLOUDS:
                return PARTLY;
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_HEAVY_RAIN:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
            case Weather.CONDITION_LIGHT_SHOWERS:
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_HEAVY_SHOWERS:
            case Weather.CONDITION_CHANCE_OF_SHOWERS:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN:
            case Weather.CONDITION_DRIZZLE:
            case Weather.CONDITION_FREEZING_RAIN:
                return RAIN;
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_HEAVY_SNOW:
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
            case Weather.CONDITION_RAIN_SNOW:
            case Weather.CONDITION_CHANCE_OF_SNOW:
            case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_FLURRIES:
            case Weather.CONDITION_SLEET:
            case Weather.CONDITION_ICE_SNOW:
            case Weather.CONDITION_ICE:
            case Weather.CONDITION_HAIL:
                return SNOW;
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
            case Weather.CONDITION_TORNADO:
            case Weather.CONDITION_HURRICANE:
            case Weather.CONDITION_TROPICAL_STORM:
            case Weather.CONDITION_SQUALL:
                return STORM;
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_HAZY:
            case Weather.CONDITION_MIST:
            case Weather.CONDITION_HAZE:
            case Weather.CONDITION_SMOKE:
            case Weather.CONDITION_DUST:
            case Weather.CONDITION_SAND:
            case Weather.CONDITION_SANDSTORM:
            case Weather.CONDITION_VOLCANIC_ASH:
                return FOG;
            case Weather.CONDITION_WINDY:
                return WIND;
        }
        return CLOUDY;
    }

    // Draws the icon centred on (x, y); s is roughly the icon radius.
    function draw(dc as Graphics.Dc, x as Number, y as Number, s as Number, g as Number) as Void {
        if (g == CLEAR) {
            drawSun(dc, x, y, s);
        } else if (g == PARTLY) {
            drawSun(dc, x - s / 3, y - s / 3, s * 2 / 3);
            drawCloud(dc, x + s / 6, y + s / 6, s * 3 / 4);
        } else if (g == FOG) {
            dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            for (var i = -1; i <= 1; i++) {
                dc.drawLine(x - s, y + i * s / 2, x + s, y + i * s / 2);
            }
            dc.setPenWidth(1);
        } else if (g == WIND) {
            dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(x - s, y - s / 3, x + s / 2, y - s / 3);
            dc.drawLine(x - s, y + s / 3, x + s, y + s / 3);
            dc.drawArc(x + s / 2, y - s * 2 / 3, s / 3, Graphics.ARC_CLOCKWISE, 270, 90);
            dc.setPenWidth(1);
        } else {
            drawCloud(dc, x, y - s / 4, s);
            var by = y + s / 2;
            if (g == RAIN) {
                dc.setColor(Ui.BLUE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                for (var i = -1; i <= 1; i++) {
                    dc.drawLine(x + i * s / 2, by, x + i * s / 2 - s / 5, by + s / 2);
                }
                dc.setPenWidth(1);
            } else if (g == SNOW) {
                dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
                for (var i = -1; i <= 1; i++) {
                    dc.fillCircle(x + i * s / 2, by + s / 4, 2);
                }
            } else if (g == STORM) {
                dc.setColor(Ui.YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[x, by - 2], [x - s / 4, by + s / 3], [x, by + s / 3],
                                [x - s / 6, by + s * 3 / 4], [x + s / 3, by + s / 4], [x + s / 12, by + s / 4],
                                [x + s / 4, by - 2]]);
            }
        }
    }

    function drawSun(dc as Graphics.Dc, x as Number, y as Number, s as Number) as Void {
        dc.setColor(Ui.YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, s / 2);
        dc.setPenWidth(2);
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4;
            var c = Math.cos(a);
            var n = Math.sin(a);
            dc.drawLine(x + (c * s * 0.7).toNumber(), y + (n * s * 0.7).toNumber(),
                        x + (c * s).toNumber(), y + (n * s).toNumber());
        }
        dc.setPenWidth(1);
    }

    function drawCloud(dc as Graphics.Dc, x as Number, y as Number, s as Number) as Void {
        dc.setColor(Ui.DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s / 2, y + s / 6, s / 3);
        dc.fillCircle(x, y - s / 8, s / 2);
        dc.fillCircle(x + s / 2, y + s / 6, s / 3);
        dc.fillRectangle(x - s / 2, y + s / 6, s, s / 3);
    }
}
