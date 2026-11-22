import AppIntents

/// "Hey Siri, resume my tour" — also appears in Shortcuts and Spotlight with no setup.
struct ResumeTourIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume my tour"
    static let description = IntentDescription("Continue your DC audio tour where you left off.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.resumeTour()
        return .result()
    }
}

struct DCAudioToursShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ResumeTourIntent(),
            phrases: [
                "Resume my tour in \(.applicationName)",
                "Continue my \(.applicationName) tour",
            ],
            shortTitle: "Resume tour",
            systemImageName: "headphones")
    }
}
