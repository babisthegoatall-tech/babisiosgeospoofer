import CoreLocation
import Combine
import Foundation
import MapKit

@MainActor
final class HubViewModel: ObservableObject {
    @Published var favorites: [Place] = []
    @Published var routes: [SavedRoute] = []
    @Published var selectedCoordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    @Published var currentDeviceCoordinate: CLLocationCoordinate2D?
    @Published var latitudeInput = "37.3349"
    @Published var longitudeInput = "-122.0090"
    @Published var placeName = "Selected location"
    @Published var routeName = "Demo route"
    @Published var searchText = ""
    @Published var searchResults: [Place] = []
    @Published var mapFocusVersion = 0
    @Published var settings = HubSettings()
    @Published var errorMessage: String?
    @Published private(set) var hasChosenDestination = false
    @Published private(set) var hasSimulatedLocation = false

    let simulator: any LocationSimulating

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var activeSearch: MKLocalSearch?
    private var searchGeneration = 0
    private var hasReceivedInitialLocation = false

    init(defaults: UserDefaults = .standard, simulator: any LocationSimulating) {
        self.defaults = defaults
        self.simulator = simulator
        favorites = decode([Place].self, key: "favorites") ?? []
        routes = decode([SavedRoute].self, key: "routes") ?? []
        settings = decode(HubSettings.self, key: "settings") ?? HubSettings()
        let savedSpeed = settings.defaultSpeedMetersPerSecond
        settings.defaultSpeedMetersPerSecond = savedSpeed.isFinite ? min(max(savedSpeed, 0.5), 50) : 5
        simulator.speedMetersPerSecond = settings.defaultSpeedMetersPerSecond
    }

    var currentRoute: [Place] {
        routes.first(where: { $0.name == routeName })?.waypoints ?? []
    }

    func updateCurrentDeviceLocation(_ coordinate: CLLocationCoordinate2D) {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
              (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude) else { return }
        currentDeviceCoordinate = coordinate
        guard !hasChosenDestination, !simulator.isRunning else { return }
        selectedCoordinate = coordinate
        latitudeInput = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), coordinate.latitude)
        longitudeInput = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), coordinate.longitude)
        placeName = "Current location"
        simulator.setCoordinate(coordinate)
        if !hasReceivedInitialLocation {
            mapFocusVersion += 1
            hasReceivedInitialLocation = true
        }
    }

    func selectCoordinate(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
              (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude) else { return }
        selectedCoordinate = coordinate
        hasChosenDestination = true
        hasSimulatedLocation = false
        latitudeInput = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), coordinate.latitude)
        longitudeInput = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), coordinate.longitude)
        if let name { placeName = name }
    }

    func goToDestination() {
        guard hasChosenDestination,
              selectedCoordinate.latitude.isFinite, selectedCoordinate.longitude.isFinite,
              (-90...90).contains(selectedCoordinate.latitude),
              (-180...180).contains(selectedCoordinate.longitude) else {
            errorMessage = "Choose a destination on the map or enter coordinates before tapping Go."
            return
        }
        simulator.setCoordinate(selectedCoordinate)
        hasSimulatedLocation = true
        mapFocusVersion += 1
    }

    func applyManualCoordinate() {
        guard let latitude = Double(latitudeInput.trimmingCharacters(in: .whitespacesAndNewlines)),
              let longitude = Double(longitudeInput.trimmingCharacters(in: .whitespacesAndNewlines)),
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            errorMessage = "Enter a valid latitude (-90 to 90) and longitude (-180 to 180)."
            return
        }
        selectCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        mapFocusVersion += 1
    }

    func addFavorite() {
        let place = Place(name: placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Saved location" : placeName,
                          coordinate: selectedCoordinate)
        favorites.append(place)
        persist(favorites, key: "favorites")
    }

    func addSelectedWaypoint() {
        guard selectedCoordinate.latitude.isFinite, selectedCoordinate.longitude.isFinite else { return }
        let waypoint = Place(name: placeName, coordinate: selectedCoordinate)
        if let existingIndex = routes.firstIndex(where: { $0.name == routeName }) {
            routes[existingIndex].waypoints.append(waypoint)
        } else {
            routes.insert(SavedRoute(name: routeName, waypoints: [waypoint]), at: 0)
        }
        persist(routes, key: "routes")
    }

    func saveCurrentRoute() {
        guard let route = routes.first(where: { $0.name == routeName }), route.waypoints.count >= 2 else {
            errorMessage = "Add at least two waypoints before starting or saving a route."
            return
        }
        persist(routes, key: "routes")
    }

    func startSimulation(for route: SavedRoute? = nil) {
        let routeToRun = route ?? routes.first(where: { $0.name == routeName })
        guard let routeToRun, routeToRun.waypoints.count >= 2 else {
            errorMessage = "Add at least two waypoints before starting a route."
            return
        }
        if let firstWaypoint = routeToRun.waypoints.first {
            routeName = routeToRun.name
            selectedCoordinate = firstWaypoint.coordinate
            placeName = firstWaypoint.name
            hasChosenDestination = true
            hasSimulatedLocation = true
        }
        simulator.speedMetersPerSecond = min(max(simulator.speedMetersPerSecond, 0.5), 50)
        simulator.start(route: routeToRun.waypoints)
        mapFocusVersion += 1
    }

    func deleteFavorite(_ favorite: Place) {
        favorites.removeAll { $0.id == favorite.id }
        persist(favorites, key: "favorites")
    }

    func deleteRoute(_ route: SavedRoute) {
        routes.removeAll { $0.id == route.id }
        persist(routes, key: "routes")
    }

    func selectFavorite(_ favorite: Place) {
        placeName = favorite.name
        selectCoordinate(favorite.coordinate, name: favorite.name)
        mapFocusVersion += 1
    }

    func selectRoute(_ route: SavedRoute) {
        guard let first = route.waypoints.first else { return }
        routeName = route.name
        selectCoordinate(first.coordinate, name: first.name)
        mapFocusVersion += 1
    }

    func importRoute(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let route = try GPXParser.parse(Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent)
            routes.insert(route, at: 0)
            persist(routes, key: "routes")
            routeName = route.name
        } catch {
            errorMessage = "Could not import GPX: \(error.localizedDescription)"
        }
    }

    func searchPlaces() async {
        searchGeneration += 1
        let generation = searchGeneration
        activeSearch?.cancel()
        activeSearch = nil
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchResults = []
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        activeSearch = search
        do {
            let response: MKLocalSearch.Response = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<MKLocalSearch.Response, Error>) in
                search.start { response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let response {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    }
                }
            }
            guard generation == searchGeneration else { return }
            activeSearch = nil
            searchResults = response.mapItems.prefix(10).map { item in
                Place(
                    name: item.name ?? item.placemark.title ?? "Search result",
                    coordinate: item.placemark.coordinate
                )
            }
        } catch {
            guard generation == searchGeneration else { return }
            activeSearch = nil
            errorMessage = "Place search failed: \(error.localizedDescription)"
        }
    }

    func updateSettings(defaultSpeed: Double) {
        let speed = defaultSpeed.isFinite ? min(max(defaultSpeed, 0.5), 50) : 5
        settings.defaultSpeedMetersPerSecond = speed
        simulator.speedMetersPerSecond = speed
        persist(settings, key: "settings")
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            defaults.set(try encoder.encode(value), forKey: key)
        } catch {
            errorMessage = "Could not save app data: \(error.localizedDescription)"
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            errorMessage = "Could not load saved app data: \(error.localizedDescription)"
            return nil
        }
    }
}
