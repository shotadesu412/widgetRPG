import Foundation

/// スカウトのレア度区分
enum ScoutTier: String, CaseIterable, Identifiable, Hashable {
    case basic, special, rare
    var id: String { rawValue }

    var label: String {
        switch self {
        case .basic: "基本"
        case .special: "特殊"
        case .rare: "レア"
        }
    }

    /// 集め切りを速くする貪欲方策の優先度(小さいほど優先)
    var priority: Int {
        switch self {
        case .rare: 0
        case .special: 1
        case .basic: 2
        }
    }
}

struct GachaCharacter: Identifiable, Hashable {
    let id: String   // 表示名を兼ねる
    let tier: ScoutTier
}

/// ギルド・スカウトの各種確率設定
struct GachaConfig: Equatable {
    /// カテゴリ出現率(%)
    var appearance: [ScoutTier: Double] = [.basic: 70, .special: 25, .rare: 5]
    /// 初期スカウト率(%)
    var initRate: [ScoutTier: Double] = [.basic: 25, .special: 10, .rare: 30]
    /// 失敗ごとのスカウト率上昇(%)
    var failStep: [ScoutTier: Double] = [.basic: 5, .special: 4, .rare: 0]
    var visitorsPerDay = 3
}

/// スカウトの純粋ロジック。手動プレイとモンテカルロ期待値の両方から使う。
enum GachaCore {
    /// 標準のキャラ一覧
    static let roster: [GachaCharacter] = {
        let basic = ["剣士", "賢者", "狂戦士", "魔法使い", "アーチャー", "武術家", "鬼", "侍", "忍者", "アサシン"]
        let special = ["スロットマシン", "タイムキーパー", "獣使い", "ゾンビ"]
        let rare = ["天使", "悪魔"]
        return basic.map { GachaCharacter(id: $0, tier: .basic) }
            + special.map { GachaCharacter(id: $0, tier: .special) }
            + rare.map { GachaCharacter(id: $0, tier: .rare) }
    }()

    static let countInTier: [ScoutTier: Int] = Dictionary(
        grouping: roster, by: \.tier
    ).mapValues(\.count)

    static func scoutRate(_ tier: ScoutTier, fails: Int, config: GachaConfig) -> Double {
        let base = (config.initRate[tier] ?? 0) + (config.failStep[tier] ?? 0) * Double(fails)
        return min(1.0, max(0.0, base / 100.0))
    }

    /// 現在の所持状況を踏まえた1人あたりの出現重み。
    /// 排出済みキャラは出現しない。排出済みキャラの分の出現率は
    /// 基本70%:特殊25%:レア5% の比率で残りのキャラに再分配される。
    static func appearanceWeight(_ c: GachaCharacter, owned: Set<String>, config: GachaConfig) -> Double {
        if owned.contains(c.id) { return 0 }
        let unownedInTier = roster.filter { $0.tier == c.tier && !owned.contains($0.id) }.count
        guard unownedInTier > 0 else { return 0 }
        // 未所持キャラが残っているティアの基本レート合計(正規化用)
        var activeWeight: Double = 0
        for tier in ScoutTier.allCases {
            if roster.contains(where: { $0.tier == tier && !owned.contains($0.id) }) {
                activeWeight += config.appearance[tier] ?? 0
            }
        }
        guard activeWeight > 0 else { return 0 }
        let tierRate = (config.appearance[c.tier] ?? 0) / activeWeight
        return tierRate / Double(unownedInTier)
    }

    /// 重み付きで来訪者を1人抽選
    static func drawVisitor(owned: Set<String>, config: GachaConfig,
                            using rng: inout some RandomNumberGenerator) -> GachaCharacter {
        let weights = roster.map { appearanceWeight($0, owned: owned, config: config) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return roster.randomElement(using: &rng)! }
        var x = Double.random(in: 0..<total, using: &rng)
        for (i, w) in weights.enumerated() {
            x -= w
            if x < 0 { return roster[i] }
        }
        return roster[roster.count - 1]
    }

    /// 未所持の来訪者から方策に沿って1人選ぶ(レア>特殊>基本、同カテゴリは成功率の高い順)
    static func pick(from candidates: [GachaCharacter], fails: [String: Int], config: GachaConfig) -> GachaCharacter? {
        candidates.min { a, b in
            if a.tier.priority != b.tier.priority { return a.tier.priority < b.tier.priority }
            return scoutRate(a.tier, fails: fails[a.id] ?? 0, config: config)
                 > scoutRate(b.tier, fails: fails[b.id] ?? 0, config: config)
        }
    }

    /// 全員そろうまで1回シミュレートし、必要日数とカテゴリ別完了日を返す
    static func runToCompletion(config: GachaConfig,
                                using rng: inout some RandomNumberGenerator) -> (days: Int, tierDone: [ScoutTier: Int]) {
        var owned = Set<String>()
        var fails = [String: Int]()
        var day = 0
        var cnt: [ScoutTier: Int] = [.basic: 0, .special: 0, .rare: 0]
        var tierDone: [ScoutTier: Int] = [:]
        let total = countInTier

        while owned.count < roster.count {
            day += 1
            if day > 200_000 { break }
            var visitors: [GachaCharacter] = []
            for _ in 0..<config.visitorsPerDay {
                visitors.append(drawVisitor(owned: owned, config: config, using: &rng))
            }
            let candidates = Array(Set(visitors)).filter { !owned.contains($0.id) }
            guard let pick = pick(from: candidates, fails: fails, config: config) else { continue }
            let rate = scoutRate(pick.tier, fails: fails[pick.id] ?? 0, config: config)
            if Double.random(in: 0..<1, using: &rng) < rate {
                owned.insert(pick.id)
                cnt[pick.tier, default: 0] += 1
                if cnt[pick.tier] == total[pick.tier] { tierDone[pick.tier] = day }
            } else {
                fails[pick.id, default: 0] += 1
            }
        }
        return (day, tierDone)
    }
}

/// モンテカルロ結果
struct GachaStats {
    var trials: Int
    var mean: Double
    var median: Int
    var p90: Int
    var p95: Int
    var minDay: Int
    var maxDay: Int
    var tierDone: [ScoutTier: Double]

    static func compute(config: GachaConfig, trials: Int) -> GachaStats {
        var rng = SystemRandomNumberGenerator()
        var days: [Int] = []
        days.reserveCapacity(trials)
        var tierSum: [ScoutTier: Int] = [.basic: 0, .special: 0, .rare: 0]
        for _ in 0..<trials {
            let r = GachaCore.runToCompletion(config: config, using: &rng)
            days.append(r.days)
            for t in ScoutTier.allCases { tierSum[t, default: 0] += r.tierDone[t] ?? r.days }
        }
        days.sort()
        let n = max(days.count, 1)
        let mean = Double(days.reduce(0, +)) / Double(n)
        func pct(_ p: Double) -> Int { days[min(n - 1, Int(Double(n) * p))] }
        return GachaStats(
            trials: trials,
            mean: mean,
            median: pct(0.5),
            p90: pct(0.9),
            p95: pct(0.95),
            minDay: days.first ?? 0,
            maxDay: days.last ?? 0,
            tierDone: tierSum.mapValues { Double($0) / Double(n) }
        )
    }
}
