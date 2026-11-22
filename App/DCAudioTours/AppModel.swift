import CoreSpotlight
import Foundation
import Observation
import SwiftUI
import TourKit
import UniformTypeIdentifiers
import UserNotifications

enum AppTab: Hashable { case tours, nearby, settings }

struct TourRoute: Hashable { let id: String }
struct StopRoute: Hashable { let tourId: String; let stopId: String }

/// Single source of truth for the UI. Services (audio, location, directions) are owned here so
/// that views stay declarative and the lock screen, notifications and App Intents can all drive
/// the same state.
@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    // MARK: Content
    private(set) var catalog: Catalog?
    private(set) var content: LanguageContent?
    private(set) var policy: AccessPolicy?
    private(set) var loadError: String?
    private(set) var language: TourLanguage

    // MARK: Purchases
    /// Phase 1 keeps this local. Phase 2 fills it from StoreKit 2 and Firestore (docs/backend-requirements.md).
    var entitlements: Entitlements = .none
    #if DEBUG
    /// Developer switch (Settings ▸ Developer) to test paid content without buying it.
    var debugUnlockAll = false
    #endif

    // MARK: Navigation
    var selectedTab: AppTab = .tours
    var toursPath = NavigationPath()
    var showFullPlayer = false

    // MARK: Progress
    private(set) var progress: [String: TourProgress] = [:]
    private(set) var activeTourId: String?
    private var pendingResume = false

    // MARK: Services
    let audio = AudioPlayerService()
    let location = LocationService()
    let walking = WalkingDirectionsService()
    private let notificationDelegate = NotificationCenterDelegate()
    let audioBaseURL: URL

    private enum Keys {
        static let language = "language"
        static let progress = "progress.v1"
        static let activeTour = "activeTour"
    }

    private init() {
        let defaults = UserDefaults.standard
        language = defaults.string(forKey: Keys.language).flatMap(TourLanguage.init(rawValue:)) ?? TourLanguage.resolve()
        let configured = Bundle.main.object(forInfoDictionaryKey: "AudioBaseURL") as? String
        audioBaseURL = URL(string: configured ?? "https://dcaudiotours.com") ?? URL(string: "https://dcaudiotours.com")!
        activeTourId = defaults.string(forKey: Keys.activeTour)
        if let data = defaults.data(forKey: Keys.progress),
           let saved = try? JSONDecoder().decode([String: TourProgress].self, from: data) {
            progress = saved
        }
    }

    // MARK: Startup

    func start() async {
        guard catalog == nil else { return }
        do {
            let loaded = try await Task.detached(priority: .userInitiated) { try BundledContent.catalog() }.value
            catalog = loaded
            policy = AccessPolicy(catalog: loaded)
        } catch {
            loadError = error.localizedDescription
            return
        }
        await loadContent()

        location.onArrival = { [weak self] stopId in self?.handleArrival(stopId: stopId) }
        audio.onFinished = { [weak self] in self?.handlePlaybackFinished() }
        audio.onNextTrack = { [weak self] in self?.openAdjacentStop(offset: +1) }
        audio.onPreviousTrack = { [weak self] in self?.openAdjacentStop(offset: -1) }

        notificationDelegate.onOpenStop = { [weak self] tourId, stopId in self?.open(tourId: tourId, stopId: stopId) }
        // The center keeps only a weak reference; AppModel.shared lives for the process lifetime.
        UNUserNotificationCenter.current().delegate = notificationDelegate

        if let catalog { SpotlightIndexer.index(catalog.tours, language: language) }
        if pendingResume { pendingResume = false; resumeTour() }
    }

    private func loadContent() async {
        let lang = language
        do {
            content = try await Task.detached(priority: .userInitiated) { try BundledContent.content(for: lang) }.value
        } catch {
            loadError = error.localizedDescription
        }
    }

    func setLanguage(_ new: TourLanguage) {
        guard new != language else { return }
        language = new
        UserDefaults.standard.set(new.rawValue, forKey: Keys.language)
        Task {
            await loadContent()
            if let catalog { SpotlightIndexer.index(catalog.tours, language: new) }
        }
    }

    // MARK: Lookups

    func tour(id: String) -> Tour? { catalog?.tour(id: id) }

    func resolve(_ route: StopRoute) -> (tour: Tour, stop: Stop)? {
        guard let tour = tour(id: route.tourId), let stop = tour.stops.first(where: { $0.id == route.stopId }) else { return nil }
        return (tour, stop)
    }

    func text(for stop: Stop) -> StopContent? { content?.content(for: stop) }

    func access(to stop: Stop) -> StopAccess { policy?.access(to: stop, entitlements: effectiveEntitlements) ?? .locked }
    func access(to tour: Tour) -> TourAccess { policy?.access(to: tour, entitlements: effectiveEntitlements) ?? .preview }

    private var effectiveEntitlements: Entitlements {
        #if DEBUG
        if debugUnlockAll { return Entitlements(allAccess: true) }
        #endif
        return entitlements
    }

    // MARK: Playback

    func audioURLs(for stop: Stop) -> [URL] {
        AudioFiles.stopFiles(for: stop, language: language).map { AudioFiles.url(base: audioBaseURL, file: $0) }
    }

    func play(_ stop: Stop, in tour: Tour) {
        guard access(to: stop).isUnlocked else { return }
        Haptics.tap()
        setActive(tour)
        let key = "\(tour.id)/\(stop.id)"
        let resumeAt = progress[tour.id]?.lastStopId == stop.id ? (progress[tour.id]?.lastPosition ?? 0) : 0
        audio.play(
            NowPlaying(id: key, title: stop.name[language], subtitle: tour.title[language], urls: audioURLs(for: stop)),
            startAt: resumeAt)
        var p = progress[tour.id] ?? TourProgress(tourId: tour.id)
        p.record(stopId: stop.id, position: resumeAt)
        progress[tour.id] = p
        persistProgress()
    }

    func playSubStop(file: String, title: String, parent stop: Stop, in tour: Tour) {
        guard access(to: stop).isUnlocked else { return }
        Haptics.tap()
        let url = AudioFiles.url(base: audioBaseURL, file: file)
        audio.play(NowPlaying(id: "\(tour.id)/\(stop.id)/\(file)", title: title, subtitle: stop.name[language], urls: [url]))
    }

    /// The stop currently loaded in the player, if it belongs to a tour stop (not a sub-stop clip).
    var nowPlayingRoute: StopRoute? {
        guard let id = audio.nowPlaying?.id else { return nil }
        let parts = id.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        return StopRoute(tourId: parts[0], stopId: parts[1])
    }

    func savePlaybackPosition() {
        guard let route = nowPlayingRoute, var p = progress[route.tourId] else { return }
        p.record(stopId: route.stopId, position: audio.position)
        progress[route.tourId] = p
        persistProgress()
    }

    private func handlePlaybackFinished() {
        guard let route = nowPlayingRoute else { return }
        var p = progress[route.tourId] ?? TourProgress(tourId: route.tourId)
        p.complete(stopId: route.stopId)
        progress[route.tourId] = p
        persistProgress()
        Haptics.arrival()
        replanGeofences()
    }

    // MARK: Tours in progress

    private func setActive(_ tour: Tour) {
        activeTourId = tour.id
        UserDefaults.standard.set(tour.id, forKey: Keys.activeTour)
    }

    func startTour(_ tour: Tour) {
        setActive(tour)
        location.requestWhenInUse()
        Task { await ArrivalNotifications.requestAuthorization() }
        replanGeofences()
    }

    /// Re-targets the 20 available geofences at the stops the listener has yet to reach.
    func replanGeofences() {
        guard let tour = activeTourId.flatMap(tour(id:)), location.isAuthorized else { return }
        let next = progress[tour.id]?.nextStop(in: tour)?.order ?? 0
        location.monitor(GeofencePlanner.plan(stops: tour.stops, strategy: .routeOrder(fromIndex: next)))
    }

    func nextStop(for tour: Tour) -> Stop? { progress[tour.id]?.nextStop(in: tour) ?? tour.stops.first }

    func tourProgress(_ tour: Tour) -> TourProgress? { progress[tour.id] }

    func fraction(of tour: Tour) -> Double { progress[tour.id]?.fraction(of: tour) ?? 0 }

    /// The tour to offer under "Continue", if the listener has started one that isn't finished.
    var resumeCandidate: (tour: Tour, stop: Stop)? {
        guard let tour = activeTourId.flatMap(tour(id:)), let stop = progress[tour.id]?.nextStop(in: tour) else { return nil }
        return (tour, stop)
    }

    private func handleArrival(stopId: String) {
        guard let tour = activeTourId.flatMap(tour(id:)),
              let stop = tour.stops.first(where: { $0.id == stopId }) else { return }
        Haptics.arrival()
        ArrivalNotifications.post(stopName: stop.name[language], tourTitle: tour.title[language], tourId: tour.id, stopId: stop.id)
        if access(to: stop).isUnlocked, audio.nowPlaying == nil || !audio.isPlaying {
            // Don't talk over the listener: offer the stop, they tap to listen.
            open(tourId: tour.id, stopId: stop.id)
        }
    }

    // MARK: Navigation helpers

    func open(tourId: String, stopId: String) {
        selectedTab = .tours
        toursPath = NavigationPath()
        toursPath.append(TourRoute(id: tourId))
        toursPath.append(StopRoute(tourId: tourId, stopId: stopId))
    }

    func open(tourId: String) {
        selectedTab = .tours
        toursPath = NavigationPath()
        toursPath.append(TourRoute(id: tourId))
    }

    /// Opens the stop in the first tour that contains it (used by the map, where tours overlap).
    func open(stopId: String) {
        guard let catalog, let tour = catalog.toursContaining(stopId: stopId).first(where: { $0.kind == .area })
                ?? catalog.toursContaining(stopId: stopId).first else { return }
        open(tourId: tour.id, stopId: stopId)
    }

    func openAdjacentStop(offset: Int) {
        guard let route = nowPlayingRoute, let found = resolve(route) else { return }
        let (tour, stop) = (found.tour, found.stop)
        let index = stop.order + offset
        guard tour.stops.indices.contains(index) else { return }
        let target = tour.stops[index]
        open(tourId: tour.id, stopId: target.id)
        play(target, in: tour)
    }

    /// App Intent entry point ("Resume my tour"). If the app was cold-launched by the intent the
    /// catalog isn't loaded yet, so the request is replayed at the end of `start()`.
    func resumeTour() {
        guard catalog != nil else { pendingResume = true; return }
        if let candidate = resumeCandidate {
            open(tourId: candidate.tour.id, stopId: candidate.stop.id)
        } else {
            selectedTab = .tours
        }
    }

    private func persistProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: Keys.progress)
        }
    }
}

// MARK: - Spotlight

enum SpotlightIndexer {
    /// Makes every tour findable from system search ("Capitol Hill walk").
    static func index(_ tours: [Tour], language: TourLanguage) {
        let items = tours.map { tour -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = tour.title[language]
            attributes.contentDescription = tour.tagline[language]
            attributes.keywords = tour.stops.prefix(12).map { $0.name[language] }
            return CSSearchableItem(uniqueIdentifier: "tour:\(tour.id)", domainIdentifier: "tours", attributeSet: attributes)
        }
        CSSearchableIndex.default().deleteAllSearchableItems { _ in
            CSSearchableIndex.default().indexSearchableItems(items)
        }
    }
}
