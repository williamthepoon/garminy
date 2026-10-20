import GarminyCore
import SwiftUI

/// Every garminy watch setting, plus where the weather comes from. Changes go to the watch over Bluetooth.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var weather: WeatherService
    @ObservedObject var news: NewsService
    @State private var customURL = ""

    var body: some View {
        Form {
            Section("Weather for the watch") {
                Text("Uses this Mac's location.")
                Text(weather.status).font(.caption).foregroundStyle(.secondary)
                if weather.locationUndecided {
                    Button("Allow location") { weather.requestAccess() }
                }
                if weather.locationDenied {
                    Button("Open Location Services settings") { weather.openLocationSettings() }
                }
            }

            Section("News for the watch") {
                Picker("Feed", selection: Binding(get: { news.choice }, set: { news.choose($0) })) {
                    ForEach(News.presets, id: \.id) { Text($0.name).tag($0.id) }
                    Text("Custom RSS feed").tag("custom")
                }
                if news.choice == "custom" {
                    HStack {
                        TextField("https://…", text: $customURL)
                        Button("Use") { news.setCustomURL(customURL) }
                    }
                    if let e = news.customError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                }
                Text(news.status).font(.caption).foregroundStyle(.secondary)
            }
            .onAppear { customURL = news.customURL }

            Section("Cards") {
                ForEach(SettingsModel.cards.indices, id: \.self) { i in
                    Toggle(SettingsModel.cards[i].name, isOn: Binding(get: { model.settings.card(i) },
                                                                    set: { model.setCard(i, $0) }))
                }
            }

            Section("Watch") {
                Picker("Seconds per card", selection: Binding(get: { model.settings.value.interval },
                                                              set: { v in model.editSettings { $0.interval = v } })) {
                    ForEach(SettingsModel.intervals, id: \.self) { Text("\($0)").tag($0) }
                }
                ForEach(0..<3, id: \.self) { slot in
                    Picker("World clock city \(slot + 1)", selection: Binding(
                        get: { Int(model.settings.value.cities[slot]) },
                        set: { v in model.editSettings { $0.cities[slot] = Int8(v) } })) {
                        Text("None").tag(-1)
                        ForEach(SettingsModel.cities.indices, id: \.self) { Text(SettingsModel.cities[$0]).tag($0) }
                    }
                }
                Picker("Temperature units", selection: Binding(get: { model.settings.value.units },
                                                               set: { v in model.editSettings { $0.units = v } })) {
                    Text("Follow device").tag(UInt8(0)); Text("°C").tag(UInt8(1)); Text("°F").tag(UInt8(2))
                }
                Picker("Backlight", selection: Binding(get: { model.settings.value.backlight },
                                                       set: { v in model.editSettings { $0.backlight = v } })) {
                    Text("Off").tag(UInt8(0)); Text("Low").tag(UInt8(1)); Text("Medium").tag(UInt8(2)); Text("High").tag(UInt8(3))
                }
                Toggle("Quiet hours (backlight off)", isOn: Binding(get: { model.settings.value.quietHours },
                                                                    set: { v in model.editSettings { $0.quietHours = v } }))
                HStack {
                    Picker("From", selection: Binding(get: { model.settings.value.quietStart },
                                                      set: { v in model.editSettings { $0.quietStart = v } })) {
                        ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d:00", h)).tag(UInt8(h)) }
                    }
                    Picker("Until", selection: Binding(get: { model.settings.value.quietEnd },
                                                       set: { v in model.editSettings { $0.quietEnd = v } })) {
                        ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d:00", h)).tag(UInt8(h)) }
                    }
                }
                .disabled(!model.settings.value.quietHours)
                Picker("On the charger", selection: Binding(get: { model.settings.value.chargerSignal },
                                                            set: { v in model.editSettings { $0.chargerSignal = v } })) {
                    Text("Nothing").tag(UInt8(0)); Text("Beep").tag(UInt8(1)); Text("Light").tag(UInt8(2)); Text("Beep and light").tag(UInt8(3))
                }
                Picker("Beep sound", selection: Binding(get: { model.settings.value.beepSound },
                                                        set: { v in model.editSettings { $0.beepSound = v } })) {
                    Text("Soft").tag(UInt8(0)); Text("Chime").tag(UInt8(1)); Text("Standard").tag(UInt8(2))
                }
                HStack {
                    Text("The watch can't vibrate while charging. Beeps need the watch's Alert Tones on.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Test on watch") { model.testSignal() }.disabled(!model.watchConnected)
                }
                Toggle("Mac companion on the watch", isOn: Binding(get: { model.settings.value.companion },
                                                                  set: { v in model.editSettings { $0.companion = v } }))
            }

            Section("About") {
                Text("garminy Companion \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · MIT licence")
                Link("Weather data by Open-Meteo.com (CC BY 4.0)", destination: URL(string: "https://open-meteo.com/")!)
                Text("Changes reach the watch over Bluetooth the next time it connects.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 640)
    }
}
