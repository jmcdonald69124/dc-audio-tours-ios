import MapKit
import SwiftUI
import TourKit

struct TourDetailView: View {
    let tourId: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if let tour = model.tour(id: tourId) {
            content(tour)
        } else {
            ContentUnavailableView("Tour not found", systemImage: "questionmark.circle")
        }
    }

    private func content(_ tour: Tour) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(tour)
                overview(tour)
                timeline(tour)
            }
        }
        .background(Ed.bg.ignoresSafeArea())
        .navigationTitle(tour.title[model.language])
        .navigationBarTitleDisplayMode(.inline)
        .tint(Ed.accent)
        .miniPlayerInset()
    }

    // MARK: Header — serif standfirst, meta line, CTA

    private func header(_ tour: Tour) -> some View {
        let started = model.fraction(of: tour) > 0
        let next = model.nextStop(for: tour)

        return VStack(alignment: .leading, spacing: 20) {
            Text(tour.marketing?[model.language].isEmpty == false ? tour.marketing![model.language] : tour.tagline[model.language])
                .font(EdFont.serif(26, relativeTo: .title2))
                .lineSpacing(5)
                .foregroundStyle(Ed.textStrong)

            HStack(spacing: 9) {
                Circle().fill(Ed.accent).frame(width: 6, height: 6)
                Text(metaLine(tour)).font(.system(size: 15)).foregroundStyle(Ed.textMuted)
            }

            Button {
                model.startTour(tour)
                if let next { model.toursPath.append(StopRoute(tourId: tour.id, stopId: next.id)) }
            } label: {
                Label(started ? "Continue tour" : "Start tour", systemImage: "play.fill")
            }
            .buttonStyle(.editorial)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 32)
    }

    private func metaLine(_ tour: Tour) -> String {
        let stops = "\(tour.stops.count) stops"
        if let route = tour.route {
            return "\(stops) · \(Formatters.distance(Double(route.totalMeters))) on foot"
        }
        return tour.isFree ? "\(stops) · free" : "\(stops) · first stop free"
    }

    // MARK: Stop overview — map on a tinted band

    private func overview(_ tour: Tour) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Stop overview")
            Text(tour.kind == .area ? "Every stop, in walking order." : "Every stop, in tour order — route paths are approximate.")
                .font(.system(size: 15)).foregroundStyle(Ed.textMuted)

            TourMapView(tour: tour)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Ed.border, lineWidth: 1))

            if let route = tour.route { RouteSummary(route: route) }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ed.surfaceAlt)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    // MARK: Timeline

    private func timeline(_ tour: Tour) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(tour.stops) { stop in
                NavigationLink(value: StopRoute(tourId: tour.id, stopId: stop.id)) {
                    StopRow(tour: tour, stop: stop)
                }
                .buttonStyle(.plain)
                Hairline()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .padding(.bottom, 24)
    }
}

private struct RouteSummary: View {
    let route: WalkingRoute
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let details = route.details {
                Label(details.start, systemImage: "figure.walk.departure")
                Label(details.finish, systemImage: "figure.walk.arrival")
                Label(details.pace, systemImage: "speedometer")
            }
            Label(
                "\(Formatters.distance(Double(route.totalMeters))) · about \(Formatters.walkTime(TimeInterval(route.totalSeconds)))",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            if route.metricsEstimated {
                Text("Walking times are estimates; each stop shows a live route from Apple Maps.")
                    .font(.footnote).foregroundStyle(Ed.textDim)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Ed.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// A stop on the walking timeline: numbered in the line colour, serif name, station + line badges.
struct StopRow: View {
    let tour: Tour
    let stop: Stop
    @Environment(AppModel.self) private var model

    var body: some View {
        let access = model.access(to: stop)
        let done = model.tourProgress(tour)?.completedStopIds.contains(stop.id) == true
        let line = stop.lines.first

        HStack(spacing: 14) {
            Text("\(stop.order + 1)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(line.map(Theme.ink(on:)) ?? .white)
                .frame(width: 36, height: 36)
                .background(line.map(Theme.color) ?? Ed.accent, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(stop.name[model.language])
                    .font(EdFont.serif(20, relativeTo: .headline))
                    .foregroundStyle(Ed.textStrong).multilineTextAlignment(.leading)
                HStack(spacing: 7) {
                    LineStack(lines: stop.lines, size: 18)
                    Text(stop.station).font(.system(size: 13)).foregroundStyle(Ed.textMuted)
                }
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Ed.success)
            } else if access == .freePreview || access == .freeTour {
                FreePill()
            } else if !access.isUnlocked {
                Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(Ed.textDim)
            }
            Image(systemName: "arrow.right").font(.system(size: 14)).foregroundStyle(Ed.textMuted)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
