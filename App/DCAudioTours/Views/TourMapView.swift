import MapKit
import SwiftUI
import TourKit

/// Numbered stops on a map. For neighborhood walks it also draws the real pedestrian route between
/// consecutive stops, fetched from Apple Maps (not the straight-line / street-grid estimates in the catalog).
struct TourMapView: View {
    let tour: Tour
    @Environment(AppModel.self) private var model
    @State private var position: MapCameraPosition
    @State private var legs: [MKPolyline] = []

    private struct Pin: Identifiable {
        let id: String
        let order: Int
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    init(tour: Tour) {
        self.tour = tour
        let coordinates = tour.stops.compactMap { $0.location?.coordinate }
        if let region = MKCoordinateRegion(fitting: coordinates) {
            _position = State(initialValue: .region(region))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    private var pins: [Pin] {
        tour.stops.compactMap { stop in
            stop.location.map { Pin(id: stop.id, order: stop.order, name: stop.name[model.language], coordinate: $0.coordinate.clLocation) }
        }
    }

    var body: some View {
        let color = Theme.color(for: tour)
        Map(position: $position) {
            UserAnnotation()
            ForEach(Array(legs.enumerated()), id: \.offset) { _, line in
                MapPolyline(line).stroke(color, lineWidth: 5)
            }
            ForEach(pins) { pin in
                Annotation(pin.name, coordinate: pin.coordinate, anchor: .bottom) {
                    Text("\(pin.order + 1)")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.white)
                        .background(color, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(radius: 2, y: 1)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
        .task(id: tour.id) { await loadLegs() }
    }

    /// Walking routes between consecutive stops — only for compact neighborhood walks, where every
    /// leg really is walked. (Themed tours hop between Metro stations.)
    private func loadLegs() async {
        guard tour.kind == .area else { return }
        var lines: [MKPolyline] = []
        let located = tour.stops.compactMap { $0.location?.coordinate }
        for (from, to) in zip(located, located.dropFirst()) {
            if let leg = try? await model.walking.route(from: from, to: to) { lines.append(leg.polyline) }
        }
        legs = lines
    }
}
