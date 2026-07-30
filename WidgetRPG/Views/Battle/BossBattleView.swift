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
                mobEnemyIDs: dungeon.mobEnemyIDs,
                level: dungeon.recommendedLevel
            )
            engine.allies = fresh.allies
            engine.enemies = fresh.enemies
            engine.log = fresh.log
            // スロットマシンのルーレットで得たコインは即座にセーブへ加算する
            engine.onGoldEarned = { amount in
                game.data.coins += amount
                game.save()
            }
            // 開戦時パッシブ(悪魔の魔力吸収・スロットマシンの初回抽選・ゾンビの復活設定)
            engine.applyBattleStart()
        }
    }
}
