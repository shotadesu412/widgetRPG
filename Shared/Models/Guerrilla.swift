import Foundation

/// ゲリラクエスト。ランダムな時間にホーム画面へ出現する高難易度の即時ボス戦。
/// ダンジョン潜入を挟まず、その場で挑戦できる。期限内なら何度でも再挑戦可
struct GuerrillaQuest: Codable, Hashable {
    var bossEnemyID: String
    /// ボスのスケーリングレベル(現在のメイン進行の推奨Lv+5=高難易度)
    var level: Int
    var expiresAt: Date

    func boss() -> Enemy { EnemyCatalog.enemy(id: bossEnemyID) }

    var isExpired: Bool { Date() >= expiresAt }

    /// 討伐報酬(高難易度ぶん豪華に)
    var rewardCoins: Int { level * 40 }
    var rewardMaterials: Int { level * 2 }
    /// 卵報酬: 30%で伝説、それ以外は珍しい卵
    static let legendaryEggChance = 0.3
}
