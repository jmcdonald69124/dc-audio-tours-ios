import CoreSpotlight
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.selectedTab) {
            ToursView()
                .tabItem { Label("Tours", systemImage: "headphones") }
                .tag(AppTab.tours)
            NearbyView()
                .tabItem { Label("Nearby", systemImage: "location.viewfinder") }
                .tag(AppTab.nearby)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        // Text("…") literals follow the language chosen in the app, not only the system language.
        .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        .sheet(isPresented: $model.showFullPlayer) {
            FullPlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // Tapping a tour in Spotlight search lands on that tour.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String, id.hasPrefix("tour:") {
                model.open(tourId: String(id.dropFirst("tour:".count)))
            }
        }
        .onChange(of: model.audio.isPlaying) { _, playing in
            if !playing { model.savePlaybackPosition() }
        }
    }
}

extension View {
    /// Docks the mini player above the tab bar whenever something is playing.
    func miniPlayerInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { MiniPlayerBar() }
    }
}
