import SwiftUI
import TourKit

struct ToursView: View {
    @Environment(AppModel.self) private var model
    @State private var showAllAreas = false
    @State private var showAllThemed = false

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.toursPath) {
            ScrollViewReader { proxy in
                ScrollView {
                    if let catalog = model.catalog {
                        VStack(alignment: .leading, spacing: 0) {
                            HeroBand(onBrowse: { withAnimation { proxy.scrollTo("selector", anchor: .top) } },
                                     onStartFree: { model.open(tourId: catalog.freeTourId) })
                            selector(catalog).id("selector")
                        }
                    } else if let error = model.loadError {
                        ContentUnavailableView("Couldn't load tours", systemImage: "exclamationmark.triangle", description: Text(error))
                            .padding(.top, 120)
                    } else {
                        ProgressView().tint(Ed.accent).padding(.top, 160)
                    }
                }
                #if DEBUG
                .task(id: model.catalog != nil) {
                    guard model.catalog != nil, ProcessInfo.processInfo.arguments.contains("-scroll-selector") else { return }
                    try? await Task.sleep(for: .seconds(1))
                    proxy.scrollTo("selector", anchor: .top)
                }
                #endif
            }
            .background(Ed.bg.ignoresSafeArea())
            // Dark, empty top bar so the status bar sits on the same dark band as the hero (white clock).
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Ed.heroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: TourRoute.self) { TourDetailView(tourId: $0.id) }
            .navigationDestination(for: StopRoute.self) { StopView(route: $0) }
            .miniPlayerInset()
        }
    }

    // MARK: Selector

    private func selector(_ catalog: Catalog) -> some View {
        let free = catalog.tour(id: catalog.freeTourId)
        let areas = catalog.areaTours
        let themed = catalog.themedTours.filter { $0.id != catalog.freeTourId }
        let areaToggle: LocalizedStringKey = showAllAreas ? "Show fewer area walks" : "Show all \(areas.count) area walks"
        let themedToggle: LocalizedStringKey = showAllThemed ? "Show fewer themed tours" : "Show all \(themed.count) themed tours"
        let areaRows = showAllAreas ? areas : Array(areas.prefix(3))
        let themedRows = showAllThemed ? themed : Array(themed.prefix(3))

        return VStack(alignment: .leading, spacing: 40) {
            if let free { FeaturedTour(tour: free) }

            if let resume = model.resumeCandidate { ResumeCard(tour: resume.tour, stop: resume.stop) }

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("Start here", dot: Ed.accent)
                Text("Choose a neighborhood or a story")
                    .font(EdFont.serif(30, relativeTo: .title))
                    .foregroundStyle(Ed.textStrong)
                Text("Most visitors start with one walkable area or one themed story. You can always open the full catalog after that.")
                    .font(.system(size: 15)).lineSpacing(3)
                    .foregroundStyle(Ed.textMuted)
            }

            rows("Walk one area", tours: areaRows, indexed: false)
            if areas.count > 3 {
                Button(areaToggle) {
                    withAnimation { showAllAreas.toggle() }
                }
                .buttonStyle(.ghost)
                .padding(.top, -20)
            }

            rows("Pick a story", tours: themedRows, indexed: true)
            if themed.count > 3 {
                Button(themedToggle) {
                    withAnimation { showAllThemed.toggle() }
                }
                .buttonStyle(.ghost)
                .padding(.top, -20)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 36)
        .padding(.bottom, 40)
    }

    private func rows(_ title: LocalizedStringKey, tours: [Tour], indexed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(title).padding(.bottom, 14)
            ForEach(Array(tours.enumerated()), id: \.element.id) { offset, tour in
                NavigationLink(value: TourRoute(id: tour.id)) {
                    EditorialRow(tour: tour, index: indexed ? offset + 2 : nil)
                }
                .buttonStyle(.plain)
            }
            Hairline()
        }
    }
}

// MARK: - Hero band (always dark, like the web)

private struct HeroBand: View {
    let onBrowse: () -> Void
    let onStartFree: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Spacer(); HeroLanguageChip() }
            Eyebrow("Self-guided · 8 languages · first stop free", dot: Ed.heroAccent, onDark: true)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -6)

            Text("Washington DC self-guided audio tours, walkable and accessible by Metro")
                .font(EdFont.serif(40, relativeTo: .largeTitle))
                .tracking(-0.8)
                .lineSpacing(0)
                .foregroundStyle(Ed.heroText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Start at a Metro stop, listen as you walk, and explore museums, monuments, food halls, and hidden neighborhoods at your own pace.")
                .font(.system(size: 16)).lineSpacing(4)
                .foregroundStyle(Ed.heroMuted)

            // Side by side when they fit; stacked in longer languages (e.g. Spanish, German).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { startButton; browseButton }
                VStack(alignment: .leading, spacing: 12) { startButton; browseButton }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                check("Historic speeches")
                check("Inside major venues")
                check("Turn-by-turn Metro")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .top) {
            ZStack {
                LinearGradient(colors: [Ed.heroBg, Ed.heroBg2], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Ed.heroAccent.opacity(0.18), .clear],
                               center: UnitPoint(x: 0.88, y: 0.22), startRadius: 0, endRadius: 340)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var startButton: some View {
        Button(action: onStartFree) { Label("Start free", systemImage: "play.fill") }
            .buttonStyle(.editorial(fill: Ed.heroAccent, ink: Color(hex: 0x1A1714)))
            .fixedSize(horizontal: true, vertical: false)
    }

    private var browseButton: some View {
        Button("Browse all tours", action: onBrowse)
            .buttonStyle(.ghostOnDark)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func check(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Ed.heroAccent)
            Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(Ed.heroDim)
        }
    }
}

private struct HeroLanguageChip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Picker("Language", selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                ForEach(TourLanguage.allCases) { Text("\($0.flag)  \($0.nativeName)").tag($0) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.language.flag).font(.system(size: 17))
                Text(model.language.nativeName).font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).opacity(0.7)
            }
            .foregroundStyle(Ed.heroText)
            .padding(.horizontal, 12).frame(minHeight: 40)
            .background(Ed.heroText.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(Ed.heroLine, lineWidth: 1))
        }
        .accessibilityLabel("Language")
    }
}

// MARK: - Rows and cards

/// Hairline-ruled index row — the web's `.ed-row`.
struct EditorialRow: View {
    let tour: Tour
    let index: Int?
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.fraction(of: tour)

        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 14) {
                if let index {
                    Text(String(format: "%02d", index))
                        .font(EdFont.serifItalic(14)).foregroundStyle(Ed.textDim)
                        .frame(width: 26, alignment: .leading)
                }
                Circle().fill(Theme.dot(for: tour)).frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 5) {
                    Text(tour.title[model.language])
                        .font(EdFont.serif(22, relativeTo: .title3))
                        .foregroundStyle(Ed.textStrong)
                        .multilineTextAlignment(.leading)
                    Text(tour.tagline[model.language])
                        .font(.system(size: 14)).foregroundStyle(Ed.textMuted).lineLimit(1)
                    if progress > 0 { ProgressView(value: progress).tint(Ed.accent).padding(.top, 2) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    AccessPill(access: model.access(to: tour))
                    Text("\(tour.stops.count) stops").font(.system(size: 13)).foregroundStyle(Ed.textMuted)
                }
                Image(systemName: "arrow.right").font(.system(size: 15)).foregroundStyle(Ed.textMuted)
            }
            .padding(.vertical, 20)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct FeaturedTour: View {
    let tour: Tour
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationLink(value: TourRoute(id: tour.id)) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("Featured", dot: Theme.dot(for: tour))
                Text(tour.title[model.language])
                    .font(EdFont.serif(30, relativeTo: .title))
                    .foregroundStyle(Ed.textStrong).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tour.marketing?[model.language].isEmpty == false ? tour.marketing![model.language] : tour.tagline[model.language])
                    .font(.system(size: 15)).lineSpacing(3)
                    .foregroundStyle(Ed.textMuted).multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Text("\(tour.stops.count) stops · first stop free")
                        .font(.system(size: 13)).foregroundStyle(Ed.textMuted)
                    Spacer()
                    FreePill()
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 20)
        }
        .buttonStyle(.plain)
    }
}

struct ResumeCard: View {
    let tour: Tour
    let stop: Stop
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.open(tourId: tour.id, stopId: stop.id) } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Ed.onAccent)
                    .frame(width: 40, height: 40).background(Ed.accent, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow("Continue")
                    Text(stop.name[model.language])
                        .font(EdFont.serif(19, relativeTo: .headline)).foregroundStyle(Ed.textStrong)
                        .multilineTextAlignment(.leading)
                    Text(tour.title[model.language]).font(.system(size: 13)).foregroundStyle(Ed.textMuted)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(Ed.textMuted)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
