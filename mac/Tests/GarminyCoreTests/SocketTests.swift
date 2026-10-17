import Foundation
import Testing
@testable import GarminyCore

/// The garminy-hook binary built alongside the tests.
func hookBinary() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/debug/garminy-hook")
}

@discardableResult
func runHook(_ args: [String], stdin: String = "", socket: String) throws -> (code: Int32, out: String, ms: Double) {
    let p = Process()
    p.executableURL = hookBinary()
    p.arguments = args
    var env = ProcessInfo.processInfo.environment
    env["GARMINY_SOCKET"] = socket
    env["TERM_PROGRAM"] = "iTerm.app"
    p.environment = env
    let inPipe = Pipe(), outPipe = Pipe()
    p.standardInput = inPipe
    p.standardOutput = outPipe
    p.standardError = outPipe
    let t = Date()
    try p.run()
    inPipe.fileHandleForWriting.write(Data(stdin.utf8))
    try inPipe.fileHandleForWriting.close()
    p.waitUntilExit()
    let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return (p.terminationStatus, out, Date().timeIntervalSince(t) * 1000)
}

final class Box: @unchecked Sendable { var events: [HookEvent] = [] }

@MainActor
@Test func socketIsPrivateAndHookDeliversEvents() async throws {
    let path = "/tmp/garminy-test-\(getpid()).sock"
    let server = SocketServer()
    let box = Box()
    server.onEvent = { box.events.append($0) }
    try server.start(path: path)
    defer { unlink(path) }

    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600)

    let raw = #"{"hook_event_name":"PermissionRequest","session_id":"s","cwd":"/x/garminy","tool_name":"Bash","tool_input":{"command":"rm -rf SECRET"},"prompt":"SECRET"}"#
    let r = try runHook(["claude"], stdin: raw, socket: path)
    #expect(r.code == 0 && r.out.isEmpty)
    try runHook(["shell", "end", "--cmd", "pytest", "--exit", "1", "--secs", "240", "--pid", "7", "--threshold", "30"], socket: path)

    for _ in 0..<40 where box.events.count < 2 { try await Task.sleep(nanoseconds: 50_000_000) }
    #expect(box.events.count == 2)
    let e = try #require(box.events.first)
    #expect(e.event == "PermissionRequest" && e.tool == "Bash" && e.term == "iTerm.app")
    #expect(!String(decoding: e.line(), as: UTF8.self).contains("SECRET"))
    #expect(box.events.last?.cmd == "pytest" && box.events.last?.exit == 1)
}

@Test func hookIsQuietAndFastWithoutCompanion() throws {
    let missing = "/tmp/garminy-none-\(getpid()).sock"
    _ = try runHook(["claude"], stdin: "{}", socket: missing)  // warm up
    for args in [["claude"], ["shell", "start", "--cmd", "make", "--pid", "1"], ["nonsense"]] {
        let r = try runHook(args, stdin: #"{"hook_event_name":"Stop","session_id":"s"}"#, socket: missing)
        #expect(r.code == 0)
        #expect(r.out.isEmpty)
        #expect(r.ms < 200)
    }
}

@Test func shellInitPrintsSnippet() throws {
    let r = try runHook(["shell-init", "zsh"], socket: "/tmp/x.sock")
    #expect(r.out.contains("add-zsh-hook preexec __garminy_preexec"))
    #expect(r.out.contains("CLAUDECODE"))
    #expect(!r.out.contains("\"HOOK\""))
}
