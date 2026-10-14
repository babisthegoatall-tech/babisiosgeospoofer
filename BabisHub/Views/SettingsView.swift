import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var viewModel: HubViewModel
    @State private var defaultSpeed = 5.0

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Simulation defaults")) {
                    HStack {
                        Text("Default speed")
                        Slider(
                            value: $defaultSpeed,
                            in: 0.5...50,
                            step: 0.5,
                            onEditingChanged: { editing in
                                if !editing { viewModel.updateSettings(defaultSpeed: defaultSpeed) }
                            }
                        )
                        Text("\(defaultSpeed, specifier: "%.1f") m/s")
                            .font(.caption).frame(width: 68)
                    }
                }
                Section(header: Text("Important limitations")) {
                    Text("Babis Hub is an internal QA/demo tool. Route playback and selected coordinates are simulated only inside Babis Hub.")
                    Text("iOS sandboxing prevents this app from changing system-wide GPS or another app's location. It does not alter Snapchat or any other third-party app.")
                    Text("Do not use this app to misrepresent real location to third-party services. Violating Apple Enterprise Program terms or Snapchat's Terms of Service may result in certificate revocation, account restrictions, or bans.")
                }
                Section(header: Text("Privacy")) {
                    Text("Babis Hub does not request device location permission. Favorites, routes, and settings are stored locally using UserDefaults.")
                }
            }
            .navigationTitle("Settings")
            .onAppear { defaultSpeed = viewModel.settings.defaultSpeedMetersPerSecond }
        }
    }
}
