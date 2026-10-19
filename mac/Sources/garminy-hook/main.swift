// garminy-hook: forwards Claude Code hook events and shell command events to the
// garminy companion over its Unix socket. It never blocks the caller and always exits 0.
//
//   garminy-hook claude                         (Claude Code hook; JSON on stdin)
//   garminy-hook shell start|end --cmd NAME [--exit N] [--secs N] --pid N [--threshold N]
//   garminy-hook shell-init zsh                 (prints the zsh snippet)
import Foundation
import GarminyCore

// Hard stop: whatever happens, exit 0 within 190 ms.
DispatchQueue.global().asyncAfter(deadline: .now() + 0.19) { exit(0) }

let socketPath = SocketServer.path
let term = ProcessInfo.processInfo.environment["TERM_PROGRAM"]

func send(_ e: HookEvent) {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return }
    defer { close(fd) }
    var tv = timeval(tv_sec: 0, tv_usec: 150_000)
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var noSigPipe: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        buf.copyBytes(from: Array(socketPath.utf8.prefix(buf.count - 1)) + [0])
    }
    let ok = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard ok == 0 else { return }
    let line = e.line()
    _ = line.withUnsafeBytes { write(fd, $0.baseAddress, line.count) }
}

/// The controlling terminal of this process or its nearest ancestor, e.g. "/dev/ttys004". No subprocess.
func controllingTTY() -> String? {
    var pid = getpid()
    for _ in 0..<4 {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let dev = info.kp_eproc.e_tdev
        if dev != -1, let name = devname(dev, S_IFCHR) { return "/dev/" + String(cString: name) }
        pid = info.kp_eproc.e_ppid
        if pid <= 1 { return nil }
    }
    return nil
}

func option(_ name: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func hookPath() -> String {
    let installed = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/garminy-hook").path
    if FileManager.default.isExecutableFile(atPath: installed) { return installed }
    return URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
}

let zshSnippet = #"""
# garminy: tell the Mac companion about long terminal commands.
zmodload zsh/datetime
autoload -Uz add-zsh-hook
typeset -g __garminy_start="" __garminy_cmd=""
: ${GARMINY_LONG_CMD_SECS:=30}
: ${GARMINY_IGNORE:="vim nvim vi nano emacs less more man ssh mosh tmux screen top htop btop watch claude"}
__garminy_preexec() {
  [[ -n $CLAUDECODE ]] && return
  local -a words=(${(z)1})
  local w
  for w in $words; do [[ $w == *=* ]] || break; done
  w=${w:t}
  if [[ " $GARMINY_IGNORE " == *" $w "* ]]; then __garminy_start=""; return; fi
  __garminy_cmd=$w
  __garminy_start=$EPOCHREALTIME
  "HOOK" shell start --cmd "$w" --pid $$ --id $__garminy_start --threshold $GARMINY_LONG_CMD_SECS &!
}
__garminy_precmd() {
  local code=$?
  [[ -z $__garminy_start ]] && return
  local secs=$(( ${EPOCHREALTIME%.*} - ${__garminy_start%.*} ))
  "HOOK" shell end --cmd "$__garminy_cmd" --exit $code --secs $secs --pid $$ --id $__garminy_start --threshold $GARMINY_LONG_CMD_SECS &!
  __garminy_start=""
}
add-zsh-hook preexec __garminy_preexec
precmd_functions=(__garminy_precmd ${precmd_functions:#__garminy_precmd})
"""#

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "claude":
    let input = FileHandle.standardInput.readData(ofLength: 1 << 20)
    if let e = HookEvent.fromClaudeHook(input, term: term, env: ProcessInfo.processInfo.environment,
                                        tty: controllingTTY()) { send(e) }
case "shell" where args.count >= 2 && (args[1] == "start" || args[1] == "end"):
    send(HookEvent(src: "shell", phase: args[1], cmd: option("--cmd", in: args).map { String($0.prefix(24)) },
                   exit: option("--exit", in: args).flatMap { Int($0) },
                   secs: option("--secs", in: args).flatMap { Int($0) },
                   pid: option("--pid", in: args).flatMap { Int($0) },
                   id: option("--id", in: args),
                   threshold: option("--threshold", in: args).flatMap { Int($0) }, term: term))
case "shell-init":
    print(zshSnippet.replacingOccurrences(of: "\"HOOK\"", with: "'\(hookPath())'"))
default:
    break
}
exit(0)
