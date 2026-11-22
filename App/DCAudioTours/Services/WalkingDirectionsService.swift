import MapKit
import TourKit

/// A walking route between two points, computed on-device-assisted by Apple Maps (real
/// pedestrian paths, crossings, and live closures) — not the street-grid estimates in the catalog.
struct WalkingLeg {
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let steps: [String]
    let polyline: MKPolyline
}

@MainActor
final class WalkingDirectionsService {
    private var cache: [String: WalkingLeg] = [:]

    func route(from: Coordinate, to: Coordinate) async throws -> WalkingLeg {
        let key = "\(from.lat),\(from.lon)>\(to.lat),\(to.lon)"
        if let cached = cache[key] { return cached }

        let request = MKDirections.Request()
        request.source = Self.mapItem(from, name: nil)
        request.destination = Self.mapItem(to, name: nil)
        request.transportType = .walking

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else { throw URLError(.resourceUnavailable) }

        let leg = WalkingLeg(
            distance: route.distance,
            expectedTravelTime: route.expectedTravelTime,
            steps: route.steps.map(\.instructions).filter { !$0.isEmpty },
            polyline: route.polyline)
        cache[key] = leg
        return leg
    }

    /// Hands off to Apple Maps for live turn-by-turn from the listener's current position
    /// (Apple Watch haptics, lock-screen guidance, CarPlay).
    static func openInMaps(to: Coordinate, destinationName: String) {
        MKMapItem.openMaps(
            with: [mapItem(to, name: destinationName)],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private static func mapItem(_ coordinate: Coordinate, name: String?) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate.clLocation))
        item.name = name
        return item
    }
}
