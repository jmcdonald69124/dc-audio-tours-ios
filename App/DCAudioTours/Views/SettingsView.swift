import CoreLocation
import SwiftUI
import TourKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    Picker("Text and narration", selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                        ForEach(TourLanguage.allCases) { Text("\($0.flag)  \($0.nativeName)").tag($0) }
                    }
                }

                Section {
                    LabeledContent("Location") { Text(locationStatus) }
                    if model.location.authorization == .authorizedWhenInUse {
                        Button("Allow alerts while walking") { model.location.requestAlways() }
                    }
                    if model.location.authorization == .denied || model.location.authorization == .restricted {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                } header: {
                    Text("Arrival alerts")
                } footer: {
                    Text("With “Always” location, your phone tells you when you reach the next stop even with the screen off. Your location never leaves your device.")
                }

                Section("Playback") {
                    Picker("Speed", selection: Binding(get: { model.audio.rate }, set: { model.audio.setRate($0) })) {
                        ForEach(AudioPlayerService.rates, id: \.self) { Text(PlayerControls.label($0)).tag($0) }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    Link("Help & FAQ", destination: URL(string: "https://dcaudiotours.com/faq")!)
                }

                #if DEBUG
                Section("Developer") {
                    Toggle("Unlock all tours", isOn: Binding(get: { model.debugUnlockAll }, set: { model.debugUnlockAll = $0 }))
                }
                #endif
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .listRowBackground(Ed.surface)
            .background(Ed.bg.ignoresSafeArea())
            .tint(Ed.accent)
            .miniPlayerInset()
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    private var locationStatus: LocalizedStringKey {
        switch model.location.authorization {
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "While using the app"
        case .denied, .restricted: "Off"
        default: "Not set"
        }
    }
}
