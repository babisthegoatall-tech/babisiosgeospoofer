import CoreLocation
import Combine
import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var viewModel: HubViewModel
    @ObservedObject var simulator: LocationSimulationService
    @ObservedObject var locationProvider: CurrentLocationProvider
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapScreen(viewModel: viewModel, simulator: simulator, locationProvider: locationProvider)
                .tabItem { Label("Map", systemImage: "map") }
                .tag(0)
            LibraryScreen(viewModel: viewModel, onStartSimulation: { route in
                    viewModel.startSimulation(for: route)
                    if simulator.isRunning {
                        selectedTab = 0
                    }
                })
                .tabItem { Label("Plans", systemImage: "bookmark") }
                .tag(1)
            SettingsScreen(viewModel: viewModel)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(2)
        }
        .alert("Babis Hub", isPresented: Binding(
            get: { viewModel.errorMessage != nil || locationProvider.errorMessage != nil },
            set: {
                if !$0 {
                    viewModel.errorMessage = nil
                    locationProvider.clearError()
                }
            }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
                locationProvider.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? locationProvider.errorMessage ?? "")
        }
    }
}

private struct MapScreen: View {
    @ObservedObject var viewModel: HubViewModel
    @ObservedObject var simulator: LocationSimulationService
    @ObservedObject var locationProvider: CurrentLocationProvider
    @State private var showingSearchResults = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Your current position", systemImage: "location.fill")
                        .font(.headline)
                    if let coordinate = viewModel.currentDeviceCoordinate {
                        Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    } else {
                        Text("Allow location access to find you and center the map.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(
                            locationProvider.authorizationStatus == .denied
                                || locationProvider.authorizationStatus == .restricted
                                ? "Open iOS Settings"
                                : "Get my current position",
                            action: requestLocation
                        )
                        .font(.caption)
                    }
                    if viewModel.hasSimulatedLocation || simulator.isRunning {
                        Label("Simulated position in Babis Hub", systemImage: "location.north.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                        Text(String(format: "%.5f, %.5f", simulator.coordinate.latitude, simulator.coordinate.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Text("Where do you want to go? Tap a destination on the map, then tap Go.")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)

                HStack {
                    TextField("Search a place", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.search)
                        .onSubmit { search() }
                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search places")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if showingSearchResults && !viewModel.searchResults.isEmpty {
                    List(viewModel.searchResults) { place in
                        Button {
                            viewModel.placeName = place.name
                            viewModel.selectCoordinate(place.coordinate, name: place.name)
                            viewModel.mapFocusVersion += 1
                            showingSearchResults = false
                        } label: {
                            VStack(alignment: .leading) {
                                Text(place.name).foregroundColor(.primary)
                                Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                }

                MapKitPicker(
                    sourceCoordinate: viewModel.currentDeviceCoordinate,
                    destinationCoordinate: viewModel.hasChosenDestination && !viewModel.hasSimulatedLocation
                        ? viewModel.selectedCoordinate
                        : nil,
                    simulatedCoordinate: viewModel.hasSimulatedLocation || simulator.isRunning
                        ? simulator.coordinate
                        : nil,
                    focusVersion: viewModel.mapFocusVersion,
                    favorites: viewModel.favorites,
                    route: viewModel.routes.first(where: { $0.name == viewModel.routeName })?.waypoints ?? [],
                    onSelect: { viewModel.selectCoordinate($0) }
                )
                .frame(minHeight: 220)

                Form {
                    Section(header: Text("Destination")) {
                        TextField("Location name", text: $viewModel.placeName)
                        HStack {
                            coordinateField("Latitude", text: $viewModel.latitudeInput)
                            coordinateField("Longitude", text: $viewModel.longitudeInput)
                        }
                        Button("Apply coordinates", action: viewModel.applyManualCoordinate)
                        Button {
                            viewModel.goToDestination()
                        } label: {
                            Label("Go to destination", systemImage: "location.north.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.hasChosenDestination)
                        HStack {
                            Button("Save favorite", action: viewModel.addFavorite)
                            Spacer()
                            Button("Add route waypoint", action: viewModel.addSelectedWaypoint)
                        }
                    }

                    Section(header: Text("Route simulation")) {
                        TextField("Route name", text: $viewModel.routeName)
                        HStack {
                            Text("Speed")
                            Slider(value: $simulator.speedMetersPerSecond, in: 0.5...50, step: 0.5)
                            Text("\(simulator.speedMetersPerSecond, specifier: "%.1f") m/s")
                                .font(.caption).frame(width: 68)
                        }
                        HStack {
                            Button(simulator.isRunning ? "Stop" : "Start") {
                                if simulator.isRunning {
                                    simulator.stop()
                                } else {
                                    viewModel.startSimulation()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                            Text(simulator.isRunning ? "Simulating in this app" : "\(viewModel.currentRoute.count) waypoints")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Text("Go moves the simulated location only inside Babis Hub. It cannot change iOS system GPS or another app's location.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Babis Hub")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { locationProvider.requestLocationPermission() }
            .onReceive(locationProvider.$location.compactMap { $0 }) { location in
                viewModel.updateCurrentDeviceLocation(location.coordinate)
            }
        }
    }

    private func coordinateField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }

    private func search() {
        Task {
            await viewModel.searchPlaces()
            showingSearchResults = true
        }
    }

    private func requestLocation() {
        if locationProvider.authorizationStatus == .denied
            || locationProvider.authorizationStatus == .restricted {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        } else {
            locationProvider.requestLocationPermission()
        }
    }
}
