import Toybox.Application;
import Toybox.Attention;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// What the watch knows from the Mac companion. The Mac owns the alert queue;
// every ALERTS message replaces it. Taps made while offline are kept and sent
// after the next HELLO.
class Companion {
    var connected as Boolean = false;
    var everConnected as Boolean = false;
    var versionMismatch as Boolean = false;
    var sessions as Array = [];        // [state, minutes, label], most urgent first
    var moreSessions as Number = 0;
    var alerts as Array = [];          // [id, kind, buzz, label, detail, openable], most urgent first
    var alertTotal as Number = 0;
    var pendingAcks as Array<Number> = [] as Array<Number>;
    var macOffset as Number = 0;       // Mac clock minus watch clock, seconds
    var onSettings as Method? = null;  // called with a decoded SETTINGS dictionary

    var _link as Link? = null;
    var _feedStage as Dictionary = {}; // channel => [batch, items with nulls for missing]
    var _seen as Dictionary = {};      // ids in the last ALERTS list, already buzzed

    function initialize() {
        everConnected = Application.Storage.getValue("everConnected") == true;
    }

    function linkUp(link as Link) as Void {
        _link = link;
        connected = true;
        if (!everConnected) {
            everConnected = true;
            Application.Storage.setValue("everConnected", true);
        }
        for (var i = 0; i < pendingAcks.size(); i++) {
            link.send(Proto.ack(link.nextMsgId(), pendingAcks[i]));
        }
        pendingAcks = [] as Array<Number>;
        WatchUi.requestUpdate();
    }

    function linkDown() as Void {
        connected = false;
        _feedStage = {};
        WatchUi.requestUpdate();
    }

    // Applies one decoded Mac -> watch message.
    function handle(d as Dictionary) as Void {
        var t = d[:type];
        if (t == Proto.HELLO_REPLY) {
            versionMismatch = d[:version] != Proto.VERSION;
            macOffset = (d[:macTime] as Number) - Time.now().value();
            sendSettings();
        }
        if (versionMismatch) {
            return;
        }
        if (t == Proto.SESSIONS) {
            sessions = d[:list] as Array;
            moreSessions = d[:more] as Number;
        } else if (t == Proto.ALERTS) {
            setAlerts(d[:list] as Array, d[:total] as Number);
        } else if (t == Proto.BUZZ) {
            var a = find(d[:id] as Number);
            if (a != null) {
                Buzz.play(a[1] as Number);
            }
        } else if (t == Proto.TEST_SIGNAL) {
            Buzz.play(d[:kind] as Number);
        } else if (t == Proto.WEATHER) {
            MacWeather.save(d, macOffset);
        } else if (t == Proto.LOCATION) {
            MacWeather.saveLocation(d[:lat] as Float, d[:lon] as Float);
        } else if (t == Proto.FEED) {
            stageFeed(d);
        } else if (t == Proto.SETTINGS && onSettings != null) {
            (onSettings as Method).invoke(d);
        }
        WatchUi.requestUpdate();
    }

    // Collects one FEED item; a channel's set is saved only once every item of its batch has
    // arrived, and a newer batch replaces a partial older one (mac-content-feeds).
    function stageFeed(d as Dictionary) as Void {
        var ch = d[:channel] as Number;
        var n = d[:count] as Number;
        var i = d[:index] as Number;
        if (Feeds.CHANNELS.indexOf(ch) < 0 || n < 1 || n > Feeds.MAX_ITEMS || i >= n) {
            return;
        }
        var stage = _feedStage[ch] as Array?;
        if (stage == null || stage[0] != d[:batch] || (stage[1] as Array).size() != n) {
            stage = [d[:batch], new [n]];
            _feedStage[ch] = stage;
        }
        var items = stage[1] as Array;
        if (items[i] != null) {
            return;
        }
        items[i] = [d[:stamp], d[:source], d[:text]];
        for (var k = 0; k < n; k++) {
            if (items[k] == null) {
                return;
            }
        }
        Feeds.save(ch, d[:batch] as Number, items, macOffset);
        _feedStage.remove(ch);
    }

    function setAlerts(list as Array, total as Number) as Void {
        // Acknowledged here but not yet confirmed by the Mac: keep hidden.
        var shown = [];
        for (var i = 0; i < list.size(); i++) {
            var a = list[i] as Array;
            if (pendingAcks.indexOf(a[0]) < 0) {
                shown.add(a);
            }
        }
        alerts = shown;
        alertTotal = total - (list.size() - shown.size());
        var kinds = toBuzz(list);
        for (var i = 0; i < kinds.size(); i++) {
            Buzz.play(kinds[i]);
        }
    }

    // Kinds to buzz for in this ALERTS list. Only ids still listed are remembered, because the Mac
    // reuses ids after a restart and after 255 alerts: a returning id is a new alert.
    function toBuzz(list as Array) as Array<Number> {
        var out = [] as Array<Number>;
        var seen = {};
        for (var i = 0; i < list.size(); i++) {
            var a = list[i] as Array;
            if (a[2] == true && !_seen.hasKey(a[0]) && pendingAcks.indexOf(a[0]) < 0) {
                out.add(a[1] as Number);
            }
            seen[a[0]] = true;
        }
        _seen = seen;
        return out;
    }

    // The alert to show, or null.
    function current() as Array? {
        return alerts.size() > 0 ? alerts[0] as Array : null;
    }

    // A live tap on an openable alert also asks the Mac to open its session (open-agent-session).
    function opensOnTap(a as Array) as Boolean {
        return connected && a.size() > 5 && a[5] == true;
    }

    // Tap on a showing alert.
    function acknowledge() as Void {
        var a = current();
        if (a == null) {
            return;
        }
        var id = a[0] as Number;
        var open = opensOnTap(a);
        alerts = alerts.slice(1, null);
        alertTotal = alertTotal > 0 ? alertTotal - 1 : 0;
        var link = _link;
        if (connected && link != null) {
            link.send(open ? Proto.open(link.nextMsgId(), id) : Proto.ack(link.nextMsgId(), id));
        } else {
            pendingAcks.add(id);
        }
        WatchUi.requestUpdate();
    }

    // Sends the watch's settings so the Mac can adopt them if they are newer.
    function sendSettings() as Void {
        var link = _link;
        if (connected && link != null) {
            link.send(Proto.settings(link.nextMsgId(), Settings.snapshot()));
        }
    }

    function find(id as Number) as Array? {
        for (var i = 0; i < alerts.size(); i++) {
            if ((alerts[i] as Array)[0] == id) {
                return alerts[i] as Array;
            }
        }
        return null;
    }

    // Most urgent session state, or null with no sessions.
    function topState() as Number? {
        return sessions.size() > 0 ? (sessions[0] as Array)[0] as Number : null;
    }
}

// The three vibration patterns: done one short pulse, failed two sharp, needs you three.
module Buzz {
    const SIGNAL_BEEP = 1;
    const SIGNAL_LIGHT = 2;
    const SOUND_SOFT = 0;
    const SOUND_CHIME = 1;

    // What to do for a buzz: [vibrate, beep, light]. The watch can't vibrate while charging,
    // so the On the charger setting picks a beep and/or the backlight instead (charger-alert-signal).
    // Quiet hours drop the light (quiet-hours).
    function plan(charging as Boolean, signal as Number, quiet as Boolean) as Array<Boolean> {
        if (!charging) {
            return [true, false, false];
        }
        return [false, (signal & SIGNAL_BEEP) != 0, !quiet && (signal & SIGNAL_LIGHT) != 0];
    }

    function play(kind as Number) as Void {
        var stats = System.getSystemStats();
        var charging = (stats has :charging) && stats.charging == true;
        var p = plan(charging, Settings.get("chargerSignal", 1) as Number, Settings.quietNow());
        if (p[0] && Attention has :vibrate) {
            Attention.vibrate(vibes(kind));
        }
        if (p[1] && Attention has :playTone) {
            beep(kind, Settings.get("beepSound", 0) as Number);
        }
        if (p[2] && Attention has :backlight) {
            Attention.backlight(true);
        }
    }

    function vibes(kind as Number) as Array<Attention.VibeProfile> {
        if (kind == Proto.K_DONE) {
            return [new Attention.VibeProfile(60, 200)];
        } else if (kind == Proto.K_FAILED) {
            return [new Attention.VibeProfile(100, 120), new Attention.VibeProfile(0, 120), new Attention.VibeProfile(100, 120)];
        }
        return [new Attention.VibeProfile(100, 250), new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 250), new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 250)];
    }

    // Tone notes as [Hz, ms] pairs; 0 Hz is a gap. Low and short is quiet: no volume API exists.
    function notes(kind as Number, sound as Number) as Array<Array<Number>> {
        if (sound == SOUND_CHIME) {
            if (kind == Proto.K_DONE) {
                return [[880, 90], [1320, 90]];
            } else if (kind == Proto.K_FAILED) {
                return [[660, 90], [440, 120]];
            }
            return [[880, 90], [1100, 90], [1320, 90]];
        }
        var clicks = kind == Proto.K_DONE ? 1 : kind == Proto.K_FAILED ? 2 : 3;
        var out = [];
        for (var i = 0; i < clicks; i++) {
            if (i > 0) {
                out.add([0, 120]);
            }
            out.add([600, 40]);
        }
        return out;
    }

    function beep(kind as Number, sound as Number) as Void {
        if (sound != SOUND_SOFT && sound != SOUND_CHIME) {
            var tone = kind == Proto.K_DONE ? Attention.TONE_SUCCESS
                : kind == Proto.K_FAILED ? Attention.TONE_FAILURE : Attention.TONE_ALERT_HI;
            Attention.playTone(tone);
            return;
        }
        var n = notes(kind, sound);
        var profile = [];
        for (var i = 0; i < n.size(); i++) {
            profile.add(new Attention.ToneProfile(n[i][0], n[i][1]));
        }
        Attention.playTone({ :toneProfile => profile, :repeatCount => 0 });
    }
}
