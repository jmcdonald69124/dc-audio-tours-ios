import SwiftUI
import TourKit

struct StopView: View {
    let route: StopRoute
    @Environment(AppModel.self) private var model

    var body: some View {
        if let found = model.resolve(route) {
            StopContentView(tour: found.tour, stop: found.stop)
        } else {
            ContentUnavailableView("Stop not found", systemImage: "questionmark.circle")
        }
    }
}

private struct StopContentView: View {
    let tour: Tour
    let stop: Stop
    @Environment(AppModel.self) private var model

    var body: some View {
        let access = model.access(to: stop)
        let color = Theme.color(for: tour)
        let text = model.text(for: stop)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(color: color)

                if access.isUnlocked {
                    StopPlayerCard(tour: tour, stop: stop)
                    if let narration = text?.narration, !narration.isEmpty {
                        Text(narration)
                            .font(.body).lineSpacing(6)
                            .textSelection(.enabled)
                    }
                    if let tips = text?.tips, !tips.isEmpty { TipCard(text: tips, color: color) }
                    if let subStops = text?.subStops, !subStops.isEmpty {
                        SubStopsSection(tour: tour, stop: stop, subStops: subStops)
                    }
                } else {
                    LockedCard(tour: tour)
                }

                gettingThere
                nextLeg
                adjacentStops
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(stop.name[model.language])
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerInset()
    }

    // MARK: Pieces

    private func header(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stop.name[model.language])
                .font(.display(.largeTitle).weight(.semibold))
            HStack(spacing: 8) {
                LineStack(lines: stop.lines)
                Text(stop.station).font(.subheadline.weight(.medium))
            }
            if !stop.exit.isEmpty {
                Label(stop.exit, systemImage: "door.left.hand.open").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if stop.walkMin > 0 { Label("\(stop.walkMin) min walk", systemImage: "figure.walk") }
                let duration = stop.duration[model.language]
                if !duration.isEmpty { Label(duration, systemImage: "clock") }
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// Real walking route from the Metro exit to the stop — for every stop in every tour, since
    /// station coordinates are in the catalog. On neighborhood walks only the first stop starts at a station.
    @ViewBuilder private var gettingThere: some View {
        if (tour.kind == .themed || stop.order == 0), let station = stop.stationLocation, let place = stop.location {
            WalkingRouteCard(
                title: "From \(stop.station) station",
                from: station, to: place.coordinate, destinationName: stop.name[model.language])
        }
    }

    @ViewBuilder private var nextLeg: some View {
        if tour.kind == .area, let here = stop.location, stop.order + 1 < tour.stops.count {
            let next = tour.stops[stop.order + 1]
            if let there = next.location {
                if let comfort = tour.route?.details?.comfortStops.first(where: { $0.afterStopId == stop.id }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(comfort.name, systemImage: "cup.and.saucer").font(.headline)
                        Text(comfort.note).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                WalkingRouteCard(
                    title: "Next: \(next.name[model.language])",
                    from: here.coordinate, to: there.coordinate, destinationName: next.name[model.language])
            }
        }
    }

    private var adjacentStops: some View {
        HStack(spacing: 12) {
            if stop.order > 0 {
                let previous = tour.stops[stop.order - 1]
                NavigationLink(value: StopRoute(tourId: tour.id, stopId: previous.id)) {
                    Label("Previous", systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            if stop.order + 1 < tour.stops.count {
                let next = tour.stops[stop.order + 1]
                NavigationLink(value: StopRoute(tourId: tour.id, stopId: next.id)) {
                    Label("Next stop", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.color(for: tour))
            }
        }
        .controlSize(.large)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.title; configuration.icon }
    }
}

private struct StopPlayerCard: View {
    let tour: Tour
    let stop: Stop
    @Environment(AppModel.self) private var model

    var body: some View {
        let isCurrent = model.audio.nowPlaying?.id == "\(tour.id)/\(stop.id)"
        VStack(spacing: 14) {
            if isCurrent {
                PlayerControls()
            } else {
                Button { model.play(stop, in: tour) } label: {
                    Label("Listen", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.color(for: tour))
            }
            if isCurrent, let error = model.audio.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct TipCard: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill").foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text("Good to know").font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct SubStopsSection: View {
    let tour: Tour
    let stop: Stop
    let subStops: [SubStopContent]
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inside").font(.display(.title2).weight(.semibold))
            ForEach(subStops) { sub in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        if !sub.directions.isEmpty {
                            clip("Directions", icon: "arrow.triangle.turn.up.right.diamond", text: sub.directions,
                                 file: AudioFiles.subStopDirections(stopId: stop.id, subStopId: sub.id, language: model.language),
                                 title: sub.name)
                        }
                        if !sub.narration.isEmpty {
                            clip("About this", icon: "headphones", text: sub.narration,
                                 file: AudioFiles.subStopNarration(stopId: stop.id, subStopId: sub.id, language: model.language),
                                 title: sub.name)
                        }
                        if !sub.tips.isEmpty { Text(sub.tips).font(.footnote).foregroundStyle(.secondary) }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(sub.name).font(.headline)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func clip(_ label: LocalizedStringKey, icon: String, text: String, file: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                model.playSubStop(file: file, title: title, parent: stop, in: tour)
            } label: {
                Label(label, systemImage: "play.circle.fill").font(.subheadline.weight(.semibold))
            }
            Text(text).font(.subheadline).lineSpacing(4)
        }
    }
}

private struct LockedCard: View {
    let tour: Tour
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.title)
            Text("This stop is part of the full tour").font(.headline)
            Text("The first stop of every tour is free. Unlock \(tour.title[model.language]) to hear every stop.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            // Phase 2: StoreKit 2 purchase button goes here (see docs/backend-requirements.md).
            Text("Purchases arrive in the next update.").font(.footnote).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }
}
