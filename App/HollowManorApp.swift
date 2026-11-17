import SwiftUI

@main
struct HollowManorApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
