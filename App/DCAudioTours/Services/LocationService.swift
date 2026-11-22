import CoreLocation
import Observation
import TourKit

/// Location for the "you are here" dot and, more importantly, **arrival detection**: the system
/// watches a handful of upcoming stops as geofences and wakes the app when the listener walks
/// into one — even with the screen off — so narration can be offered at exactly the right place
/// without the app polling GPS (which would flatten the battery on a long walk).
@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var location: CLLocation?
    private(set) var monitoredStopIds: [String] = []

    /// Called with the stop id when the listener enters a monitored region.
    var onArrival: ((String) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.activityType = .fitness          // a walking tour
        manager.pausesLocationUpdatesAutomatically = true
    }

    var coordinate: Coordinate? {
        location.map { Coordinate(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
    }

    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var canMonitorInBackground: Bool { authorization == .authorizedAlways }

    // MARK: Authorization

    func requestWhenInUse() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    /// Needed for arrival alerts while the app is in the background. iOS only shows this prompt
    /// after When-In-Use has been granted, so call it after the listener has seen the value of the feature.
    func requestAlways() {
        if authorization == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
    }

    // MARK: Live position (only while a map or tour screen is visible)

    func startUpdates() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdates() { manager.stopUpdatingLocation() }

    // MARK: Geofences

    /// Replaces the currently monitored regions with `regions` (at most `GeofencePlanner.systemLimit`).
    func monitor(_ regions: [GeofenceRegion]) {
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { monitoredStopIds = []; return }
        for region in regions.prefix(GeofencePlanner.systemLimit) {
            let circle = CLCircularRegion(
                center: region.center.clLocation,
                radius: min(region.radius, manager.maximumRegionMonitoringDistance),
                identifier: region.id)
            circle.notifyOnEntry = true
            circle.notifyOnExit = false
            manager.startMonitoring(for: circle)
        }
        monitoredStopIds = regions.map(\.id)
    }

    func stopMonitoring() { monitor([]) }

    // MARK: CLLocationManagerDelegate (nonisolated; hop to the main actor)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.location = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.onArrival?(id) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {}
}
