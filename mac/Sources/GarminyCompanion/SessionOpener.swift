import AppKit
import Foundation
import GarminyCore

/// Brings a Claude Code session's terminal to the front (open-agent-session).
/// iTerm2 and Terminal get the exact tab via AppleScript; any other host app is just activated.
final class SessionOpener {
    static let iTerm = "com.googlecode.iterm2"
    static let terminal = "com.apple.Terminal"

    private let queue = DispatchQueue(label: "garminy.opener")

    func open(_ loc: SessionLocation, label: String) {
        queue.async { self.run(loc, label: label) }
    }

    /// Reads the selected tab of iTerm2 or Terminal and calls back on the main queue,
    /// with nil when it can't be read. Never asks for Automation permission.
    func selectedTab(in app: String, _ done: @escaping @Sendable (SessionLocation?) -> Void) {
        queue.async {
            var result: SessionLocation?
            if Self.mayAutomate(app) {
                let script = app == Self.iTerm
                    ? "tell application id \"\(Self.iTerm)\" to return unique id of current session of current window"
                    : "tell application id \"\(Self.terminal)\" to return tty of selected tab of front window"
                var err: NSDictionary?
                if let s = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue, err == nil {
                    result = app == Self.iTerm ? SessionLocation(app: app, itermSession: s, tty: nil)
                                               : SessionLocation(app: app, itermSession: nil, tty: s)
                }
            }
            DispatchQueue.main.async { done(result) }
        }
    }

    /// Whether Automation for `app` is already granted, without prompting.
    static func mayAutomate(_ app: String) -> Bool {
        var addr = AEAddressDesc()
        let id = Array(app.utf8)
        guard AECreateDesc(DescType(typeApplicationBundleID), id, id.count, &addr) == noErr else { return false }
        defer { AEDisposeDesc(&addr) }
        return AEDeterminePermissionToAutomateTarget(&addr, AEEventClass(typeWildCard), AEEventID(typeWildCard), false) == noErr
    }

    private func run(_ loc: SessionLocation, label: String) {
        guard let app = loc.app,
              let running = NSRunningApplication.runningApplications(withBundleIdentifier: app).first,
              let url = running.bundleURL else {
            Log.info("open \(label): host app \(loc.app ?? "unknown") not running")
            return
        }
        var script: String?
        if app == Self.iTerm, let id = loc.itermSession {
            script = """
            tell application id "\(Self.iTerm)"
              repeat with w in windows
                repeat with t in tabs of w
                  repeat with s in sessions of t
                    if unique id of s is "\(id)" then
                      select w
                      tell t to select
                      tell s to select
                      activate
                      return "ok"
                    end if
                  end repeat
                end repeat
              end repeat
            end tell
            return "missing"
            """
        } else if app == Self.terminal, let tty = loc.tty {
            script = """
            tell application id "\(Self.terminal)"
              repeat with w in windows
                repeat with t in tabs of w
                  if tty of t is "\(tty)" then
                    set selected of t to true
                    set index of w to 1
                    activate
                    return "ok"
                  end if
                end repeat
              end repeat
            end tell
            return "missing"
            """
        }
        if let script {
            var err: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&err)
            if let err {
                let code = err[NSAppleScript.errorNumber] as? Int ?? 0
                Log.info(code == -1743 ? "open \(label): Automation permission needed for \(app)"
                                       : "open \(label): AppleScript error \(code) \(err[NSAppleScript.errorMessage] ?? "")")
            } else if result?.stringValue == "ok" {
                Log.info("open \(label): selected tab in \(app)")
                return
            } else {
                Log.info("open \(label): tab not found in \(app)")
            }
        }
        // Launch Services activation works from a background app, where activate() may not.
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            Log.info(error.map { "open \(label): \($0)" } ?? "open \(label): activated \(app)")
        }
    }
}
