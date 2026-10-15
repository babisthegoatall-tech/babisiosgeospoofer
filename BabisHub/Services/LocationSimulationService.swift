import Combine
import CoreLocation
import Foundation

@MainActor
protocol LocationSimulating: AnyObject {
    var coordinate: CLLocationCoordinate2D { get }
    var isRunning: Bool { get }
    var speedMetersPerSecond: Double { get set }

    func setCoordinate(_ coordinate: CLLocationCoordinate2D)
    func start(route: [Place])
    func stop()
}

@MainActor
final class CurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is disabled. Allow it in Settings to show your current position."
        @unknown default:
            errorMessage = "This device's location authorization status is not supported."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0 else { return }
        location = latest
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Could not get your current location: \(error.localizedDescription)"
    }
}

@MainActor
final class LocationSimulationService: ObservableObject, LocationSimulating {
    @Published private(set) var coordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    @Published private(set) var isRunning = false
    @Published var speedMetersPerSecond: Double = 5

    private var waypoints: [Place] = []
    private var destinationIndex = 1
    private var tickTask: Task<Void, Never>?

    func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        stop()
        self.coordinate = coordinate
    }

    func start(route: [Place]) {
        guard route.count >= 2 else { return }
        stop()
        waypoints = route
        coordinate = route[0].coordinate
        destinationIndex = 1
        isRunning = true
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { break }
                self?.advance(by: max(0, self?.speedMetersPerSecond ?? 0) * 0.25)
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
        waypoints = []
        destinationIndex = 1
    }

    private func advance(by distance: Double) {
        guard isRunning, distance > 0, destinationIndex < waypoints.count else { return }

        var remainingDistance = distance
        while remainingDistance > 0, destinationIndex < waypoints.count {
            let destination = waypoints[destinationIndex].coordinate
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            let segmentDistance = currentLocation.distance(from: destinationLocation)

            if segmentDistance <= remainingDistance || segmentDistance < 0.5 {
                coordinate = destination
                remainingDistance -= min(segmentDistance, remainingDistance)
                destinationIndex += 1
            } else {
                let fraction = remainingDistance / segmentDistance
                coordinate = CLLocationCoordinate2D(
                    latitude: coordinate.latitude + (destination.latitude - coordinate.latitude) * fraction,
                    longitude: coordinate.longitude + (destination.longitude - coordinate.longitude) * fraction
                )
                remainingDistance = 0
            }
        }

        if destinationIndex >= waypoints.count {
            stop()
        }
    }
}
