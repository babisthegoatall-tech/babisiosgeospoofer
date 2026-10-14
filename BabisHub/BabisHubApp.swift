import SwiftUI

@main
@MainActor
struct BabisHubApp: App {
    @StateObject private var simulator: LocationSimulationService
    @StateObject private var viewModel: HubViewModel

    init() {
        let simulator = LocationSimulationService()
        _simulator = StateObject(wrappedValue: simulator)
        _viewModel = StateObject(wrappedValue: HubViewModel(simulator: simulator))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, simulator: simulator)
                .preferredColorScheme(.light)
        }
    }
}
