import Toybox.Application;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Test;
import Toybox.Time;

// Protocol tests: the same frames as mac/Tests/vectors.md.

(:test)
module TC {
    function bytes(hex as String) as ByteArray {
        return StringUtil.convertEncodedString(hex, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY
        }) as ByteArray;
    }

    function hex(b as ByteArray) as String {
        return StringUtil.convertEncodedString(b, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX
        }) as String;
    }

    // Feeds hex frames and decodes the completed message.
    function run(frames as Array<String>) as Dictionary? {
        var a = new Proto.Assembler();
        var out = null;
        for (var i = 0; i < frames.size(); i++) {
            out = a.feed(bytes(frames[i]));
        }
        return out == null ? null : Proto.decode(out[0] as Number, out[1] as ByteArray);
    }
}

(:test)
function testProtoSingleFrames(logger as Test.Logger) as Boolean {
    var ok = true;
    var hb = TC.run(["090701"]);
    ok &= T.check(logger, "heartbeat", hb != null && hb[:type] == Proto.HEARTBEAT);
    var hr = TC.run(["0101010168e77800"]);
    ok &= T.check(logger, "hello reply", hr != null && hr[:version] == 1 && hr[:macTime] == 1760000000);
    var bz = TC.run(["04040102"]);
    ok &= T.check(logger, "buzz", bz != null && bz[:id] == 2);
    var loc = TC.run(["06090111c6e343"]);
    ok &= T.check(logger, "location", loc != null && ((loc[:lat] as Float) - 45.5).abs() < 0.001 && ((loc[:lon] as Float) + 73.57).abs() < 0.001);
    var s = TC.run(["070a0168e7780001ff0a0021090000010100"]);
    ok &= T.check(logger, "settings", s != null && s[:changedAt] == 1760000000 && s[:cards] == 0x1FF && s[:interval] == 10
        && (s[:cities] as Array)[1] == 33 && s[:companion] == true && s[:chargerSignal] == 1 && s[:beepSound] == 0);
    var old = TC.run(["070b0168e7780001ff0a002109000001"]);
    ok &= T.check(logger, "13-byte settings get defaults", old != null && old[:chargerSignal] == 1 && old[:beepSound] == 0);
    var ts = TC.run(["0a0f0100"]);
    ok &= T.check(logger, "test signal", ts != null && ts[:type] == Proto.TEST_SIGNAL && ts[:kind] == Proto.K_NEEDS_YOU);
    return ok;
}

(:test)
function testProtoMultiPart(logger as Test.Logger) as Boolean {
    var ok = true;
    var w = TC.run(["050b0268e778000c010f060309020368e7728800", "050b120a141e28323c46505a64ff"]);
    ok &= T.check(logger, "weather", w != null && w[:temp] == 12 && (w[:today] as Array)[0] == 15
        && (w[:tomorrow] as Array)[1] == 2 && w[:base] == 1759998600 && (w[:chances] as Array)[11] == 255);
    var a = TC.run(["030c020101010001076761726d696e7910506572", "030c126d697373696f6e3a2042617368"]);
    var first = a == null ? null : ((a[:list] as Array)[0] as Array);
    ok &= T.check(logger, "alerts", first != null && first[0] == 1 && first[1] == Proto.K_NEEDS_YOU && first[2] == true
        && "garminy".equals(first[3]) && "Permission: Bash".equals(first[4]) && first[5] == false);
    var o = TC.run(["030e010101020202076761726d696e7902346d"]);
    var op = o == null ? null : ((o[:list] as Array)[0] as Array);
    ok &= T.check(logger, "openable alert", op != null && op[1] == Proto.K_DONE && op[2] == false && op[5] == true);
    var ss = TC.run(["020d030300010000076761726d696e7900000c07", "020d136170692d73766302000307776562736974", "020d2365"]);
    var list = ss == null ? [] : ss[:list] as Array;
    ok &= T.check(logger, "sessions", list.size() == 3 && (list[1] as Array)[1] == 12 && "website".equals((list[2] as Array)[2]));
    return ok;
}

(:test)
function testProtoDropsIncomplete(logger as Test.Logger) as Boolean {
    var ok = true;
    ok &= T.check(logger, "missing part", TC.run(["020d030300010000076761726d696e7900000c07", "020d2365"]) == null);
    ok &= T.check(logger, "interleaved", TC.run(["020d030300010000076761726d696e7900000c07", "030c126d697373696f6e3a2042617368",
        "020d136170692d73766302000307776562736974"]) == null);
    ok &= T.check(logger, "truncated payload", TC.run(["0101010168e7"]) == null);
    return ok;
}

(:test)
function testProtoEncodes(logger as Test.Logger) as Boolean {
    var ok = true;
    ok &= T.check(logger, "hello", TC.hex(Proto.hello(0)[0]).equals("41000101"));
    ok &= T.check(logger, "ack", TC.hex(Proto.ack(3, 5)[0]).equals("42030105"));
    ok &= T.check(logger, "open", TC.hex(Proto.open(6, 5)[0]).equals("44060105"));
    var s = { :changedAt => 1760000000, :cards => 0x1FF, :interval => 10, :cities => [0, 33, 9],
              :units => 0, :backlight => 0, :companion => true, :chargerSignal => 1, :beepSound => 0 };
    ok &= T.check(logger, "settings", TC.hex(Proto.settings(10, s)[0]).equals("430a0168e7780001ff0a0021090000010100"));
    return ok;
}

(:test)
function testLinkPolicyBackoff(logger as Test.Logger) as Boolean {
    var ok = true;
    ok &= T.check(logger, "scan at start", LinkPolicy.scanNow(0));
    ok &= T.check(logger, "scan at 9 min", LinkPolicy.scanNow(9 * 60000));
    ok &= T.check(logger, "burst at 10 min", LinkPolicy.scanNow(600000 + 2000));
    ok &= T.check(logger, "quiet at 11 min", !LinkPolicy.scanNow(660000));
    ok &= T.check(logger, "burst at 15 min", LinkPolicy.scanNow(900000 + 5000));
    ok &= T.check(logger, "quiet after burst", !LinkPolicy.scanNow(900000 + 10001));
    // Within an hour of back-off, gaps between bursts never exceed 5 minutes.
    var last = 600000;
    var worst = 0;
    for (var t = 600000; t < 4200000; t += 1000) {
        if (LinkPolicy.scanNow(t)) {
            if (t - last > worst) {
                worst = t - last;
            }
            last = t;
        }
    }
    ok &= T.check(logger, "gap <= 5 min", worst <= 300000);
    ok &= T.check(logger, "lost after 30 s", LinkPolicy.lost(30001) && !LinkPolicy.lost(29000));
    ok &= T.check(logger, "connect timeout", LinkPolicy.connectTimedOut(30001) && !LinkPolicy.connectTimedOut(1000));
    ok &= T.check(logger, "write timeout", LinkPolicy.writeTimedOut(5001) && !LinkPolicy.writeTimedOut(4000));
    return ok;
}

(:test)
function testCompanionSnapshotReplacesQueue(logger as Test.Logger) as Boolean {
    var c = new Companion();
    c.handle({ :type => Proto.ALERTS, :total => 2, :list => [[1, Proto.K_NEEDS_YOU, false, "a", ""], [2, Proto.K_DONE, false, "b", ""]] });
    var ok = T.check(logger, "two alerts", c.alerts.size() == 2 && (c.current() as Array)[0] == 1);
    c.handle({ :type => Proto.ALERTS, :total => 1, :list => [[2, Proto.K_DONE, false, "b", ""]] });
    ok &= T.check(logger, "replaced", c.alerts.size() == 1 && (c.current() as Array)[0] == 2 && c.alertTotal == 1);
    c.handle({ :type => Proto.ALERTS, :total => 0, :list => [] });
    ok &= T.check(logger, "cleared", c.current() == null);
    return ok;
}

(:test)
function testCompanionOfflineAck(logger as Test.Logger) as Boolean {
    var c = new Companion();
    c.handle({ :type => Proto.ALERTS, :total => 2, :list => [[7, Proto.K_FAILED, false, "pytest", ""], [8, Proto.K_DONE, false, "cargo", ""]] });
    c.acknowledge();
    var ok = T.check(logger, "removed locally", c.alerts.size() == 1 && (c.current() as Array)[0] == 8);
    ok &= T.check(logger, "pending ack", c.pendingAcks.size() == 1 && c.pendingAcks[0] == 7);
    // A snapshot that still contains 7 (the Mac hasn't heard yet) keeps it hidden.
    c.handle({ :type => Proto.ALERTS, :total => 2, :list => [[7, Proto.K_FAILED, false, "pytest", ""], [8, Proto.K_DONE, false, "cargo", ""]] });
    ok &= T.check(logger, "still hidden", c.alerts.size() == 1 && c.alertTotal == 1);
    return ok;
}

(:test)
function testOpensOnTapOnlyForLiveOpenable(logger as Test.Logger) as Boolean {
    var c = new Companion();
    var claude = [2, Proto.K_DONE, false, "garminy", "Done · 4m", true];
    var shell = [3, Proto.K_DONE, false, "cargo", "2m", false];
    var ok = T.check(logger, "offline never opens", !c.opensOnTap(claude));
    c.connected = true;
    ok &= T.check(logger, "live openable opens", c.opensOnTap(claude));
    ok &= T.check(logger, "shell only dismisses", !c.opensOnTap(shell));
    return ok;
}

(:test)
function testCompanionVersionMismatch(logger as Test.Logger) as Boolean {
    var c = new Companion();
    c.handle({ :type => Proto.HELLO_REPLY, :version => 99, :macTime => 1760000000 });
    c.handle({ :type => Proto.ALERTS, :total => 1, :list => [[1, Proto.K_DONE, false, "x", ""]] });
    var ok = T.check(logger, "mismatch flagged", c.versionMismatch);
    ok &= T.check(logger, "content ignored", c.current() == null);
    c.handle({ :type => Proto.HELLO_REPLY, :version => Proto.VERSION, :macTime => 1760000000 });
    ok &= T.check(logger, "cleared on match", !c.versionMismatch);
    return ok;
}

(:test)
function testCompanionSettingStartsAndStopsLink(logger as Test.Logger) as Boolean {
    Application.Properties.setValue("companion", true);
    var c = new Companion();
    var link = new Link(c);
    var v = new CarouselView(c, link);
    var ok = T.check(logger, "started: " + link.state, link.state != Link.OFF);
    Application.Properties.setValue("companion", false);
    v.reload();
    ok &= T.check(logger, "stopped", link.state == Link.OFF);
    return ok;
}

(:test)
function testTapAcknowledgesAlertElsePins(logger as Test.Logger) as Boolean {
    Application.Properties.setValue("companion", false);
    var c = new Companion();
    var v = new CarouselView(c, new Link(c));
    c.handle({ :type => Proto.ALERTS, :total => 1, :list => [[3, Proto.K_DONE, false, "cargo", "2m"]] });
    v.tap();
    var ok = T.check(logger, "alert acknowledged", c.current() == null && c.pendingAcks.size() == 1);
    ok &= T.check(logger, "pin unchanged", !v._pinned);
    v.tap();
    ok &= T.check(logger, "next tap pins", v._pinned);
    // Navigation never acknowledges.
    c.handle({ :type => Proto.ALERTS, :total => 1, :list => [[4, Proto.K_FAILED, false, "pytest", "4m"]] });
    v.next();
    ok &= T.check(logger, "swipe keeps alert", c.current() != null);
    return ok;
}

(:test)
function testRotationPausesDuringAlert(logger as Test.Logger) as Boolean {
    Application.Properties.setValue("companion", false);
    var c = new Companion();
    var v = new CarouselView(c, new Link(c));
    c.handle({ :type => Proto.ALERTS, :total => 1, :list => [[5, Proto.K_NEEDS_YOU, false, "garminy", ""]] });
    var idx = v._idx;
    for (var i = 0; i < 25; i++) {
        v.onTick();
    }
    return T.check(logger, "no rotation while alerting", v._idx == idx);
}

(:test)
function testWeatherSourceOrder(logger as Test.Logger) as Boolean {
    var now = 1760000000;
    var ok = true;
    ok &= T.check(logger, "no Garmin, Mac 20 min", WeatherSource.preferMac(null, now - 1200, now));
    ok &= T.check(logger, "Garmin 1 h beats newer Mac", !WeatherSource.preferMac(now - 3600, now - 600, now));
    ok &= T.check(logger, "Garmin 6 h, Mac 30 min", WeatherSource.preferMac(now - 6 * 3600, now - 1800, now));
    ok &= T.check(logger, "Garmin 6 h, Mac 9 h", !WeatherSource.preferMac(now - 6 * 3600, now - 9 * 3600, now));
    ok &= T.check(logger, "no Mac", !WeatherSource.preferMac(now - 6 * 3600, null, now));
    return ok;
}

(:test)
function testUmbrellaFromMac(logger as Test.Logger) as Boolean {
    var now = 1760000000;
    var w = { "base" => now - 1800, "chances" => [10, 20, 60, 30, 255, 0, 0, 0, 0, 0, 0, 0] };
    var u = Umbrella.fromMac(w, now) as Array<Number>;
    var ok = T.check(logger, "peak 60 at +1.5h", u[0] == Umbrella.YES && u[1] == 60 && u[2] == now - 1800 + 7200);
    var dry = Umbrella.fromMac({ "base" => now, "chances" => [5, 10, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0] }, now) as Array<Number>;
    ok &= T.check(logger, "dry", dry[0] == Umbrella.NO && dry[1] == 10);
    return ok;
}

(:test)
function testMacWeatherSavedAndStale(logger as Test.Logger) as Boolean {
    var macNow = Time.now().value() + 100;  // Mac clock 100 s ahead
    var d = { :observed => macNow - 9 * 3600, :temp => 12, :cond => 3, :today => [15, 6, 3], :tomorrow => [9, 2, 3],
              :base => macNow, :chances => [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] };
    MacWeather.save(d, 100);
    var w = MacWeather.get() as Dictionary;
    var ok = T.check(logger, "observed in watch clock", w["observed"] == Time.now().value() - 9 * 3600);
    ok &= T.check(logger, "stale note", "Updated 9h ago".equals(staleNote(w["observed"] as Number, Time.now().value())));
    return ok;
}

(:test)
function testLocationFallsBackToMac(logger as Test.Logger) as Boolean {
    MacWeather.saveLocation(45.5, -73.57);
    var m = LocationSource.choose([null, null, LocationSource.fromMac()]);
    var ok = T.check(logger, "Montreal from Mac", m != null && ((m as Array<Double>)[0] - 45.5d).abs() < 0.001d);
    ok &= T.check(logger, "device first", (LocationSource.choose([[1.0d, 2.0d], [3.0d, 4.0d], LocationSource.fromMac()]) as Array<Double>)[0] == 1.0d);
    return ok;
}

(:test)
function testSettingsFromMacNewerWins(logger as Test.Logger) as Boolean {
    Application.Storage.setValue("settingsChangedAt", 1000);
    var d = { :changedAt => 2000, :cards => 0x1FF & ~(1 << 1), :interval => 60, :cities => [9, -1, 16],
              :units => 2, :backlight => 0, :companion => true, :chargerSignal => 3, :beepSound => 1 };
    var ok = T.check(logger, "applied", Settings.applyRemote(d));
    ok &= T.check(logger, "interval 60", Settings.interval() == 60);
    ok &= T.check(logger, "fortune off", Application.Properties.getValue("cardFortune") == false);
    ok &= T.check(logger, "city2 none", Settings.cities().size() == 2);
    d[:changedAt] = 1500;
    d[:interval] = 5;
    ok &= T.check(logger, "older ignored", !Settings.applyRemote(d) && Settings.interval() == 60);
    var snap = Settings.snapshot();
    ok &= T.check(logger, "snapshot round trip", snap[:changedAt] == 2000 && snap[:interval] == 60 && snap[:units] == 2
        && snap[:chargerSignal] == 3 && snap[:beepSound] == 1);
    TS.reset();
    Application.Storage.deleteValue("settingsChangedAt");
    return ok;
}

(:test)
function testAgentsCardOnlyAfterFirstConnection(logger as Test.Logger) as Boolean {
    TS.reset();
    Application.Properties.setValue("companion", true);
    Application.Properties.setValue("cardAgents", true);
    Application.Storage.deleteValue("everConnected");
    var c = new Companion();
    var link = new Link(c);
    var v = new CarouselView(c, link);
    var ok = T.check(logger, "no agents before connecting: " + TS.ids(v), TS.ids(v).equals("fortune,quote,umbrella,weather,daylight,moon,world,onthisday"));
    c.everConnected = true;
    v.reload();
    ok &= T.check(logger, "agents first after connecting: " + TS.ids(v), TS.ids(v).equals("agents,fortune,quote,umbrella,weather,daylight,moon,world,onthisday"));
    Application.Properties.setValue("cardAgents", false);
    v.reload();
    ok &= T.check(logger, "agents toggle off", TS.ids(v).find("agents") == null);
    link.stop();
    Application.Properties.setValue("cardAgents", true);
    Application.Properties.setValue("companion", false);
    return ok;
}

(:test)
function testChargerSignalPlan(logger as Test.Logger) as Boolean {
    var p = Buzz.plan(false, 3);
    var ok = T.check(logger, "battery vibrates only", p[0] && !p[1] && !p[2]);
    p = Buzz.plan(true, 1);
    ok &= T.check(logger, "charging beep", !p[0] && p[1] && !p[2]);
    p = Buzz.plan(true, 2);
    ok &= T.check(logger, "charging light", !p[0] && !p[1] && p[2]);
    p = Buzz.plan(true, 3);
    ok &= T.check(logger, "charging both", !p[0] && p[1] && p[2]);
    p = Buzz.plan(true, 0);
    ok &= T.check(logger, "charging nothing", !p[0] && !p[1] && !p[2]);
    ok &= T.check(logger, "soft needs-you is 3 clicks", Buzz.notes(Proto.K_NEEDS_YOU, Buzz.SOUND_SOFT).size() == 5);
    ok &= T.check(logger, "soft done is 1 click", Buzz.notes(Proto.K_DONE, Buzz.SOUND_SOFT).size() == 1);
    return ok;
}
