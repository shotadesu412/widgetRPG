import Foundation

/// 職の分類
enum JobCategory: String, Codable, CaseIterable {
    case normal        // 通常キャラ(戦闘用、得意分野あり)
    case specialBattle // 特殊戦闘キャラ(進化数が少ない代わりに特殊効果)
    case specialSupport // 特殊キャラ(ステータス低め、編成でダンジョン特殊効果)

    var label: String {
        switch self {
        case .normal: "通常"
        case .specialBattle: "特殊戦闘"
        case .specialSupport: "特殊支援"
        }
    }
}

/// 職の定義。進化命名規則: ひらがな → カタカナ → 漢字(例: けんし→パラディン→剣豪)
struct Job: Identifiable, Codable, Hashable {
    let id: String
    let category: JobCategory
    /// 進化段階ごとの名前。特殊キャラは要素数が少ない(=進化回数が少ない)
    let stageNames: [String]
    let element: Element
    /// スロット数(3か4、キャラによって変動)
    let slotCount: Int
    let baseStats: BaseStats
    /// レベルアップごとの成長量
    let growth: BaseStats
    /// 得意分野・特殊効果の説明
    let speciality: String

    var maxStage: Int { stageNames.count - 1 }

    func name(atStage stage: Int) -> String {
        stageNames[min(max(stage, 0), stageNames.count - 1)]
    }
}

/// 所持キャラクター
struct PlayerCharacter: Identifiable, Codable, Hashable {
    var id = UUID()
    var jobID: String
    /// 進化段階(0開始)
    var stage = 0
    var level = 1
    var exp = 0
    /// 習得済みスキル(進化・レベルアップで習得)
    var learnedSkills: [Skill] = []
    /// スロットへの配置(要素数 = スロット数、nil = 空きスロット = 通常攻撃)
    /// 武器スキルが付与された位置は武器側が優先される
    var placedSkills: [Skill?] = []
    var ultimate: UltimateSkill?
    var weaponID: UUID?
    /// 防具は1個のみ装備できる
    var armorID: UUID?

    /// 次のレベルまでの必要経験値。
    /// メイン攻略ペース(最終ボス推奨Lv: 30/45/65/75)に合わせた上振れカーブ
    var expToNext: Int { Int(pow(Double(level), 1.5) * 20) }

    func job() -> Job { JobCatalog.job(id: jobID) }

    var displayName: String { job().name(atStage: stage) }

    /// レベルと進化段階を反映した素のステータス。
    /// 進化1段階ごとに+25%(最終進化で1.5倍)。
    /// アンカー: 剣士 Lv50・最終進化 = HP600/攻200/防150/速100/魔30
    /// (戦闘調整シミュレーターの基準値)
    var grownStats: BaseStats {
        let job = job()
        let leveled = job.baseStats + job.growth.scaled(by: Double(level - 1))
        return leveled.scaled(by: 1.0 + Double(stage) * 0.25)
    }

    var canEvolve: Bool {
        stage < job().maxStage && level >= (stage + 1) * 10
    }
}
