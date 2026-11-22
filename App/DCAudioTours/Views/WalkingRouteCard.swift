import SwiftUI
import TourKit

/// Live walking directions between two points from Apple Maps: time, distance, turn-by-turn steps,
/// and a one-tap hand-off to the Maps app for guidance with haptics on Apple Watch.
struct WalkingRouteCard: View {
    let title: LocalizedStringKey
    let from: Coordinate
    let to: Coordinate
    let destinationName: String

    @Environment(AppModel.self) private var model
    @State private var leg: WalkingLeg?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "figure.walk").font(.headline)

            if let leg {
                HStack(spacing: 18) {
                    Label(Formatters.walkTime(leg.expectedTravelTime), systemImage: "clock")
                    Label(Formatters.distance(leg.distance), systemImage: "ruler")
                }
                .font(.subheadline)

                if !leg.steps.isEmpty {
                    DisclosureGroup("Turn-by-turn") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(leg.steps.enumerated()), id: \.offset) { index, step in
                                Text("\(index + 1). \(step)").font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }
                }
            } else if failed {
                Text("Walking directions aren't available right now.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }

            Button {
                WalkingDirectionsService.openInMaps(to: to, destinationName: destinationName)
            } label: {
                Label("Open in Apple Maps", systemImage: "map")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .task(id: "\(from.lat),\(from.lon)>\(to.lat),\(to.lon)") { await load() }
    }

    private func load() async {
        do {
            leg = try await model.walking.route(from: from, to: to)
            failed = false
        } catch {
            leg = nil
            failed = true
        }
    }
}
