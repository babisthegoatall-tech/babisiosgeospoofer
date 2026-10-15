import SwiftUI

@main
@MainActor
struct BabisHubApp: App {
    @StateObject private var simulator: LocationSimulationService
    @StateObject private var locationProvider: CurrentLocationProvider
    @StateObject private var viewModel: HubViewModel

    init() {
        let simulator = LocationSimulationService()
        let locationProvider = CurrentLocationProvider()
        _simulator = StateObject(wrappedValue: simulator)
        _locationProvider = StateObject(wrappedValue: locationProvider)
        _viewModel = StateObject(wrappedValue: HubViewModel(simulator: simulator))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, simulator: simulator, locationProvider: locationProvider)
                .preferredColorScheme(.light)
        }
    }
}
