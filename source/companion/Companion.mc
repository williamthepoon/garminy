import Toybox.Application;
import Toybox.Attention;
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
    var alerts as Array = [];          // [id, kind, buzz, label, detail], most urgent first
    var alertTotal as Number = 0;
    var pendingAcks as Array<Number> = [] as Array<Number>;
    var macOffset as Number = 0;       // Mac clock minus watch clock, seconds
    var onSettings as Method? = null;  // called with a decoded SETTINGS dictionary

    var _link as Link? = null;
    var _seen as Dictionary = {};      // alert ids already buzzed this run

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
        } else if (t == Proto.WEATHER) {
            MacWeather.save(d, macOffset);
        } else if (t == Proto.LOCATION) {
            MacWeather.saveLocation(d[:lat] as Float, d[:lon] as Float);
        } else if (t == Proto.SETTINGS && onSettings != null) {
            (onSettings as Method).invoke(d);
        }
        WatchUi.requestUpdate();
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
        for (var i = 0; i < alerts.size(); i++) {
            var a = alerts[i] as Array;
            if (a[2] == true && !_seen.hasKey(a[0])) {
                Buzz.play(a[1] as Number);
            }
            _seen[a[0]] = true;
        }
    }

    // The alert to show, or null.
    function current() as Array? {
        return alerts.size() > 0 ? alerts[0] as Array : null;
    }

    // Tap on a showing alert.
    function acknowledge() as Void {
        var a = current();
        if (a == null) {
            return;
        }
        var id = a[0] as Number;
        alerts = alerts.slice(1, null);
        alertTotal = alertTotal > 0 ? alertTotal - 1 : 0;
        var link = _link;
        if (connected && link != null) {
            link.send(Proto.ack(link.nextMsgId(), id));
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
    function play(kind as Number) as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        var p;
        if (kind == Proto.K_DONE) {
            p = [new Attention.VibeProfile(60, 200)];
        } else if (kind == Proto.K_FAILED) {
            p = [new Attention.VibeProfile(100, 120), new Attention.VibeProfile(0, 120), new Attention.VibeProfile(100, 120)];
        } else {
            p = [new Attention.VibeProfile(100, 250), new Attention.VibeProfile(0, 150),
                 new Attention.VibeProfile(100, 250), new Attention.VibeProfile(0, 150),
                 new Attention.VibeProfile(100, 250)];
        }
        Attention.vibrate(p);
    }
}
