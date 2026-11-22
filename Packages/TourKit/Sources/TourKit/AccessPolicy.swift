import Foundation

/// What a listener has bought. On iOS this is filled from StoreKit 2 and mirrored to
/// Firestore (`users/{uid}/entitlements`) so a purchase made on the web or on iOS unlocks both.
public struct Entitlements: Codable, Equatable, Sendable {
    public var tourIds: Set<String>
    /// The all-access pass: every tour, now and later.
    public var allAccess: Bool

    public init(tourIds: Set<String> = [], allAccess: Bool = false) {
        self.tourIds = tourIds; self.allAccess = allAccess
    }

    public static let none = Entitlements()
}

public enum StopAccess: Equatable, Sendable {
    /// First stop of any tour: always free.
    case freePreview
    /// The stop belongs to the free tour.
    case freeTour
    case owned
    case locked

    public var isUnlocked: Bool { self != .locked }
}

public enum TourAccess: Equatable, Sendable {
    case free
    case owned
    /// Locked apart from the free first stop.
    case preview
}

/// Decides which stops can be played. These rules mirror the server's `isAudioAllowed`
/// in the web repo (first stop of every tour free → free tour free → purchased), so the app
/// and the audio server never disagree about what a listener may hear.
public struct AccessPolicy: Sendable {
    private let previewStopIds: Set<String>
    private let toursByStop: [String: Set<String>]
    private let freeTourIds: Set<String>

    public init(catalog: Catalog) {
        var previews = Set<String>()
        var byStop = [String: Set<String>]()
        var free = Set<String>()
        for tour in catalog.tours {
            if tour.isFree || tour.id == catalog.freeTourId { free.insert(tour.id) }
            if let first = tour.stops.first { previews.insert(first.id) }
            for stop in tour.stops { byStop[stop.id, default: []].insert(tour.id) }
        }
        previewStopIds = previews; toursByStop = byStop; freeTourIds = free
    }

    public func access(toStopId stopId: String, entitlements: Entitlements) -> StopAccess {
        if previewStopIds.contains(stopId) { return .freePreview }
        let tours = toursByStop[stopId] ?? []
        if !tours.isDisjoint(with: freeTourIds) { return .freeTour }
        if entitlements.allAccess || !tours.isDisjoint(with: entitlements.tourIds) { return .owned }
        return .locked
    }

    public func access(to stop: Stop, entitlements: Entitlements) -> StopAccess {
        access(toStopId: stop.id, entitlements: entitlements)
    }

    public func access(to tour: Tour, entitlements: Entitlements) -> TourAccess {
        if tour.isFree || freeTourIds.contains(tour.id) { return .free }
        if entitlements.allAccess || entitlements.tourIds.contains(tour.id) { return .owned }
        // An area tour whose stops are all already unlocked through themed tours is effectively owned.
        if !tour.stops.isEmpty, tour.stops.allSatisfy({ access(to: $0, entitlements: entitlements).isUnlocked }) {
            return .owned
        }
        return .preview
    }
}
