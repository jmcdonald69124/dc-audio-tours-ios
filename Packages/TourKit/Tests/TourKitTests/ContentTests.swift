import Foundation
import Testing
@testable import TourKit

/// These tests decode the real content bundled into the app, so they double as data-quality checks:
/// a bad geocode, a missing translation or a broken route leg fails here, not on someone's phone.
private enum Bundled {
    static let contentDir: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }   // → repository root
        return url.appendingPathComponent("App/DCAudioTours/Resources/Content")
    }()

    static let catalog: Catalog = {
        // swiftlint:disable:next force_try
        try! Catalog.decode(from: Data(contentsOf: contentDir.appendingPathComponent("catalog.json")))
    }()

    static func content(_ language: TourLanguage) throws -> LanguageContent {
        try LanguageContent.decode(from: Data(contentsOf: contentDir.appendingPathComponent("content/\(language.rawValue).json")))
    }
}

@Suite("Bundled catalog")
struct CatalogTests {
    let catalog = Bundled.catalog

    @Test func hasBothKindsOfTours() {
        #expect(catalog.themedTours.count >= 10)
        #expect(catalog.areaTours.count >= 5)
        #expect(catalog.languages.sorted() == TourLanguage.allCases.map(\.rawValue).sorted())
    }

    @Test func tourAndStopIdsAreUniqueWhereRequired() {
        #expect(Set(catalog.tours.map(\.id)).count == catalog.tours.count)
        for tour in catalog.tours {
            #expect(Set(tour.stops.map(\.id)).count == tour.stops.count, "duplicate stop id in \(tour.id)")
            #expect(tour.stops.map(\.order) == Array(0..<tour.stops.count), "stop order not 0…n in \(tour.id)")
        }
    }

    @Test func everyStopHasACoordinateInsideTheDCArea() {
        var bad: [String] = []
        for tour in catalog.tours {
            for stop in tour.stops {
                guard let loc = stop.location else { bad.append("\(tour.id)/\(stop.id): no coordinate"); continue }
                // Generous Washington, DC metro bounding box; catches geocodes that landed in another city.
                if !(38.70...39.10).contains(loc.lat) || !(-77.30 ... -76.80).contains(loc.lon) {
                    bad.append("\(tour.id)/\(stop.id): \(loc.lat),\(loc.lon)")
                }
            }
        }
        #expect(bad.isEmpty, "suspicious coordinates: \(bad)")
    }

    /// Stops whose coordinate is known to disagree with the tour text. Each needs a content decision, not a code fix.
    /// The test below fails when an entry is fixed, so the list cannot go stale.
    private static let knownDistanceProblems: Set<String> = [
        // Tour describes the Adams Morgan café (12 min from Woodley Park); the geocode found "Songbyrd Music House,
        // 540 Penn St NE", ~5.5 km away. Either the tour text is out of date or the coordinate is wrong.
        "music-lovers/songbyrd",
    ]

    @Test func everyStopIsWithinWalkingRangeOfItsStation() {
        // Catches a wrong station name or a geocode that landed far from where the tour says to get off.
        var far = Set<String>()
        var details: [String] = []
        for tour in catalog.tours {
            for stop in tour.stops {
                guard let station = stop.stationLocation, let loc = stop.location else { details.append("\(tour.id)/\(stop.id): missing"); continue }
                // Some stops are explicitly reached by rideshare, so a long distance is expected.
                if stop.exit.localizedCaseInsensitiveContains("rideshare") { continue }
                let meters = station.distance(to: loc.coordinate)
                if meters > 3_500 { far.insert("\(tour.id)/\(stop.id)"); details.append("\(tour.id)/\(stop.id) \(stop.station): \(Int(meters)) m (says \(stop.walkMin) min)") }
            }
        }
        let unexpected = far.subtracting(Self.knownDistanceProblems)
        #expect(unexpected.isEmpty, "stops far from their station: \(details)")
        let fixed = Self.knownDistanceProblems.subtracting(far)
        #expect(fixed.isEmpty, "now fine — remove from knownDistanceProblems: \(fixed)")
    }

    @Test func areaTourLegsConnectConsecutiveStops() throws {
        for tour in catalog.areaTours {
            let route = try #require(tour.route, "\(tour.id) has no route")
            #expect(route.legs.count == tour.stops.count - 1, "\(tour.id): legs ≠ stops−1")
            for (i, leg) in route.legs.enumerated() {
                #expect(leg.from == tour.stops[i].id && leg.to == tour.stops[i + 1].id, "\(tour.id) leg \(i) endpoints")
            }
            #expect(route.legs.reduce(0) { $0 + $1.meters } == route.totalMeters, "\(tour.id) total meters")
        }
    }

    @Test func legDistancesAreNeverShorterThanTheStraightLine() {
        // A walking route cannot be shorter than the great-circle distance (5 % slack for geocode rounding).
        var short: [String] = []
        for tour in catalog.areaTours {
            for leg in tour.route?.legs ?? [] {
                guard let a = tour.stops.first(where: { $0.id == leg.from })?.location,
                      let b = tour.stops.first(where: { $0.id == leg.to })?.location else { continue }
                let straight = a.coordinate.distance(to: b.coordinate)
                if Double(leg.meters) < straight * 0.95 { short.append("\(tour.id) \(leg.from)→\(leg.to): \(leg.meters) m < \(Int(straight)) m") }
            }
        }
        #expect(short.isEmpty, "legs shorter than straight line: \(short)")
    }

    @Test func everyStopHasAudioKeysAndAName() {
        for tour in catalog.tours {
            #expect(!tour.title[.en].isEmpty, "\(tour.id) title")
            for stop in tour.stops {
                #expect(!stop.audioKeys.isEmpty, "\(tour.id)/\(stop.id) audio keys")
                for lang in TourLanguage.allCases { #expect(!stop.name[lang].isEmpty, "\(stop.id) name \(lang)") }
            }
        }
    }
}

@Suite("Bundled content")
struct ContentCompletenessTests {
    @Test(arguments: TourLanguage.allCases)
    func everyStopHasNarrationInEveryLanguage(language: TourLanguage) throws {
        let content = try Bundled.content(language)
        var missing: [String] = []
        for tour in Bundled.catalog.tours {
            for stop in tour.stops {
                guard let c = content.content(for: stop), !c.narration.isEmpty else { missing.append("\(tour.id)/\(stop.id)"); continue }
                // The sub-stop list in the catalog and in the content must agree.
                if c.subStops.map(\.id) != stop.subStops.map(\.id) { missing.append("\(tour.id)/\(stop.id): sub-stop mismatch") }
            }
        }
        #expect(missing.isEmpty, "\(language): \(missing.prefix(10))")
    }
}

@Suite("Access policy on real data")
struct AccessPolicyTests {
    let catalog = Bundled.catalog
    var policy: AccessPolicy { AccessPolicy(catalog: catalog) }

    @Test func firstStopOfEveryTourIsAFreePreview() {
        for tour in catalog.tours {
            let first = try! #require(tour.stops.first)
            #expect(policy.access(to: first, entitlements: .none).isUnlocked, "\(tour.id) first stop locked")
        }
    }

    @Test func theFreeTourIsFullyUnlocked() throws {
        let free = try #require(catalog.tour(id: catalog.freeTourId))
        #expect(policy.access(to: free, entitlements: .none) == .free)
        for stop in free.stops { #expect(policy.access(to: stop, entitlements: .none).isUnlocked) }
    }

    @Test func aPaidTourStaysLockedUntilPurchased() throws {
        let paid = try #require(catalog.themedTours.first { !$0.isFree && $0.id != catalog.freeTourId })
        let later = try #require(paid.stops.dropFirst().first { stop in
            // a stop that is not shared with the free tour and not a preview stop elsewhere
            policy.access(to: stop, entitlements: .none) == .locked
        })
        #expect(policy.access(to: paid, entitlements: .none) == .preview)
        #expect(policy.access(to: later, entitlements: .none) == .locked)
        #expect(policy.access(to: later, entitlements: Entitlements(tourIds: [paid.id])) == .owned)
        #expect(policy.access(to: paid, entitlements: Entitlements(tourIds: [paid.id])) == .owned)
    }

    @Test func allAccessUnlocksEverything() {
        let all = Entitlements(allAccess: true)
        for tour in catalog.tours {
            #expect(policy.access(to: tour, entitlements: all) != .preview)
            for stop in tour.stops { #expect(policy.access(to: stop, entitlements: all).isUnlocked) }
        }
    }

    @Test func buyingAThemedTourUnlocksItsStopsInAreaWalks() throws {
        // Stops are shared between tours; owning one tour must unlock the stop wherever it appears.
        for area in catalog.areaTours {
            for stop in area.stops {
                let owners = catalog.toursContaining(stopId: stop.id).filter { $0.kind == .themed && !$0.isFree }
                guard let owner = owners.first,
                      policy.access(to: stop, entitlements: .none) == .locked else { continue }
                #expect(policy.access(to: stop, entitlements: Entitlements(tourIds: [owner.id])) == .owned)
            }
        }
    }
}

@Suite("Planner on real tours")
struct RealGeofenceTests {
    @Test func plansRegionsForEveryTour() {
        for tour in Bundled.catalog.tours {
            let regions = GeofencePlanner.plan(stops: tour.stops, strategy: .routeOrder(fromIndex: 0))
            #expect(!regions.isEmpty, "\(tour.id)")
            #expect(regions.count <= GeofencePlanner.systemLimit)
        }
    }
}
