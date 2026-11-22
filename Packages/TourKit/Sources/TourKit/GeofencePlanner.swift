import Foundation

public struct GeofenceRegion: Hashable, Sendable, Identifiable {
    /// The stop this region announces.
    public let id: String
    public let center: Coordinate
    public let radius: Double
}

/// iOS lets an app monitor only 20 regions at once, so the app asks this planner which
/// stops to watch next and re-plans every time the listener arrives somewhere.
///
/// Geofences are placed on **stops**, not sub-stops: sub-stops are rooms and exhibits inside a
/// building, where GPS is unreliable and the data carries no coordinates.
public enum GeofencePlanner {
    public static let systemLimit = 20
    /// Apple recommends radii of at least ~100 m for reliable region monitoring.
    public static let minimumRadius: Double = 100

    public enum Strategy: Sendable {
        /// Follow the tour in order, starting at `fromIndex` (themed tours and guided walks).
        case routeOrder(fromIndex: Int)
        /// Watch whatever is closest (free exploration).
        case nearest(to: Coordinate)
    }

    public static func plan(
        stops: [Stop], strategy: Strategy, maxRegions: Int = 18, radius: Double = 150
    ) -> [GeofenceRegion] {
        let limit = max(0, min(maxRegions, systemLimit))
        let r = max(radius, minimumRadius)
        let located: [(Stop, Coordinate)] = stops.compactMap { stop in
            stop.location.map { (stop, $0.coordinate) }
        }

        let chosen: [(Stop, Coordinate)]
        switch strategy {
        case .routeOrder(let fromIndex):
            chosen = located.filter { $0.0.order >= fromIndex }.sorted { $0.0.order < $1.0.order }
        case .nearest(let origin):
            chosen = located.sorted { origin.distance(to: $0.1) < origin.distance(to: $1.1) }
        }

        return chosen.prefix(limit).map { GeofenceRegion(id: $0.0.id, center: $0.1, radius: r) }
    }
}
