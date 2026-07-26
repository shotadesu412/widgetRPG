import SwiftUI

/// ホームの村シーン。中身は Shared の VillageSceneView(ウィジェットと共用)。
/// ここではタップ処理だけを渡す。
struct VillageHomeView: View {
    @EnvironmentObject private var game: GameViewModel
    let onTapTent: () -> Void
    let onTapShop: () -> Void
    let onTapGuild: () -> Void

    var body: some View {
        VillageSceneView(
            data: game.data,
            onTapTent: onTapTent,
            onTapShop: onTapShop,
            onTapGuild: onTapGuild
        )
        .aspectRatio(VillageSceneView.sceneAspect, contentMode: .fit)
    }
}
