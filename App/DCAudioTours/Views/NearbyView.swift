import MapKit
import SwiftUI
import TourKit

/// Every stop in the catalog on one map, sorted by distance — "what's near me right now?".
struct NearbyView: View {
    @Environment(AppModel.self) private var model
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let station: String
        let coordinate: Coordinate
        var meters: Double?
    }

    private var entries: [Entry] {
        guard let catalog = model.catalog else { return [] }
        var seen = Set<String>()
        var result: [Entry] = []
        for tour in catalog.tours {
            for stop in tour.stops where !seen.contains(stop.id) {
                guard let location = stop.location else { continue }
                seen.insert(stop.id)
                result.append(Entry(
                    id: stop.id, name: stop.name[model.language], station: stop.station,
                    coordinate: location.coordinate, meters: model.location.coordinate.map { $0.distance(to: location.coordinate) }))
            }
        }
        if model.location.coordinate != nil { result.sort { ($0.meters ?? .infinity) < ($1.meters ?? .infinity) } }
        return result
    }

    var body: some View {
        let list = entries
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $position) {
                    UserAnnotation()
                    ForEach(list) { entry in
                        Annotation(entry.name, coordinate: entry.coordinate.clLocation) {
                            Button { model.open(stopId: entry.id) } label: {
                                Image(systemName: "headphones.circle.fill")
                                    .font(.title)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Ed.onAccent, Ed.accent)
                            }
                            .accessibilityLabel(entry.name)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .mapControls { MapUserLocationButton(); MapCompass() }
                .overlay(alignment: .top) { permissionBanner }

                List(list.prefix(12)) { entry in
                    Button { model.open(stopId: entry.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name).font(EdFont.serif(18, relativeTo: .headline)).foregroundStyle(Ed.textStrong)
                                Text(entry.station).font(.system(size: 12)).foregroundStyle(Ed.textMuted)
                            }
                            Spacer()
                            if let meters = entry.meters {
                                Text(Formatters.distance(meters)).font(.system(size: 13)).foregroundStyle(Ed.textMuted)
                            }
                        }
                    }
                    .listRowBackground(Ed.bg)
                    .listRowSeparatorTint(Ed.border)
                    .tint(Ed.textStrong)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Ed.bg)
                .frame(maxHeight: 260)
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .miniPlayerInset()
        }
        .onAppear {
            model.location.requestWhenInUse()
            model.location.startUpdates()
        }
        .onDisappear { model.location.stopUpdates() }
    }

    @ViewBuilder private var permissionBanner: some View {
        if model.location.authorization == .denied || model.location.authorization == .restricted {
            Text("Turn on Location in Settings to see stops near you.")
                .font(.footnote)
                .padding(10)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        }
    }
}
