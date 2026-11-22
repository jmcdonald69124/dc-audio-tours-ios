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
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tour.tagline[model.language])
                        .font(.display(.title3)).foregroundStyle(.secondary)
                    if let marketing = tour.marketing?[model.language], !marketing.isEmpty {
                        Text(marketing).font(.body).foregroundStyle(.secondary)
                    }
                }

                startButton(tour)

                TourMapView(tour: tour)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

                if let route = tour.route { RouteSummary(route: route) }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Stops").font(.display(.title2).weight(.semibold)).padding(.bottom, 8)
                    ForEach(tour.stops) { stop in
                        NavigationLink(value: StopRoute(tourId: tour.id, stopId: stop.id)) {
                            StopRow(tour: tour, stop: stop)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(tour.title[model.language])
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerInset()
    }

    private func startButton(_ tour: Tour) -> some View {
        let next = model.nextStop(for: tour)
        let started = model.fraction(of: tour) > 0
        return Button {
            model.startTour(tour)
            if let next { model.toursPath.append(StopRoute(tourId: tour.id, stopId: next.id)) }
        } label: {
            Label(started ? "Continue tour" : "Start tour", systemImage: "play.fill")
                .font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.color(for: tour))
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
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct StopRow: View {
    let tour: Tour
    let stop: Stop
    @Environment(AppModel.self) private var model

    var body: some View {
        let access = model.access(to: stop)
        let done = model.tourProgress(tour)?.completedStopIds.contains(stop.id) == true
        let color = Theme.color(for: tour)

        HStack(spacing: 14) {
            Text("\(stop.order + 1)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .frame(width: 34, height: 34)
                .foregroundStyle(.white)
                .background(color, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name[model.language]).font(.headline).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    LineStack(lines: stop.lines)
                    Text(stop.station).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if !access.isUnlocked {
                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            } else {
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
