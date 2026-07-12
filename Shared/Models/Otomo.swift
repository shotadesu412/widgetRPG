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
    /// (旧仕様の名残。孵化時間は卵の種類で決まる)
    let baseHatchSeconds: TimeInterval
}

/// 個体値(オトモのみ)。各ステータスに±10%のブレ
struct IndividualValues: Codable, Hashable {
    var hp = 0
    var attack = 0
    var defense = 0
    var speed = 0
    var magic = 0

    var total: Int { hp + attack + defense + speed + magic }
    var average: Double { Double(total) / 5.0 }

    func applied(to stats: BaseStats) -> BaseStats {
        BaseStats(
            hp: Int(Double(stats.hp) * (1.0 + Double(hp) / 100)),
            attack: Int(Double(stats.attack) * (1.0 + Double(attack) / 100)),
            defense: Int(Double(stats.defense) * (1.0 + Double(defense) / 100)),
            speed: Int(Double(stats.speed) * (1.0 + Double(speed) / 100)),
            magic: Int(Double(stats.magic) * (1.0 + Double(magic) / 100))
        )
    }

    /// 星1・2は完全ランダム。星3は個体値の合計が+10%以上(仕様確定)。伝説の卵はさらに優遇
    static func roll(rarity: Rarity, favored: Bool) -> IndividualValues {
        let minTotal: Int? = rarity == .star3 ? (favored ? 25 : 10) : (favored ? 15 : nil)
        for _ in 0..<200 {
            let iv = IndividualValues(
                hp: Int.random(in: -10...10),
                attack: Int.random(in: -10...10),
                defense: Int.random(in: -10...10),
                speed: Int.random(in: -10...10),
                magic: Int.random(in: -10...10)
            )
            if let minTotal {
                if iv.total >= minTotal { return iv }
            } else {
                return iv
            }
        }
        return IndividualValues(hp: 10, attack: 10, defense: 10, speed: 10, magic: 10)
    }
}

/// オトモ。卵から生まれ、キャラ同様スロットを持ちランダムにスキルが付与される
struct Otomo: Identifiable, Codable, Hashable {
    var id = UUID()
    var speciesID: String
    var nickname: String?
    /// 星1〜3。星に応じて進化できる回数が異なる(星2=1回、星3=2回)
    var rarity: Rarity
    /// 個体値(オトモのみ導入)
    var ivs = IndividualValues()
    var stage = 0
    var level = 1
    var exp = 0
    var skills: [Skill] = []
    var ultimate: UltimateSkill? // 必殺技持ちは少なめ
    var slotCount = 3

    /// 次のレベルまでの必要経験値(キャラよりやや軽いカーブ)
    var expToNext: Int { Int(pow(Double(level), 1.5) * 16) }

    func species() -> OtomoSpecies { OtomoCatalog.species(id: speciesID) }

    var displayName: String { nickname ?? species().name }

    /// 星の数に応じた進化上限(星1=0回、星2=1回、星3=2回)
    var maxStage: Int { species().canEvolve ? rarity.rawValue - 1 : 0 }

    /// 進化可能か(キャラと同じレベル条件。素材は不要)
    var canEvolve: Bool { stage < maxStage && level >= (stage + 1) * 10 }

    var grownStats: BaseStats {
        let base = species().baseStats.scaled(by: 1.0 + Double(rarity.rawValue - 1) * 0.25)
        let leveled = (base + base.scaled(by: Double(level - 1) * 0.08)).scaled(by: 1.0 + Double(stage) * 0.4)
        return ivs.applied(to: leveled)
    }
}

// MARK: - 卵

/// 卵の種類。色や形(=種類)で強さの傾向と孵化時間が分かる。星は孵化するまで分からない
enum EggGrade: String, Codable, CaseIterable, Identifiable {
    case normal    // 普通の卵
    case uncommon  // 珍しい卵
    case legendary // 伝説の卵(個体値優遇)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: "普通の卵"
        case .uncommon: "珍しい卵"
        case .legendary: "伝説の卵"
        }
    }

    /// 孵化時間(普通2時間 / 珍しい5時間 / 伝説10時間)
    var hatchSeconds: TimeInterval {
        switch self {
        case .normal: 2 * 3600
        case .uncommon: 5 * 3600
        case .legendary: 10 * 3600
        }
    }

    /// 星の抽選率(%)
    var starRates: [(rarity: Rarity, rate: Double)] {
        switch self {
        case .normal: [(.star1, 90), (.star2, 9.5), (.star3, 0.5)]
        case .uncommon: [(.star1, 20), (.star2, 78), (.star3, 2)]
        case .legendary: [(.star2, 50), (.star3, 50)]
        }
    }

    /// 伝説の卵で星3を引いたとき、伝説キャラになる確率(%)。外れは通常キャラの星3
    static let legendarySpeciesChanceInStar3 = 30.0

    func rollRarity() -> Rarity {
        var x = Double.random(in: 0..<100)
        for (rarity, rate) in starRates {
            x -= rate
            if x < 0 { return rarity }
        }
        return .star1
    }
}

/// 卵。孵化は自動ではなく、自分で孵化器にセットして開始する
struct Egg: Identifiable, Codable, Hashable {
    var id = UUID()
    var grade: EggGrade
    /// ボスドロップなど中身が確定している卵(神話キャラ等)
    var fixedSpeciesID: String?
    var obtainedAt: Date
    /// 孵化セットした時刻(nil = 未セット)
    var incubationStartedAt: Date?
    /// セット時に確定する孵化所要時間(テイマー編成で短縮)
    var hatchSeconds: TimeInterval = 0

    var isIncubating: Bool { incubationStartedAt != nil }

    func progress(now: Date = Date()) -> Double {
        guard let start = incubationStartedAt else { return 0 }
        return min(1.0, now.timeIntervalSince(start) / max(hatchSeconds, 1))
    }

    /// ひび割れ段階 0(無傷)〜3(孵化寸前)。ウィジェットはこれで孵化状況を伝える
    func crackStage(now: Date = Date()) -> Int {
        let p = progress(now: now)
        if p >= 1.0 { return 3 }
        if p >= 0.7 { return 2 }
        if p >= 0.35 { return 1 }
        return 0
    }

    func isReady(now: Date = Date()) -> Bool { isIncubating && progress(now: now) >= 1.0 }

    func statusText(now: Date = Date()) -> String {
        guard isIncubating else { return "孵化を待っている(セットで孵化開始)" }
        switch crackStage(now: now) {
        case 0: return "静かに眠っている……"
        case 1: return "小さなひびが入った"
        case 2: return "ひびが広がり、中で何かが動いている"
        default: return "今にも生まれそうだ!"
        }
    }
}
