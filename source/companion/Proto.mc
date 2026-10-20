import Toybox.Lang;
import Toybox.StringUtil;

// Wire protocol shared with the Mac companion (mac/Sources/GarminyCore/Wire.swift).
// Frame: [type][msgId][part<<4 | total] + up to 17 payload bytes. Layouts: mac/Tests/vectors.md.
module Proto {
    const VERSION = 1;

    const HELLO_REPLY = 0x01;
    const SESSIONS = 0x02;
    const ALERTS = 0x03;
    const BUZZ = 0x04;
    const WEATHER = 0x05;
    const LOCATION = 0x06;
    const SETTINGS = 0x07;
    const SNAPSHOT_END = 0x08;
    const HEARTBEAT = 0x09;
    const TEST_SIGNAL = 0x0A;
    const FEED = 0x0B;
    const HELLO = 0x41;
    const ACK = 0x42;
    const WATCH_SETTINGS = 0x43;
    const OPEN = 0x44;

    const MAX_PAYLOAD = 17;

    // Session states and alert kinds, as sent by the Mac.
    const S_WORKING = 0;
    const S_NEEDS_YOU = 1;
    const S_DONE = 2;
    const S_ERROR = 3;
    const K_NEEDS_YOU = 0;
    const K_FAILED = 1;
    const K_DONE = 2;

    // Reassembles multi-part messages. Drops a message on a missing or
    // out-of-order part, or when another msgId starts first.
    class Assembler {
        var _type as Number = 0;
        var _id as Number = 0;
        var _next as Number = 0;
        var _total as Number = 0;
        var _buf as ByteArray = []b;

        function initialize() {
        }

        // Returns [type, payload] once a message is complete, else null.
        function feed(f as ByteArray) as Array? {
            if (f.size() < 3 || f.size() > 20) {
                reset();
                return null;
            }
            var part = f[2] >> 4;
            var total = f[2] & 0x0F;
            if (total < 1 || part >= total) {
                reset();
                return null;
            }
            if (part == 0) {
                _type = f[0];
                _id = f[1];
                _total = total;
                _buf = []b;
            } else if (f[0] != _type || f[1] != _id || total != _total || part != _next) {
                reset();
                return null;
            }
            _buf.addAll(f.slice(3, null));
            _next = part + 1;
            if (_next == _total) {
                var out = [_type, _buf];
                reset();
                return out;
            }
            return null;
        }

        function reset() as Void {
            _total = 0;
            _next = 0;
            _buf = []b;
        }
    }

    // Bounds-checked reader; every getter returns null past the end.
    class Reader {
        var _b as ByteArray;
        var _i as Number = 0;

        function initialize(b as ByteArray) {
            _b = b;
        }

        function num(format as Lang.NumberFormat, size as Number) as Number? {
            if (_i + size > _b.size()) {
                _i = _b.size() + 1;
                return null;
            }
            var v = _b.decodeNumber(format, { :offset => _i, :endianness => Lang.ENDIAN_BIG }) as Number;
            _i += size;
            return v;
        }

        function u8() as Number? { return num(Lang.NUMBER_FORMAT_UINT8, 1); }
        // A trailing field added later: absent from an older sender's payload.
        function optU8(fallback as Number) as Number {
            var v = _i < _b.size() ? u8() : null;
            return v == null ? fallback : v;
        }
        function i8() as Number? { return num(Lang.NUMBER_FORMAT_SINT8, 1); }
        function u16() as Number? { return num(Lang.NUMBER_FORMAT_UINT16, 2); }
        function i16() as Number? { return num(Lang.NUMBER_FORMAT_SINT16, 2); }
        function u32() as Number? { return num(Lang.NUMBER_FORMAT_UINT32, 4); }

        function str() as String? {
            var n = u8();
            if (n == null || _i + n > _b.size()) {
                _i = _b.size() + 1;
                return null;
            }
            var s = "";
            if (n > 0) {
                s = StringUtil.convertEncodedString(_b.slice(_i, _i + n), {
                    :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                    :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT
                }) as String;
            }
            _i += n;
            return s;
        }

        // True when every read so far stayed inside the payload.
        function ok() as Boolean {
            return _i <= _b.size();
        }
    }

    // Splits a payload into frames of at most 20 bytes.
    function frames(type as Number, msgId as Number, payload as ByteArray) as Array<ByteArray> {
        var n = (payload.size() + MAX_PAYLOAD - 1) / MAX_PAYLOAD;
        if (n < 1) {
            n = 1;
        }
        var out = [] as Array<ByteArray>;
        for (var i = 0; i < n; i++) {
            var end = (i + 1) * MAX_PAYLOAD;
            if (end > payload.size()) {
                end = payload.size();
            }
            var f = [type, msgId & 0xFF, (i << 4) | n]b;
            f.addAll(payload.slice(i * MAX_PAYLOAD, end));
            out.add(f);
        }
        return out;
    }

    function hello(msgId as Number) as Array<ByteArray> {
        return frames(HELLO, msgId, [VERSION]b);
    }

    function ack(msgId as Number, alertId as Number) as Array<ByteArray> {
        return frames(ACK, msgId, [alertId & 0xFF]b);
    }

    // Acknowledge and ask the Mac to open the session that raised the alert.
    function open(msgId as Number, alertId as Number) as Array<ByteArray> {
        return frames(OPEN, msgId, [alertId & 0xFF]b);
    }

    // s: decoded settings dictionary (same keys as decodeSettings).
    function settings(msgId as Number, s as Dictionary) as Array<ByteArray> {
        var p = new [18]b;
        p.encodeNumber(s[:changedAt] as Number, Lang.NUMBER_FORMAT_UINT32, { :offset => 0, :endianness => Lang.ENDIAN_BIG });
        p.encodeNumber(s[:cards] as Number, Lang.NUMBER_FORMAT_UINT16, { :offset => 4, :endianness => Lang.ENDIAN_BIG });
        p[6] = (s[:interval] as Number) & 0xFF;
        var cities = s[:cities] as Array<Number>;
        for (var i = 0; i < 3; i++) {
            p[7 + i] = (i < cities.size() ? cities[i] : -1) & 0xFF;
        }
        p[10] = (s[:units] as Number) & 0xFF;
        p[11] = (s[:backlight] as Number) & 0xFF;
        p[12] = (s[:companion] as Boolean) ? 1 : 0;
        p[13] = (s[:chargerSignal] as Number) & 0xFF;
        p[14] = (s[:beepSound] as Number) & 0xFF;
        p[15] = (s[:quietHours] as Boolean) ? 1 : 0;
        p[16] = (s[:quietStart] as Number) & 0xFF;
        p[17] = (s[:quietEnd] as Number) & 0xFF;
        return frames(WATCH_SETTINGS, msgId, p);
    }

    function decodeSettings(r as Reader) as Dictionary? {
        var d = {
            :changedAt => r.u32(), :cards => r.u16(), :interval => r.u8(),
            :cities => [r.i8(), r.i8(), r.i8()],
            :units => r.u8(), :backlight => r.u8(), :companion => r.u8() == 1
        };
        d[:chargerSignal] = r.optU8(1);
        d[:beepSound] = r.optU8(0);
        d[:quietHours] = r.optU8(1) == 1;
        d[:quietStart] = r.optU8(18);
        d[:quietEnd] = r.optU8(9);
        return r.ok() ? d : null;
    }

    function day(r as Reader) as Array {
        return [r.i8(), r.i8(), r.u8()];
    }

    // Decodes a complete Mac -> watch payload into a dictionary with :type, or null.
    function decode(type as Number, p as ByteArray) as Dictionary? {
        var r = new Reader(p);
        var d = null as Dictionary?;
        if (type == HELLO_REPLY) {
            d = { :version => r.u8(), :macTime => r.u32() };
        } else if (type == SESSIONS) {
            var n = r.u8();
            var more = r.u8();
            var list = [];
            for (var i = 0; n != null && i < n && r.ok(); i++) {
                list.add([r.u8(), r.u16(), r.str()]);
            }
            d = { :more => more, :list => list };
        } else if (type == ALERTS) {
            var total = r.u8();
            var n = r.u8();
            var list = [];
            for (var i = 0; n != null && i < n && r.ok(); i++) {
                var id = r.u8();
                var kind = r.u8();
                var flags = r.u8();
                flags = flags == null ? 0 : flags;
                // [id, kind, buzz, label, detail, openable]
                list.add([id, kind, (flags & 1) != 0, r.str(), r.str(), (flags & 2) != 0]);
            }
            d = { :total => total, :list => list };
        } else if (type == BUZZ) {
            d = { :id => r.u8() };
        } else if (type == WEATHER) {
            d = { :observed => r.u32(), :temp => r.i8(), :cond => r.u8() };
            d[:today] = day(r);
            d[:tomorrow] = day(r);
            d[:base] = r.u32();
            var chances = [];
            for (var i = 0; i < 12; i++) {
                chances.add(r.u8());
            }
            d[:chances] = chances;
        } else if (type == LOCATION) {
            var lat = r.i16();
            var lon = r.i16();
            if (lat != null && lon != null) {
                d = { :lat => lat / 100.0, :lon => lon / 100.0 };
            }
        } else if (type == SETTINGS) {
            d = decodeSettings(r);
        } else if (type == FEED) {
            d = { :channel => r.u8(), :batch => r.u32(), :index => r.u8(), :count => r.u8(),
                  :stamp => r.u32(), :source => r.str(), :text => r.str() };
        } else if (type == TEST_SIGNAL) {
            d = { :kind => r.u8() };
        } else if (type == SNAPSHOT_END || type == HEARTBEAT) {
            d = {};
        }
        if (d == null || !r.ok()) {
            return null;
        }
        d[:type] = type;
        return d;
    }
}
