import SwiftUI

/// ボス戦(手動戦闘)。セーブデータのパーティで ATB バトルを行う
struct BossBattleView: View {
    @EnvironmentObject private var game: GameViewModel
    @Environment(\.dismiss) private var dismiss

    let dungeon: Dungeon
    @StateObject private var engine = BattleEngine()
    @State private var started = false

    var body: some View {
        BattleSceneView(
            engine: engine,
            title: dungeon.name,
            onExit: { dismiss() },
            onFinish: { result in
                game.completeRun(victory: result == .victory)
                dismiss()
            }
        )
        .onAppear {
            guard !started else { return }
            started = true
            let fresh = BattleEngine.make(
                data: game.data,
                bossEnemyID: dungeon.bossEnemyID,
                mobEnemyIDs: dungeon.mobEnemyIDs
            )
            engine.allies = fresh.allies
            engine.enemies = fresh.enemies
            engine.log = fresh.log
        }
    }
}
