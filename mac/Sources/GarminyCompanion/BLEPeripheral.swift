import CoreBluetooth
import Foundation
import GarminyCore

/// The Mac as the BLE peripheral the watch connects to (mac-link).
final class BLEPeripheral: NSObject, CBPeripheralManagerDelegate {
    static let base = "-4A93-428D-9D38-6812A7B5F0A9"
    static let service = CBUUID(string: "51C80001" + base)
    static let toWatchID = CBUUID(string: "51C80002" + base)
    static let toMacID = CBUUID(string: "51C80004" + base)

    private var pm: CBPeripheralManager!
    private var toWatch: CBMutableCharacteristic?
    private var centrals: Set<UUID> = []
    private var outbox: [Data] = []
    private var msgId: UInt8 = 0
    private var reassembler = Reassembler()
    private var heartbeat: Timer?

    var onConnectionChange: ((Bool) -> Void)?
    var onMessage: ((WatchMessage) -> Void)?
    var onStateChange: (() -> Void)?

    var connected: Bool { !centrals.isEmpty }
    var poweredOn: Bool { pm?.state == .poweredOn }
    var authorization: CBManagerAuthorization { CBManager.authorization }

    func start() {
        pm = CBPeripheralManager(delegate: self, queue: nil)
        heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.connected else { return }
            self.send(.heartbeat)
        }
    }

    func send(_ m: MacMessage) {
        guard connected else { return }
        msgId &+= 1
        outbox.append(contentsOf: Wire.encode(m, msgId: msgId))
        flush()
    }

    /// Restarts advertising, e.g. after the Mac wakes.
    func advertise() {
        guard pm?.state == .poweredOn else { return }
        pm.stopAdvertising()
        pm.startAdvertising([CBAdvertisementDataLocalNameKey: "GRMNY",
                             CBAdvertisementDataServiceUUIDsKey: [Self.service]])
    }

    private func flush() {
        guard let c = toWatch else { return }
        while let f = outbox.first {
            guard pm.updateValue(f, for: c, onSubscribedCentrals: nil) else { return }  // resumes in isReady
            Log.frame("tx", f)
            outbox.removeFirst()
        }
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        Log.info("bluetooth state \(p.state.rawValue), authorization \(CBManager.authorization.rawValue)")
        onStateChange?()
        guard p.state == .poweredOn else {
            centrals.removeAll(); outbox.removeAll()
            onConnectionChange?(false)
            return
        }
        let tw = CBMutableCharacteristic(type: Self.toWatchID, properties: [.notify], value: nil, permissions: [])
        let tm = CBMutableCharacteristic(type: Self.toMacID, properties: [.write, .writeWithoutResponse], value: nil, permissions: [.writeable])
        let svc = CBMutableService(type: Self.service, primary: true)
        svc.characteristics = [tw, tm]
        toWatch = tw
        p.removeAllServices()
        p.add(svc)
    }

    func peripheralManager(_ p: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { Log.info("add service failed: \(error)") }
        advertise()
    }

    func peripheralManagerDidStartAdvertising(_ p: CBPeripheralManager, error: Error?) {
        Log.info(error.map { "advertising failed: \($0)" } ?? "advertising")
    }

    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didSubscribeTo c: CBCharacteristic) {
        centrals.insert(central.identifier)
        Log.info("watch subscribed (max update \(central.maximumUpdateValueLength))")
        onConnectionChange?(true)
    }

    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom c: CBCharacteristic) {
        centrals.remove(central.identifier)
        if centrals.isEmpty { outbox.removeAll() }
        Log.info("watch unsubscribed")
        onConnectionChange?(connected)
    }

    func peripheralManagerIsReady(toUpdateSubscribers p: CBPeripheralManager) {
        flush()
    }

    func peripheralManager(_ p: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for r in requests {
            guard let v = r.value else { continue }
            Log.frame("rx", v)
            if let done = reassembler.feed(v), let m = Wire.decodeWatch(type: done.type, payload: done.payload) {
                onMessage?(m)
            }
        }
        if let first = requests.first { p.respond(to: first, withResult: .success) }
    }
}
