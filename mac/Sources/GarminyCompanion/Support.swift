import AppKit
import CoreGraphics
import Foundation
import GarminyCore
import IOKit.pwr_mgt

/// Appends to ~/Library/Logs/garminy-companion.log.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/garminy-companion.log")
    static let stamp = ISO8601DateFormatter()
    /// Set `defaults write com.github.williamthepoon.garminy.companion debugFrames -bool true` to log every frame.
    static var debugFrames: Bool { UserDefaults.standard.bool(forKey: "debugFrames") }

    static func info(_ s: String) {
        let line = "\(stamp.string(from: Date())) \(s)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func frame(_ dir: String, _ d: Data) {
        guard debugFrames else { return }
        info("\(dir) \(d.map { String(format: "%02x", $0) }.joined())")
    }
}

/// Idle time, screen lock, sleep/wake and the frontmost app. No special permissions.
final class PresenceMonitor {
    private(set) var locked = false
    var onChange: (() -> Void)?
    var onWake: (() -> Void)?
    var onSleep: (() -> Void)?

    init() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = true; self?.onChange?()
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = false; self?.onChange?()
        }
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.onSleep?() }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.onWake?() }
    }

    var snapshot: Presence {
        let any = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: any)
        return Presence(idleSeconds: idle, locked: locked,
                        frontmostBundle: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }
}

/// Holds an idle-sleep assertion while work runs.
final class KeepAwake {
    private var id: IOPMAssertionID = 0
    private(set) var held = false

    func set(_ on: Bool) {
        if on == held { return }
        if on {
            held = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                               IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "garminy: agents or a long command are running" as CFString, &id) == kIOReturnSuccess
        } else {
            IOPMAssertionRelease(id)
            held = false
        }
        Log.info("keep awake \(held ? "on" : "off")")
    }
}

