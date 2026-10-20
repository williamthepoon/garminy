import AppKit
import GarminyCore
import SwiftUI

@main
struct CompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: delegate.model)
        } label: {
            MenuIcon(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        model.showSettings = { [weak self] in self?.showSettings() }
        model.start()
    }

    /// Opening the app again (Spotlight, Finder, Launchpad) shows the settings window,
    /// so it is reachable even when the menu-bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model, weather: model.weather, news: model.news, daily: model.daily)))
            w.title = "garminy Watch settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MenuIcon: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let needsYou = model.alerts.contains { $0.kind == .needsYou }
        Image(systemName: model.watchConnected ? (needsYou ? "applewatch.radiowaves.left.and.right" : "applewatch") : "applewatch.slash")
    }
}

extension SessionState {
    var word: String {
        switch self {
        case .working: return "working"
        case .needsYou: return "needs you"
        case .done: return "done"
        case .error: return "error"
        }
    }

    var color: Color {
        switch self {
        case .working: return .blue
        case .needsYou: return .orange
        case .done: return .green
        case .error: return .red
        }
    }
}

extension AlertKind {
    var word: String {
        switch self {
        case .needsYou: return "Needs you"
        case .failed: return "Failed"
        case .done: return "Done"
        }
    }
}

struct MenuView: View {
    @ObservedObject var model: AppModel
    @State private var showShellHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(model.watchConnected ? Color.green : Color.secondary).frame(width: 8, height: 8)
                Text(model.watchConnected ? "Watch connected" : "Watch not connected").font(.headline)
            }
            if let note = model.bluetoothNote {
                HStack {
                    Text(note).foregroundStyle(.orange)
                    Button("Open Settings") { model.openBluetoothSettings() }
                }
            }

            Divider()
            Text("Agents").font(.subheadline).foregroundStyle(.secondary)
            if model.sessions.isEmpty {
                Text("No agents running").foregroundStyle(.secondary)
            }
            ForEach(model.sessions, id: \.id) { s in
                HStack {
                    Circle().fill(s.state.color).frame(width: 7, height: 7)
                    Text(s.label)
                    Spacer()
                    Text(s.state.word).foregroundStyle(.secondary)
                }
            }

            if !model.alerts.isEmpty {
                Divider()
                Text("Alerts").font(.subheadline).foregroundStyle(.secondary)
                ForEach(model.alerts, id: \.id) { a in
                    HStack {
                        Text("\(a.kind.word): \(a.label)")
                        Text(a.detail).foregroundStyle(.secondary)
                        Spacer()
                        Button("Dismiss") { model.acknowledge(a.id) }.buttonStyle(.link)
                    }
                }
            }

            Divider()
            Button("Watch settings…") { model.showSettings?() }
            .buttonStyle(.link)
            Button("Set up terminal alerts…") {
                model.copyShellSetup()
                showShellHelp = true
            }
            .buttonStyle(.link)
            if showShellHelp {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copied. Add this line to ~/.zshrc, then open a new terminal:").font(.caption)
                    Text(AppModel.shellLine).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Text("Commands that run 30 s or longer will alert the watch. Change it with GARMINY_LONG_CMD_SECS.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Picker("Buzz on Claude alerts", selection: $model.buzzMode) {
                ForEach(BuzzMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle("Keep Mac awake while work runs", isOn: $model.keepAwakeEnabled)
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            HStack {
                Spacer()
                Button("Quit garminy") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { model.refreshBluetoothNote() }
    }
}
