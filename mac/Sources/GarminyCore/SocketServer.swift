import Foundation

/// Accepts one JSON line per connection on a Unix socket only the current user can open.
public final class SocketServer: @unchecked Sendable {
    /// The socket path; GARMINY_SOCKET overrides it (tests).
    public static var path: String {
        if let p = ProcessInfo.processInfo.environment["GARMINY_SOCKET"] { return p }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/garminy")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("garminy.sock").path
    }

    private var fd: Int32 = -1
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "garminy.socket")
    public var onEvent: ((HookEvent) -> Void)?
    public var log: (String) -> Void = { _ in }

    public init() {}

    public func start(path: String = SocketServer.path) throws {
        unlink(path)
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let b = Array(path.utf8.prefix(buf.count - 1))
            buf.copyBytes(from: b + [0])
        }
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard ok == 0 else { throw POSIXError(.EADDRINUSE) }
        chmod(path, 0o600)
        listen(fd, 16)
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler { [weak self] in self?.acceptOne() }
        src.resume()
        source = src
        log("socket listening at \(path)")
    }

    private func acceptOne() {
        let c = accept(fd, nil, nil)
        guard c >= 0 else { return }
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while data.count < 65536 {
            let n = read(c, &buf, buf.count)
            if n <= 0 { break }
            data.append(contentsOf: buf[0..<n])
        }
        close(c)
        for line in data.split(separator: 0x0A) {
            if let e = try? JSONDecoder().decode(HookEvent.self, from: Data(line)) {
                DispatchQueue.main.async { self.onEvent?(e) }
            }
        }
    }
}
