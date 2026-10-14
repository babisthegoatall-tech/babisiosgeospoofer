import CoreLocation
import Foundation

struct Place: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D) {
        self.init(
            id: id,
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isValidCoordinate: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }
}

struct SavedRoute: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var waypoints: [Place]
}

struct HubSettings: Codable {
    var defaultSpeedMetersPerSecond: Double = 5
}
