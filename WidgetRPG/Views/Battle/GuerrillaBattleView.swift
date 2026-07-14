import SwiftUI

/// ゲリラクエスト(即ボス戦)。ダンジョン潜入なしでその場で高難易度ボスと戦う。
/// 敗北しても期限内なら何度でも再挑戦できる
struct GuerrillaBattleView: View {
    @EnvironmentObject private var game: GameViewModel
    @Environment(\.dismiss) private var dismiss

    let quest: GuerrillaQuest
    @StateObject private var engine = BattleEngine()
    @State private var started = false

    var body: some View {
        BattleSceneView(
            engine: engine,
            title: "ゲリラ討伐: \(quest.boss().name) Lv\(quest.level)",
            onExit: { dismiss() },
            onFinish: { result in
                game.settleGuerrilla(victory: result == .victory)
                dismiss()
            },
            finishLabel: { result in
                result == .victory
                    ? "報酬を受け取る(コイン\(quest.rewardCoins)+素材\(quest.rewardMaterials)+卵)"
                    : "撤退する(期限内なら再挑戦できる)"
            }
        )
        .onAppear {
            guard !started else { return }
            started = true
            let fresh = BattleEngine.make(
                data: game.data,
                bossEnemyID: quest.bossEnemyID,
                mobEnemyIDs: [],
                level: quest.level
            )
            engine.allies = fresh.allies
            engine.enemies = fresh.enemies
            engine.log = fresh.log
        }
    }
}
