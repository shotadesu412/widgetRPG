import Foundation

enum OtomoCategory: String, Codable, CaseIterable, Identifiable {
    case special   // 特殊(風船、スライム)
    case ground    // 地上
    case aquatic   // 水生生物
    case bird      // 鳥
    case insect    // 虫
    case legendary // 伝説(進化しない)
    case mythic    // 神話(メインダンジョン最終ボスのドロップ)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .special: "特殊"
        case .ground: "地上"
        case .aquatic: "水生"
        case .bird: "鳥"
        case .insect: "虫"
        case .legendary: "伝説"
        case .mythic: "神話"
        }
    }
}

struct OtomoSpecies: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: OtomoCategory
    let element: Element
    let baseStats: BaseStats
    /// 伝説・神話は進化しない
    var canEvolve: Bool { category != .legendary && category != .mythic }
    /// 孵化の基準時間(秒)。強い種族ほど長い
    let baseHatchSeconds: TimeInterval
}

/// オトモ。卵から生まれ、キャラ同様スロットを持ちランダムにスキルが付与される
struct Otomo: Identifiable, Codable, Hashable {
    var id = UUID()
    var speciesID: String
    var nickname: String?
    /// 星1〜3。星に応じて進化できる回数が異なる(伝説・神話は星3固定)
    var rarity: Rarity
    var stage = 0
    var level = 1
    var exp = 0
    var skills: [Skill] = []
    var ultimate: UltimateSkill? // 必殺技持ちは少なめ
    var slotCount = 3

    var expToNext: Int { level * 80 }

    func species() -> OtomoSpecies { OtomoCatalog.species(id: speciesID) }

    var displayName: String { nickname ?? species().name }

    /// 星の数に応じた進化上限
    var maxStage: Int { species().canEvolve ? rarity.rawValue - 1 : 0 }

    var grownStats: BaseStats {
        let base = species().baseStats.scaled(by: 1.0 + Double(rarity.rawValue - 1) * 0.25)
        return (base + base.scaled(by: Double(level - 1) * 0.08)).scaled(by: 1.0 + Double(stage) * 0.4)
    }
}

/// 卵。色や形で中身の強さ・種族の傾向が分かる。孵化時間は数字では見せない
struct Egg: Identifiable, Codable, Hashable {
    var id = UUID()
    var speciesID: String
    var rarity: Rarity
    var obtainedAt: Date
    var hatchSeconds: TimeInterval

    func progress(now: Date = Date()) -> Double {
        min(1.0, now.timeIntervalSince(obtainedAt) / max(hatchSeconds, 1))
    }

    /// ひび割れ段階 0(無傷)〜3(孵化寸前)。ウィジェットはこれで孵化状況を伝える
    func crackStage(now: Date = Date()) -> Int {
        let p = progress(now: now)
        if p >= 1.0 { return 3 }
        if p >= 0.7 { return 2 }
        if p >= 0.35 { return 1 }
        return 0
    }

    func isReady(now: Date = Date()) -> Bool { progress(now: now) >= 1.0 }

    func statusText(now: Date = Date()) -> String {
        switch crackStage(now: now) {
        case 0: "静かに眠っている……"
        case 1: "小さなひびが入った"
        case 2: "ひびが広がり、中で何かが動いている"
        default: "今にも生まれそうだ!"
        }
    }
}
