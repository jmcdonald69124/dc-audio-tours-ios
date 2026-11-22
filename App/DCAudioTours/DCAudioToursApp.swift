import SwiftUI

@main
struct DCAudioToursApp: App {
    private let model = AppModel.shared

    init() { Appearance.apply() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.start() }
        }
    }
}
