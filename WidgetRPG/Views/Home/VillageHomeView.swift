import SwiftUI

/// ホームの村シーン(全画面)。中身は Shared の VillageSceneView(ウィジェットと共用)。
struct VillageHomeView: View {
    @EnvironmentObject private var game: GameViewModel
    let onTapTent: () -> Void
    let onTapShop: () -> Void
    let onTapGuild: () -> Void

    var body: some View {
        VillageSceneView(
            data: game.data,
            layout: .portrait,
            partyHeightRatio: 0.16,   // ホームではキャラを大きく見せる
            onTapTent: onTapTent,
            onTapShop: onTapShop,
            onTapGuild: onTapGuild
        )
    }
}
