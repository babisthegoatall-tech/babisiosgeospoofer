import CoreLocation
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: HubViewModel
    @ObservedObject var simulator: LocationSimulationService

    var body: some View {
        TabView {
            MapScreen(viewModel: viewModel, simulator: simulator)
                .tabItem { Label("Map", systemImage: "map") }
            LibraryScreen(viewModel: viewModel)
                .tabItem { Label("Library", systemImage: "bookmark") }
            SettingsScreen(viewModel: viewModel)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .alert("Babis Hub", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct MapScreen: View {
    @ObservedObject var viewModel: HubViewModel
    @ObservedObject var simulator: LocationSimulationService
    @State private var showingSearchResults = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                    selectedCoordinate: simulator.isRunning ? simulator.coordinate : viewModel.selectedCoordinate,
                    focusVersion: viewModel.mapFocusVersion,
                    favorites: viewModel.favorites,
                    route: viewModel.routes.first(where: { $0.name == viewModel.routeName })?.waypoints ?? [],
                    onSelect: { viewModel.selectCoordinate($0) }
                )
                .frame(minHeight: 250)

                Form {
                    Section(header: Text("Selected in-app location")) {
                        TextField("Location name", text: $viewModel.placeName)
                        HStack {
                            coordinateField("Latitude", text: $viewModel.latitudeInput)
                            coordinateField("Longitude", text: $viewModel.longitudeInput)
                        }
                        Button("Apply coordinates", action: viewModel.applyManualCoordinate)
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
                        Text("Babis Hub changes only the location shown inside this app. It cannot change iOS system GPS or another app's location.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Babis Hub")
            .navigationBarTitleDisplayMode(.inline)
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
}
