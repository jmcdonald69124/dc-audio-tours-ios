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
        let lineColor = stop.lines.first.map(Theme.color) ?? Ed.accent
        let text = model.text(for: stop)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(lineColor: lineColor)

                VStack(alignment: .leading, spacing: 26) {
                    if access.isUnlocked {
                        StopPlayerCard(tour: tour, stop: stop)
                        if let narration = text?.narration, !narration.isEmpty {
                            Text(narration)
                                .font(.system(size: 17)).lineSpacing(8)
                                .foregroundStyle(Ed.text)
                                .textSelection(.enabled)
                        }
                        if let tips = text?.tips, !tips.isEmpty { TipCard(text: tips, color: lineColor) }
                        if let subStops = text?.subStops, !subStops.isEmpty {
                            SubStopsSection(tour: tour, stop: stop, subStops: subStops)
                        }
                    } else {
                        LockedCard(tour: tour)
                    }

                    gettingThere
                    nextLeg
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
        }
        .background(Ed.bg.ignoresSafeArea())
        // Dark top bar that continues into the hero, like the web stop page.
        .navigationTitle("Stop \(stop.order + 1) of \(tour.stops.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Ed.heroBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                MiniPlayerBar()
                navBar
            }
        }
    }

    // MARK: Hero

    private func hero(lineColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Eyebrow("Stop \(stop.order + 1) of \(tour.stops.count)", dot: lineColor, onDark: true)
                Spacer()
                LineStack(lines: stop.lines, size: 30)
            }

            Text(stop.name[model.language])
                .font(EdFont.serif(38, relativeTo: .largeTitle))
                .tracking(-0.6)
                .foregroundStyle(Ed.heroText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Label { Text(stop.station).foregroundStyle(Ed.heroText) } icon: { Image(systemName: "tram.fill").foregroundStyle(lineColor) }
                if stop.walkMin > 0 {
                    Label("\(stop.walkMin) min walk from station", systemImage: "figure.walk")
                }
                let duration = stop.duration[model.language]
                if !duration.isEmpty { Label(duration, systemImage: "clock") }
            }
            .font(.system(size: 15))
            .foregroundStyle(Ed.heroMuted)

            if !stop.exit.isEmpty {
                Text("Exit: \(stop.exit)").font(.system(size: 14)).foregroundStyle(Ed.heroDim)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(colors: [Ed.heroBg, Ed.heroBg2], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [lineColor.opacity(0.34), .clear],
                               startPoint: .topTrailing, endPoint: UnitPoint(x: 0.35, y: 0.75))
            }
        }
    }

    // MARK: Directions

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
                    VStack(alignment: .leading, spacing: 6) {
                        Label(comfort.name, systemImage: "cup.and.saucer")
                            .font(EdFont.serif(18, relativeTo: .headline)).foregroundStyle(Ed.textStrong)
                        Text(comfort.note).font(.system(size: 14)).foregroundStyle(Ed.textMuted)
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

    // MARK: Prev / Next bar

    private var navBar: some View {
        let lineColor = stop.lines.first.map(Theme.color) ?? Ed.accent
        let ink = stop.lines.first.map(Theme.ink(on:)) ?? Ed.onAccent
        let hasPrev = stop.order > 0
        let hasNext = stop.order + 1 < tour.stops.count

        return HStack(spacing: 12) {
            Button {
                if hasPrev { model.replaceStop(tourId: tour.id, stopId: tour.stops[stop.order - 1].id) }
            } label: {
                Label("Prev", systemImage: "arrow.left").frame(maxWidth: .infinity)
            }
            .buttonStyle(StopNavButtonStyle(fill: Ed.surfaceAlt, ink: Ed.textStrong, border: Ed.border))
            .disabled(!hasPrev)

            Button {
                if hasNext { model.replaceStop(tourId: tour.id, stopId: tour.stops[stop.order + 1].id) }
            } label: {
                HStack(spacing: 8) { Text("Next"); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
            }
            .buttonStyle(StopNavButtonStyle(fill: lineColor, ink: ink, border: .clear))
            .disabled(!hasNext)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Ed.surface)
        .overlay(alignment: .top) { Hairline() }
    }
}

private struct StopNavButtonStyle: ButtonStyle {
    let fill: Color
    let ink: Color
    let border: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(ink)
            .frame(height: 52)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
    }
}

// MARK: - Cards

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
                    Label("Listen", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.editorial(fill: Ed.accent, ink: Ed.onAccent, fullWidth: true))
            }
            if isCurrent, let error = model.audio.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Ed.textMuted)
            }
        }
        .card()
    }
}

private struct TipCard: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Good to know")
                Text(text).font(.system(size: 15)).lineSpacing(4).foregroundStyle(Ed.text)
            }
            .padding(16)
            Spacer(minLength: 0)
        }
        .background(Ed.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ed.border, lineWidth: 1))
    }
}

private struct SubStopsSection: View {
    let tour: Tour
    let stop: Stop
    let subStops: [SubStopContent]
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow("Inside").padding(.bottom, 10)
            Hairline()
            ForEach(subStops) { sub in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        if !sub.directions.isEmpty {
                            clip("Directions", text: sub.directions,
                                 file: AudioFiles.subStopDirections(stopId: stop.id, subStopId: sub.id, language: model.language),
                                 title: sub.name)
                        }
                        if !sub.narration.isEmpty {
                            clip("About this", text: sub.narration,
                                 file: AudioFiles.subStopNarration(stopId: stop.id, subStopId: sub.id, language: model.language),
                                 title: sub.name)
                        }
                        if !sub.tips.isEmpty { Text(sub.tips).font(.system(size: 14)).foregroundStyle(Ed.textMuted) }
                    }
                    .padding(.top, 10)
                } label: {
                    Text(sub.name).font(EdFont.serif(19, relativeTo: .headline)).foregroundStyle(Ed.textStrong)
                }
                .tint(Ed.accent)
                .padding(.vertical, 14)
                Hairline()
            }
        }
    }

    private func clip(_ label: LocalizedStringKey, text: String, file: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.playSubStop(file: file, title: title, parent: stop, in: tour) } label: {
                Label(label, systemImage: "play.circle.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Ed.accent)
            }
            Text(text).font(.system(size: 15)).lineSpacing(5).foregroundStyle(Ed.text)
        }
    }
}

private struct LockedCard: View {
    let tour: Tour
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(Ed.accent)
            Text("This stop is part of the full tour")
                .font(EdFont.serif(22, relativeTo: .title3)).foregroundStyle(Ed.textStrong).multilineTextAlignment(.center)
            Text("The first stop of every tour is free. Unlock \(tour.title[model.language]) to hear every stop.")
                .font(.system(size: 15)).foregroundStyle(Ed.textMuted).multilineTextAlignment(.center)
            // Phase 2: StoreKit 2 purchase button goes here (see docs/backend-requirements.md).
            Text("Purchases arrive in the next update.").font(.footnote).foregroundStyle(Ed.textDim)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 26)
    }
}
