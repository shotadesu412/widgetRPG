import Foundation

enum DungeonCatalog {
    static let all: [Dungeon] = mainDungeons + sideDungeons

    /// メインダンジョン: 4系統 × 15マップ。順に攻略する。
    /// 最終ボスの推奨レベル: ルルイエ30 / 無貌45 / 混沌65 / 禁書75
    static let mainDungeons: [Dungeon] = {
        var list: [Dungeon] = []
        for arc in MainArc.allCases {
            for map in 1...MainArc.mapsPerArc {
                let isLast = map == MainArc.mapsPerArc
                list.append(Dungeon(
                    id: "main_\(arc.rawValue)_\(map)",
                    name: "\(arc.areaName) 第\(map)層",
                    kind: .main,
                    arc: arc,
                    mapIndex: map,
                    recommendedLevel: recommendedLevel(arc: arc, map: map),
                    // 序盤のマップほど発見確率が高く、発見も早い
                    bossFindChancePerMinute: max(0.01, 0.10 - Double(map) * 0.005),
                    guaranteedFindMinutes: 10 + map * 4,
                    bossEnemyID: isLast ? arc.bossEnemyID : midBossID(arc: arc, map: map),
                    // 最終ボスは単騎で登場(調整基準のヒュドラ戦と同条件)
                    mobEnemyIDs: isLast ? [] : ["goblin", "ogre", "demon"]
                ))
            }
        }
        return list
    }()

    /// 系統ごとの推奨レベル(最終層が 30/45/65/75 になるよう配分)
    static func recommendedLevel(arc: MainArc, map: Int) -> Int {
        switch arc {
        case .cthulhu: map * 2                                        // 2 → 30
        case .nyarlathotep: 30 + map                                  // 31 → 45
        case .azathoth: 45 + Int((Double(map) * 20.0 / 15.0).rounded()) // 46 → 65
        case .necronomicon: 65 + Int((Double(map) * 10.0 / 15.0).rounded()) // 66 → 75
        }
    }

    private static func midBossID(arc: MainArc, map: Int) -> String {
        let pool = ["golem", "cyclops", "ogre", "giant", "demon", "angel", "dragon_enemy"]
        return pool[map % pool.count]
    }

    /// 属性石の祠: 5属性それぞれの石がドロップする。
    /// 第一進化(Lv25)の手前でクリアできる難易度(推奨Lv20)
    static let stoneShrines: [Dungeon] = {
        let bosses: [Element: String] = [
            .fire: "ogre", .water: "golem", .electric: "angel",
            .dark: "demon", .wind: "wyvern",
        ]
        return Element.allCases.map { element in
            Dungeon(id: "shrine_\(element.rawValue)",
                    name: "\(element.label)の祠", kind: .stone, arc: nil, mapIndex: nil,
                    recommendedLevel: 20, bossFindChancePerMinute: 0.08, guaranteedFindMinutes: 30,
                    bossEnemyID: bosses[element] ?? "golem",
                    mobEnemyIDs: [], element: element)
        }
    }()

    /// サブダンジョン(卵・装備・素材・イベント・カオス)
    static let sideDungeons: [Dungeon] = stoneShrines + [
        Dungeon(id: "egg_random", name: "始まりの巣", kind: .egg, arc: nil, mapIndex: nil,
                recommendedLevel: 2, bossFindChancePerMinute: 0.12, guaranteedFindMinutes: 10,
                bossEnemyID: "goblin", mobEnemyIDs: ["goblin"]),
        Dungeon(id: "egg_legendary", name: "伝説の霊峰", kind: .egg, arc: nil, mapIndex: nil,
                recommendedLevel: 50, bossFindChancePerMinute: 0.03, guaranteedFindMinutes: 60,
                bossEnemyID: "dragon_enemy", mobEnemyIDs: ["ogre", "giant"]),
        Dungeon(id: "equip_random", name: "錆びた武器庫", kind: .equipment, arc: nil, mapIndex: nil,
                recommendedLevel: 6, bossFindChancePerMinute: 0.10, guaranteedFindMinutes: 15,
                bossEnemyID: "golem", mobEnemyIDs: ["goblin", "golem"]),
        Dungeon(id: "equip_element", name: "属性の祭壇", kind: .equipment, arc: nil, mapIndex: nil,
                recommendedLevel: 30, bossFindChancePerMinute: 0.05, guaranteedFindMinutes: 40,
                bossEnemyID: "angel", mobEnemyIDs: ["angel", "demon"]),
        Dungeon(id: "material_mine", name: "古びた坑道", kind: .material, arc: nil, mapIndex: nil,
                recommendedLevel: 4, bossFindChancePerMinute: 0.10, guaranteedFindMinutes: 12,
                bossEnemyID: "golem", mobEnemyIDs: ["goblin"]),
        Dungeon(id: "event_raid", name: "ゲリラレイド", kind: .event, arc: nil, mapIndex: nil,
                recommendedLevel: 35, bossFindChancePerMinute: 0.20, guaranteedFindMinutes: 8,
                bossEnemyID: "dragon_enemy", mobEnemyIDs: ["demon", "angel"]),
        // カオス: エンドレス。発見時間は青天井(保証なし)
        Dungeon(id: "chaos", name: "混沌の狭間", kind: .chaos, arc: nil, mapIndex: nil,
                recommendedLevel: 70, bossFindChancePerMinute: 0.04, guaranteedFindMinutes: nil,
                bossEnemyID: "dragon_enemy",
                mobEnemyIDs: ["angel", "demon", "golem", "cyclops", "ogre", "giant"]),
    ]

    static func dungeon(id: String) -> Dungeon {
        all.first { $0.id == id } ?? sideDungeons[0]
    }

    /// メイン進行度(系統ごとの攻略済みマップ数)に応じて挑戦可能なダンジョン一覧
    static func unlocked(mainProgress: [String: Int]) -> [Dungeon] {
        let totalCleared = mainProgress.values.reduce(0, +)
        return all.filter { dungeon in
            switch dungeon.kind {
            case .main:
                guard let arc = dungeon.arc, let map = dungeon.mapIndex else { return false }
                let cleared = mainProgress[arc.rawValue] ?? 0
                return map == cleared + 1 // 次のマップだけ挑戦可
            case .stone:
                // 進化(Lv25)を意識し始める頃に解禁
                return totalCleared >= 5
            case .egg:
                return dungeon.id == "egg_random" || totalCleared >= 10
            case .equipment:
                return dungeon.id == "equip_random" || totalCleared >= 15
            case .material:
                return true
            case .event:
                return false // ゲリラ開催時のみ(イベントシステムはTODO)
            case .chaos:
                return totalCleared >= MainArc.mapsPerArc // 1系統クリアで解禁(仮)
            }
        }
    }
}
