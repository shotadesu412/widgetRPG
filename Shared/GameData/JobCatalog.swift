import Foundation

/// 全職の定義カタログ
enum JobCatalog {
    static let all: [Job] = normal + specialBattle + specialSupport

    // MARK: - 通常キャラ(進化: ひらがな → カタカナ → 漢字)

    static let normal: [Job] = [
        Job(id: "swordsman", category: .normal,
            stageNames: ["けんし", "パラディン", "剣豪"],
            element: .fire, slotCount: 3,
            baseStats: BaseStats(hp: 100, attack: 16, defense: 12, speed: 12, magic: 6),
            growth: BaseStats(hp: 12, attack: 3, defense: 2, speed: 1, magic: 1),
            speciality: "攻守のバランスに優れた前衛"),
        Job(id: "sage", category: .normal,
            stageNames: ["けんじゃ", "セージ", "大賢者"],
            element: .water, slotCount: 4,
            baseStats: BaseStats(hp: 80, attack: 8, defense: 10, speed: 10, magic: 20),
            growth: BaseStats(hp: 8, attack: 1, defense: 2, speed: 1, magic: 4),
            speciality: "回復と魔法を使い分ける後衛"),
        Job(id: "berserker", category: .normal,
            stageNames: ["きょうせんし", "バーサーカー", "修羅"],
            element: .fire, slotCount: 3,
            baseStats: BaseStats(hp: 130, attack: 24, defense: 6, speed: 10, magic: 2),
            growth: BaseStats(hp: 16, attack: 4, defense: 1, speed: 1, magic: 0),
            speciality: "防御を捨てた圧倒的火力"),
        Job(id: "mage", category: .normal,
            stageNames: ["まほうつかい", "ウィザード", "大魔導士"],
            element: .electric, slotCount: 3,
            baseStats: BaseStats(hp: 70, attack: 6, defense: 8, speed: 11, magic: 24),
            growth: BaseStats(hp: 7, attack: 1, defense: 1, speed: 1, magic: 5),
            speciality: "属性魔法による全体攻撃が得意"),
        Job(id: "archer", category: .normal,
            stageNames: ["ゆみつかい", "アーチャー", "弓聖"],
            element: .electric, slotCount: 3,
            baseStats: BaseStats(hp: 85, attack: 18, defense: 8, speed: 16, magic: 6),
            growth: BaseStats(hp: 9, attack: 3, defense: 1, speed: 2, magic: 1),
            speciality: "先手を取りやすい遠距離アタッカー"),
        Job(id: "monk", category: .normal,
            stageNames: ["ぶじゅつか", "モンク", "拳聖"],
            element: .fire, slotCount: 4,
            baseStats: BaseStats(hp: 110, attack: 17, defense: 10, speed: 14, magic: 4),
            growth: BaseStats(hp: 12, attack: 3, defense: 2, speed: 2, magic: 0),
            speciality: "手数で押す格闘家。スロット4つ"),
        Job(id: "oni", category: .normal,
            stageNames: ["おに", "ラセツ", "鬼神"],
            element: .dark, slotCount: 3,
            baseStats: BaseStats(hp: 140, attack: 22, defense: 14, speed: 8, magic: 6),
            growth: BaseStats(hp: 15, attack: 4, defense: 2, speed: 1, magic: 1),
            speciality: "高い体力と攻撃力を併せ持つ"),
        Job(id: "samurai", category: .normal,
            stageNames: ["さむらい", "ムシャ", "侍大将"],
            element: .fire, slotCount: 3,
            baseStats: BaseStats(hp: 105, attack: 20, defense: 11, speed: 13, magic: 4),
            growth: BaseStats(hp: 11, attack: 4, defense: 2, speed: 1, magic: 0),
            speciality: "一撃の重さに秀でた剣客"),
        Job(id: "ninja", category: .normal,
            stageNames: ["しのび", "ニンジャ", "上忍"],
            element: .dark, slotCount: 4,
            baseStats: BaseStats(hp: 80, attack: 15, defense: 7, speed: 22, magic: 8),
            growth: BaseStats(hp: 8, attack: 2, defense: 1, speed: 3, magic: 1),
            speciality: "最速で行動する俊足キャラ"),
        Job(id: "assassin", category: .normal,
            stageNames: ["あんさつしゃ", "アサシン", "暗殺王"],
            element: .dark, slotCount: 3,
            baseStats: BaseStats(hp: 75, attack: 21, defense: 6, speed: 19, magic: 6),
            growth: BaseStats(hp: 8, attack: 4, defense: 1, speed: 2, magic: 1),
            speciality: "急所を突く高火力・低耐久"),
    ]

    // MARK: - 特殊戦闘キャラ(進化数が少ない代わりに特殊効果)

    static let specialBattle: [Job] = [
        Job(id: "slot_machine", category: .specialBattle,
            stageNames: ["スロットマシン", "ジャックポット"],
            element: .electric, slotCount: 4,
            baseStats: BaseStats(hp: 95, attack: 14, defense: 10, speed: 12, magic: 12),
            growth: BaseStats(hp: 10, attack: 2, defense: 2, speed: 1, magic: 2),
            speciality: "必殺技がない代わりにスロット一巡でランダムな効果が発動"),
        Job(id: "beast_master", category: .specialBattle,
            stageNames: ["けものつかい", "ビーストマスター"],
            element: .fire, slotCount: 3,
            baseStats: BaseStats(hp: 100, attack: 14, defense: 10, speed: 12, magic: 10),
            growth: BaseStats(hp: 10, attack: 2, defense: 2, speed: 1, magic: 2),
            speciality: "オトモ強化スキルを多く持つ"),
        Job(id: "time_keeper", category: .specialBattle,
            stageNames: ["タイムキーパー", "クロノマスター"],
            element: .water, slotCount: 3,
            baseStats: BaseStats(hp: 85, attack: 10, defense: 10, speed: 15, magic: 16),
            growth: BaseStats(hp: 9, attack: 1, defense: 2, speed: 2, magic: 3),
            speciality: "他キャラのスロットに干渉して行動を操る"),
        Job(id: "zombie", category: .specialBattle,
            stageNames: ["ゾンビ", "グール"],
            element: .dark, slotCount: 3,
            baseStats: BaseStats(hp: 150, attack: 16, defense: 8, speed: 6, magic: 2),
            growth: BaseStats(hp: 18, attack: 3, defense: 1, speed: 0, magic: 0),
            speciality: "倒れても確率で復活する"),
    ]

    // MARK: - 特殊支援キャラ(編成してダンジョン潜入で特殊効果)

    static let specialSupport: [Job] = [
        Job(id: "monster_tamer", category: .specialSupport,
            stageNames: ["モンスターテイマー"],
            element: .water, slotCount: 3,
            baseStats: supportStats,
            growth: supportGrowth,
            speciality: "編成して潜入すると卵の孵化時間短縮・オトモ経験値アップ"),
        Job(id: "professor", category: .specialSupport,
            stageNames: ["はかせ", "博士"],
            element: .electric, slotCount: 3,
            baseStats: supportStats,
            growth: supportGrowth,
            speciality: "研究による支援効果(効果は検討中)"),
        Job(id: "explorer", category: .specialSupport,
            stageNames: ["たんけんか", "探検家"],
            element: .fire, slotCount: 3,
            baseStats: supportStats,
            growth: supportGrowth,
            speciality: "編成時、武器の発見率アップ"),
        Job(id: "miner", category: .specialSupport,
            stageNames: ["たんこうふ", "炭鉱夫"],
            element: .fire, slotCount: 3,
            baseStats: supportStats,
            growth: supportGrowth,
            speciality: "編成時、素材の発見率アップ"),
        Job(id: "thief", category: .specialSupport,
            stageNames: ["とうぞく", "盗賊"],
            element: .dark, slotCount: 3,
            baseStats: supportStats,
            growth: supportGrowth,
            speciality: "編成時、取得コインアップ"),
        Job(id: "trainer", category: .specialSupport,
            stageNames: ["トレーナー"],
            element: .water, slotCount: 3,
            baseStats: supportStats,
            growth: supportGrowth,
            speciality: "編成時、キャラの経験値アップ"),
    ]

    private static let supportStats = BaseStats(hp: 60, attack: 8, defense: 6, speed: 10, magic: 6)
    private static let supportGrowth = BaseStats(hp: 6, attack: 1, defense: 1, speed: 1, magic: 1)

    static func job(id: String) -> Job {
        all.first { $0.id == id } ?? normal[0]
    }

    /// レベルアップ・進化で習得するスキルの見本(本実装ではテーブル化する)
    static func starterSkills(for job: Job) -> [Skill] {
        switch job.category {
        case .normal, .specialBattle:
            [Skill(name: "\(job.stageNames[0])の一撃", kind: .attack, power: 120, element: job.element)]
        case .specialSupport:
            [Skill(name: "応急手当", kind: .heal, power: 60, element: nil)]
        }
    }

    static func starterUltimate(for job: Job) -> UltimateSkill? {
        // スロットマシンは必殺技を持たない
        if job.id == "slot_machine" { return nil }
        return UltimateSkill(name: "\(job.stageNames.last ?? "")の極意",
                             kind: job.element == .water ? .heal : .damageAll,
                             power: 250, requiredLoops: 3)
    }
}
