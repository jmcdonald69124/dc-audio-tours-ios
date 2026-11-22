import Foundation

/// Where a listener is in a tour, so the app can resume exactly where they left off.
public struct TourProgress: Codable, Equatable, Sendable {
    public let tourId: String
    public private(set) var completedStopIds: Set<String>
    public private(set) var lastStopId: String?
    /// Playback position inside `lastStopId`, in seconds.
    public private(set) var lastPosition: TimeInterval

    public init(tourId: String) {
        self.tourId = tourId; completedStopIds = []; lastStopId = nil; lastPosition = 0
    }

    public mutating func record(stopId: String, position: TimeInterval) {
        lastStopId = stopId
        lastPosition = max(0, position)
    }

    public mutating func complete(stopId: String) {
        completedStopIds.insert(stopId)
        if lastStopId == stopId { lastPosition = 0 }
    }

    /// 0…1 across the stops of `tour`.
    public func fraction(of tour: Tour) -> Double {
        guard !tour.stops.isEmpty else { return 0 }
        let done = tour.stops.filter { completedStopIds.contains($0.id) }.count
        return Double(done) / Double(tour.stops.count)
    }

    /// The first stop not yet completed (the stop to resume at).
    public func nextStop(in tour: Tour) -> Stop? {
        if let last = lastStopId, !completedStopIds.contains(last), let stop = tour.stops.first(where: { $0.id == last }) {
            return stop
        }
        return tour.stops.first { !completedStopIds.contains($0.id) }
    }
}
