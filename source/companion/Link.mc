import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;

// Timing rules for the companion link, kept pure so they can be unit-tested.
module LinkPolicy {
    const SILENCE_MS = 30000;        // no frame for this long: link lost
    const CONNECT_TIMEOUT_MS = 30000; // pairing or subscribing took too long
    const WRITE_TIMEOUT_MS = 5000;
    const SEARCH_MS = 600000;        // scan continuously for 10 minutes...
    const BACKOFF_PERIOD_MS = 300000; // ...then 10 s every 5 minutes
    const BACKOFF_SCAN_MS = 10000;

    // Whether the radio should be scanning `searching` ms after the search started.
    function scanNow(searching as Number) as Boolean {
        if (searching < SEARCH_MS) {
            return true;
        }
        return (searching - SEARCH_MS) % BACKOFF_PERIOD_MS < BACKOFF_SCAN_MS;
    }

    function lost(sinceRx as Number) as Boolean {
        return sinceRx > SILENCE_MS;
    }

    function connectTimedOut(sinceState as Number) as Boolean {
        return sinceState > CONNECT_TIMEOUT_MS;
    }

    function writeTimedOut(sinceWrite as Number) as Boolean {
        return sinceWrite > WRITE_TIMEOUT_MS;
    }
}

// Watch side of the BLE link: scan for the companion service, connect,
// subscribe, keep one request in flight, and start over when the link goes quiet.
class Link extends BluetoothLowEnergy.BleDelegate {
    enum State { OFF, REGISTERING, SEARCHING, PAIRING, SUBSCRIBING, CONNECTED }

    const SERVICE = BluetoothLowEnergy.longToUuid(0x51C800014A93428DL, 0x9D386812A7B5F0A9L);
    const TO_WATCH = BluetoothLowEnergy.longToUuid(0x51C800024A93428DL, 0x9D386812A7B5F0A9L);
    const TO_MAC = BluetoothLowEnergy.longToUuid(0x51C800044A93428DL, 0x9D386812A7B5F0A9L);

    var state as State = OFF;
    var _model as Companion;
    var _registered as Boolean = false;
    var _device as BluetoothLowEnergy.Device? = null;
    var _stateAt as Number = 0;     // when the current state began
    var _searchAt as Number = 0;    // when the current search began
    var _rxAt as Number = 0;
    var _scanning as Boolean = false;
    var _queue as Array<ByteArray> = [] as Array<ByteArray>;
    var _inFlightAt as Number? = null;
    var _msgId as Number = 0;
    var _asm as Proto.Assembler = new Proto.Assembler();

    function initialize(model as Companion) {
        BleDelegate.initialize();
        _model = model;
    }

    function start() as Void {
        if (state != OFF) {
            return;
        }
        BluetoothLowEnergy.setDelegate(self);
        if (_registered) {
            search();
            return;
        }
        enter(REGISTERING);
        try {
            BluetoothLowEnergy.registerProfile({
                :uuid => SERVICE,
                :characteristics => [
                    { :uuid => TO_WATCH, :descriptors => [BluetoothLowEnergy.cccdUuid()] },
                    { :uuid => TO_MAC }
                ]
            });
        } catch (e) {
            // Already registered by an earlier start in this process.
            _registered = true;
            search();
        }
    }

    function stop() as Void {
        release();
        setScan(false);
        enter(OFF);
        _model.linkDown();
    }

    // Called every second from the carousel timer.
    function tick() as Void {
        var now = System.getTimer();
        if (state == SEARCHING) {
            setScan(LinkPolicy.scanNow(now - _searchAt));
        } else if ((state == PAIRING || state == SUBSCRIBING) && LinkPolicy.connectTimedOut(now - _stateAt)) {
            restart();
        } else if (state == CONNECTED && LinkPolicy.lost(now - _rxAt)) {
            restart();
        }
        if (_inFlightAt != null && LinkPolicy.writeTimedOut(now - (_inFlightAt as Number))) {
            _inFlightAt = null;
            pump();
        }
    }

    // Queues a message (already split into frames) for the Mac.
    function send(frames as Array<ByteArray>) as Void {
        _queue.addAll(frames);
        pump();
    }

    function nextMsgId() as Number {
        _msgId = (_msgId + 1) % 256;
        return _msgId;
    }

    function isConnected() as Boolean {
        return state == CONNECTED;
    }

    // --- BleDelegate ---

    function onProfileRegister(uuid as BluetoothLowEnergy.Uuid, status as BluetoothLowEnergy.Status) as Void {
        _registered = true;
        if (state == REGISTERING) {
            search();
        }
    }

    function onScanResults(results as BluetoothLowEnergy.Iterator) as Void {
        if (state != SEARCHING) {
            return;
        }
        for (var r = results.next(); r != null; r = results.next()) {
            if (r instanceof BluetoothLowEnergy.ScanResult && advertises(r)) {
                setScan(false);
                enter(PAIRING);
                try {
                    _device = BluetoothLowEnergy.pairDevice(r);
                } catch (e) {
                    restart();
                }
                return;
            }
        }
    }

    function onConnectedStateChanged(device as BluetoothLowEnergy.Device, cs as BluetoothLowEnergy.ConnectionState) as Void {
        if (state == OFF) {
            return;
        }
        if (cs == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            _device = device;
            enter(SUBSCRIBING);
            var c = characteristic(TO_WATCH);
            var cccd = c != null ? c.getDescriptor(BluetoothLowEnergy.cccdUuid()) : null;
            if (cccd == null) {
                restart();
                return;
            }
            cccd.requestWrite([0x01, 0x00]b);
        } else {
            restart();
        }
    }

    function onDescriptorWrite(d as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        if (state != SUBSCRIBING) {
            return;
        }
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            restart();
            return;
        }
        enter(CONNECTED);
        _rxAt = System.getTimer();
        _queue = [] as Array<ByteArray>;
        _inFlightAt = null;
        send(Proto.hello(nextMsgId()));
        _model.linkUp(self);
    }

    function onCharacteristicChanged(c as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        _rxAt = System.getTimer();
        var msg = _asm.feed(value);
        if (msg != null) {
            var d = Proto.decode(msg[0] as Number, msg[1] as ByteArray);
            if (d != null) {
                _model.handle(d);
            }
        }
    }

    function onCharacteristicWrite(c as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        _inFlightAt = null;
        pump();
    }

    // --- internals ---

    function enter(s as State) as Void {
        if (s != state) {
            System.println("garminy link: " + ["OFF", "REGISTERING", "SEARCHING", "PAIRING", "SUBSCRIBING", "CONNECTED"][s]);
        }
        state = s;
        _stateAt = System.getTimer();
    }

    function search() as Void {
        enter(SEARCHING);
        _searchAt = _stateAt;
        _scanning = false;
        setScan(true);
    }

    // Drop the connection and look for the Mac again.
    function restart() as Void {
        var wasConnected = state == CONNECTED;
        release();
        if (wasConnected) {
            _model.linkDown();
        }
        search();
    }

    function release() as Void {
        if (_device != null) {
            try {
                BluetoothLowEnergy.unpairDevice(_device as BluetoothLowEnergy.Device);
            } catch (e) {
            }
        }
        _device = null;
        _queue = [] as Array<ByteArray>;
        _inFlightAt = null;
        _asm.reset();
    }

    function setScan(on as Boolean) as Void {
        if (on == _scanning) {
            return;
        }
        _scanning = on;
        BluetoothLowEnergy.setScanState(on ? BluetoothLowEnergy.SCAN_STATE_SCANNING : BluetoothLowEnergy.SCAN_STATE_OFF);
    }

    function pump() as Void {
        if (_inFlightAt != null || _queue.size() == 0 || state != CONNECTED) {
            return;
        }
        var c = characteristic(TO_MAC);
        if (c == null) {
            restart();
            return;
        }
        var f = _queue[0];
        _queue = _queue.slice(1, null);
        try {
            _inFlightAt = System.getTimer();
            c.requestWrite(f, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
        } catch (e) {
            _inFlightAt = null;
        }
    }

    function advertises(r as BluetoothLowEnergy.ScanResult) as Boolean {
        var it = r.getServiceUuids();
        for (var u = it.next(); u != null; u = it.next()) {
            if (SERVICE.equals(u)) {
                return true;
            }
        }
        return false;
    }

    function characteristic(uuid as BluetoothLowEnergy.Uuid) as BluetoothLowEnergy.Characteristic? {
        var d = _device;
        var s = d != null ? d.getService(SERVICE) : null;
        return s != null ? s.getCharacteristic(uuid) : null;
    }
}
