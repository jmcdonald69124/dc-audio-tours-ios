import SwiftUI
import TourKit

struct ToursView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.toursPath) {
            ScrollView {
                if let catalog = model.catalog {
                    VStack(alignment: .leading, spacing: 28) {
                        if let resume = model.resumeCandidate { ResumeCard(tour: resume.tour, stop: resume.stop) }
                        section("Walk a neighborhood", tours: filtered(catalog.areaTours))
                        section("Stories across the Metro", tours: filtered(catalog.themedTours))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                } else if let error = model.loadError {
                    ContentUnavailableView("Couldn't load tours", systemImage: "exclamationmark.triangle", description: Text(error))
                        .padding(.top, 80)
                } else {
                    ProgressView().padding(.top, 120)
                }
            }
            .navigationTitle("DC Audio Tours")
            .searchable(text: $query, prompt: "Search tours")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { LanguageMenu() } }
            .navigationDestination(for: TourRoute.self) { TourDetailView(tourId: $0.id) }
            .navigationDestination(for: StopRoute.self) { StopView(route: $0) }
            .miniPlayerInset()
        }
    }

    private func filtered(_ tours: [Tour]) -> [Tour] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return tours }
        return tours.filter {
            $0.title[model.language].localizedCaseInsensitiveContains(q)
                || $0.tagline[model.language].localizedCaseInsensitiveContains(q)
                || $0.stops.contains { $0.name[model.language].localizedCaseInsensitiveContains(q) }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, tours: [Tour]) -> some View {
        if !tours.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.display(.title2).weight(.semibold))
                ForEach(tours) { tour in
                    NavigationLink(value: TourRoute(id: tour.id)) { TourCard(tour: tour) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

struct LanguageMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Picker("Language", selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                ForEach(TourLanguage.allCases) { Text("\($0.flag)  \($0.nativeName)").tag($0) }
            }
        } label: {
            Text(model.language.flag).font(.title3)
        }
        .accessibilityLabel("Language")
    }
}

struct TourCard: View {
    let tour: Tour
    @Environment(AppModel.self) private var model

    var body: some View {
        let color = Theme.color(for: tour)
        let progress = model.fraction(of: tour)

        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tour.title[model.language])
                        .font(.display(.title3).weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    AccessPill(access: model.access(to: tour))
                }
                Text(tour.tagline[model.language])
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading).lineLimit(2)
                HStack(spacing: 14) {
                    Label("\(tour.stops.count) stops", systemImage: "mappin.and.ellipse")
                    if let route = tour.route {
                        Label(Formatters.distance(Double(route.totalMeters)), systemImage: "figure.walk")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if progress > 0 { ProgressView(value: progress).tint(color) }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct ResumeCard: View {
    let tour: Tour
    let stop: Stop
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.open(tourId: tour.id, stopId: stop.id) } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill").font(.system(size: 38)).foregroundStyle(Theme.color(for: tour))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(stop.name[model.language]).font(.headline).multilineTextAlignment(.leading)
                    Text(tour.title[model.language]).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
