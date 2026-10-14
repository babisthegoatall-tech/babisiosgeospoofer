import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct MapKitPicker: UIViewRepresentable {
    var selectedCoordinate: CLLocationCoordinate2D
    var focusVersion: Int
    var favorites: [Place]
    var route: [Place]
    var onSelect: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .excludingAll
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tap)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSelect = onSelect
        if let selected = context.coordinator.selectedAnnotation {
            selected.coordinate = selectedCoordinate
        } else {
            let selected = MKPointAnnotation()
            selected.coordinate = selectedCoordinate
            selected.title = "In-app simulated location"
            context.coordinator.selectedAnnotation = selected
            mapView.addAnnotation(selected)
        }

        if context.coordinator.lastFavorites != favorites || context.coordinator.lastRoute != route {
            let staticAnnotations = mapView.annotations.filter {
                !($0 is MKUserLocation) && $0 !== context.coordinator.selectedAnnotation
            }
            mapView.removeAnnotations(staticAnnotations)
            for favorite in favorites {
                let annotation = MKPointAnnotation()
                annotation.coordinate = favorite.coordinate
                annotation.title = favorite.name
                mapView.addAnnotation(annotation)
            }
            for (index, waypoint) in route.enumerated() {
                let annotation = MKPointAnnotation()
                annotation.coordinate = waypoint.coordinate
                annotation.title = "Waypoint \(index + 1): \(waypoint.name)"
                mapView.addAnnotation(annotation)
            }
            mapView.removeOverlays(mapView.overlays)
            if route.count > 1 {
                let coordinates = route.map(\.coordinate)
                mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
            }
            context.coordinator.lastFavorites = favorites
            context.coordinator.lastRoute = route
        }

        if !context.coordinator.hasSetInitialRegion || context.coordinator.lastFocusVersion != focusVersion {
            mapView.setRegion(
                MKCoordinateRegion(
                    center: selectedCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ),
                animated: false
            )
            context.coordinator.hasSetInitialRegion = true
            context.coordinator.lastFocusVersion = focusVersion
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapView: MKMapView?
        var onSelect: (CLLocationCoordinate2D) -> Void
        var selectedAnnotation: MKPointAnnotation?
        var lastFavorites: [Place]?
        var lastRoute: [Place]?
        var hasSetInitialRegion = false
        var lastFocusVersion: Int?

        init(onSelect: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onSelect = onSelect
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView, recognizer.state == .ended else { return }
            let point = recognizer.location(in: mapView)
            onSelect(mapView.convert(point, toCoordinateFrom: mapView))
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "BabisHubPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = true
            return view
        }
    }
}
