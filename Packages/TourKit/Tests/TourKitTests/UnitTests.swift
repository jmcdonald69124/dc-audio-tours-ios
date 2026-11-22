import Foundation
import Testing
@testable import TourKit

@Suite("Language")
struct LanguageTests {
    @Test func resolvesRegionalTagsToSupportedLanguages() {
        #expect(TourLanguage.resolve(preferred: ["zh-Hans-CN"]) == .zh)
        #expect(TourLanguage.resolve(preferred: ["pt_BR"]) == .pt)
        #expect(TourLanguage.resolve(preferred: ["fr-CA", "en-US"]) == .fr)
    }

    @Test func skipsUnsupportedAndFallsBackToEnglish() {
        #expect(TourLanguage.resolve(preferred: ["it-IT", "ja-JP"]) == .ja)
        #expect(TourLanguage.resolve(preferred: ["it-IT"]) == .en)
        #expect(TourLanguage.resolve(preferred: []) == .en)
    }

    @Test func localizedTextFallsBackToEnglishThenAnything() {
        let t = LocalizedText(["en": "Hello", "es": "Hola", "ja": ""])
        #expect(t[.es] == "Hola")
        #expect(t[.ja] == "Hello")      // empty string counts as missing
        #expect(t[.de] == "Hello")
        #expect(LocalizedText(["fr": "Salut"])[.de] == "Salut")
        #expect(LocalizedText([:])[.en] == "")
    }

    @Test func localizedTextRoundTripsAsPlainObject() throws {
        let data = try JSONEncoder().encode(LocalizedText(["en": "A", "es": "B"]))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object == ["en": "A", "es": "B"])
        #expect(try JSONDecoder().decode(LocalizedText.self, from: data)[.es] == "B")
    }
}

@Suite("Geo")
struct GeoTests {
    @Test func haversineDistanceIsPlausible() {
        let lincoln = Coordinate(lat: 38.8893, lon: -77.0502)
        let washington = Coordinate(lat: 38.8895, lon: -77.0353)
        let meters = lincoln.distance(to: washington)
        #expect(meters > 1_200 && meters < 1_400)
        #expect(lincoln.distance(to: lincoln) == 0)
        #expect(abs(lincoln.distance(to: washington) - washington.distance(to: lincoln)) < 0.001)
    }

    @Test func bearingPointsTheRightWay() {
        let origin = Coordinate(lat: 38.9, lon: -77.0)
        #expect(abs(origin.bearing(to: Coordinate(lat: 39.0, lon: -77.0)) - 0) < 0.5)      // north
        #expect(abs(origin.bearing(to: Coordinate(lat: 38.8, lon: -77.0)) - 180) < 0.5)    // south
        let east = origin.bearing(to: Coordinate(lat: 38.9, lon: -76.9))
        #expect(east > 85 && east < 95)
    }

    @Test func geohashMatchesPublishedTestVectors() {
        // Standard vectors from the geohash reference implementation.
        #expect(Coordinate(lat: 57.64911, lon: 10.40744).geohash(precision: 11) == "u4pruydqqvj")
        #expect(Coordinate(lat: 42.605, lon: -5.603).geohash(precision: 5) == "ezs42")
    }

    @Test func boundsCoverAllPoints() throws {
        let box = try #require([Coordinate(lat: 1, lon: 5), Coordinate(lat: 3, lon: 2), Coordinate(lat: 2, lon: 9)].bounds)
        #expect(box.southWest == Coordinate(lat: 1, lon: 2))
        #expect(box.northEast == Coordinate(lat: 3, lon: 9))
        #expect([Coordinate]().bounds == nil)
    }
}

@Suite("Audio files")
struct AudioFileTests {
    private func stop(_ id: String, keys: [String]? = nil) -> Stop {
        Stop(id: id, order: 0, contentKey: "t/\(id)", station: "S", name: LocalizedText(["en": id]), audioKeys: keys)
    }

    @Test func stopFilesFollowPreferenceOrder() {
        let s = stop("natural-history", keys: ["museums-monuments-natural-history", "natural-history"])
        #expect(AudioFiles.stopFiles(for: s, language: .es) == [
            "museums-monuments-natural-history-es.mp3", "natural-history-es.mp3",
        ])
    }

    @Test func subStopNamesMatchTheWebClient() {
        #expect(AudioFiles.subStopNarration(stopId: "american-history", subStopId: "flag", language: .ja)
                == "american-history-sub-flag-ja.mp3")
        #expect(AudioFiles.subStopDirections(stopId: "american-history", subStopId: "flag", language: .ja)
                == "american-history-sub-flag-directions-ja.mp3")
    }

    @Test func urlsAddTokenOnlyWhenPresent() throws {
        let base = try #require(URL(string: "https://dcaudiotours.com"))
        #expect(AudioFiles.url(base: base, file: "a-en.mp3").absoluteString == "https://dcaudiotours.com/audio/a-en.mp3")
        #expect(AudioFiles.url(base: base, file: "a-en.mp3", token: "").absoluteString == "https://dcaudiotours.com/audio/a-en.mp3")
        #expect(AudioFiles.url(base: base, file: "a-en.mp3", token: "abc.def").absoluteString
                == "https://dcaudiotours.com/audio/a-en.mp3?t=abc.def")
    }
}

@Suite("Progress")
struct ProgressTests {
    private func tour() -> Tour {
        let stops = (0..<4).map {
            Stop(id: "s\($0)", order: $0, contentKey: "t/s\($0)", station: "S", name: LocalizedText(["en": "s\($0)"]))
        }
        return Tour(id: "t", title: LocalizedText(["en": "T"]), stops: stops)
    }

    @Test func resumesAtLastUnfinishedStop() {
        var p = TourProgress(tourId: "t")
        #expect(p.nextStop(in: tour())?.id == "s0")
        p.complete(stopId: "s0")
        p.record(stopId: "s1", position: 42)
        #expect(p.nextStop(in: tour())?.id == "s1")
        #expect(p.lastPosition == 42)
        p.complete(stopId: "s1")
        #expect(p.lastPosition == 0)
        #expect(p.nextStop(in: tour())?.id == "s2")
        #expect(p.fraction(of: tour()) == 0.5)
    }

    @Test func finishedTourHasNoNextStop() {
        var p = TourProgress(tourId: "t")
        for s in tour().stops { p.complete(stopId: s.id) }
        #expect(p.nextStop(in: tour()) == nil)
        #expect(p.fraction(of: tour()) == 1)
    }
}

@Suite("Geofence planner")
struct GeofencePlannerTests {
    private func stops(_ n: Int) -> [Stop] {
        (0..<n).map { i in
            Stop(id: "s\(i)", order: i, contentKey: "t/s\(i)", station: "S", name: LocalizedText(["en": "s\(i)"]),
                 location: StopLocation(lat: 38.9 + Double(i) * 0.001, lon: -77.0))
        }
    }

    @Test func neverExceedsTheSystemLimit() {
        let regions = GeofencePlanner.plan(stops: stops(60), strategy: .routeOrder(fromIndex: 0), maxRegions: 100)
        #expect(regions.count == GeofencePlanner.systemLimit)
    }

    @Test func routeOrderWatchesUpcomingStopsOnly() {
        let regions = GeofencePlanner.plan(stops: stops(30), strategy: .routeOrder(fromIndex: 10), maxRegions: 5)
        #expect(regions.map(\.id) == ["s10", "s11", "s12", "s13", "s14"])
    }

    @Test func nearestWatchesTheClosestStops() {
        let here = Coordinate(lat: 38.9 + 0.0205, lon: -77.0)
        let regions = GeofencePlanner.plan(stops: stops(30), strategy: .nearest(to: here), maxRegions: 3)
        #expect(Set(regions.map(\.id)) == ["s20", "s21", "s19"])
        #expect(regions.first?.id == "s20")
    }

    @Test func clampsRadiusToReliableMinimum() {
        let regions = GeofencePlanner.plan(stops: stops(3), strategy: .routeOrder(fromIndex: 0), radius: 20)
        #expect(regions.allSatisfy { $0.radius >= GeofencePlanner.minimumRadius })
    }

    @Test func skipsStopsWithoutCoordinates() {
        var list = stops(3)
        list.append(Stop(id: "nowhere", order: 3, contentKey: "t/nowhere", station: "S", name: LocalizedText(["en": "x"])))
        let regions = GeofencePlanner.plan(stops: list, strategy: .routeOrder(fromIndex: 0))
        #expect(!regions.map(\.id).contains("nowhere"))
    }
}
