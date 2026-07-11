import SwiftUI

@main
struct WidgetRPGApp: App {
    @StateObject private var game = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                game.processIdle()
            case .background:
                game.save()
            default:
                break
            }
        }
    }
}
