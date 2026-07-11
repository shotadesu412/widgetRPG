import Foundation

enum DungeonCatalog {
    static let all: [Dungeon] = mainDungeons + sideDungeons

    /// メインダンジョン: 4系統 × 15マップ。順に攻略する
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
                    recommendedLevel: map * 3 + arcOffset(arc),
                    // 序盤のマップほど発見確率が高く、発見も早い
                    bossFindChancePerMinute: max(0.01, 0.10 - Double(map) * 0.005),
                    guaranteedFindMinutes: 10 + map * 4,
                    bossEnemyID: isLast ? arc.bossEnemyID : midBossID(arc: arc, map: map),
                    mobEnemyIDs: ["goblin", "ogre", "demon"]
                ))
            }
        }
        return list
    }()

    private static func arcOffset(_ arc: MainArc) -> Int {
        switch arc {
        case .cthulhu: 0
        case .nyarlathotep: 20
        case .azathoth: 40
        case .necronomicon: 60
        }
    }

    private static func midBossID(arc: MainArc, map: Int) -> String {
        let pool = ["golem", "cyclops", "ogre", "giant", "demon", "angel", "dragon_enemy"]
        return pool[map % pool.count]
    }

    /// サブダンジョン(卵・装備・素材・イベント・カオス)
    static let sideDungeons: [Dungeon] = [
        Dungeon(id: "egg_random", name: "始まりの巣", kind: .egg, arc: nil, mapIndex: nil,
                recommendedLevel: 1, bossFindChancePerMinute: 0.12, guaranteedFindMinutes: 10,
                bossEnemyID: "goblin", mobEnemyIDs: ["goblin"]),
        Dungeon(id: "egg_legendary", name: "伝説の霊峰", kind: .egg, arc: nil, mapIndex: nil,
                recommendedLevel: 40, bossFindChancePerMinute: 0.03, guaranteedFindMinutes: 60,
                bossEnemyID: "dragon_enemy", mobEnemyIDs: ["ogre", "giant"]),
        Dungeon(id: "equip_random", name: "錆びた武器庫", kind: .equipment, arc: nil, mapIndex: nil,
                recommendedLevel: 5, bossFindChancePerMinute: 0.10, guaranteedFindMinutes: 15,
                bossEnemyID: "golem", mobEnemyIDs: ["goblin", "golem"]),
        Dungeon(id: "equip_element", name: "属性の祭壇", kind: .equipment, arc: nil, mapIndex: nil,
                recommendedLevel: 25, bossFindChancePerMinute: 0.05, guaranteedFindMinutes: 40,
                bossEnemyID: "angel", mobEnemyIDs: ["angel", "demon"]),
        Dungeon(id: "material_mine", name: "古びた坑道", kind: .material, arc: nil, mapIndex: nil,
                recommendedLevel: 3, bossFindChancePerMinute: 0.10, guaranteedFindMinutes: 12,
                bossEnemyID: "golem", mobEnemyIDs: ["goblin"]),
        Dungeon(id: "event_raid", name: "ゲリラレイド", kind: .event, arc: nil, mapIndex: nil,
                recommendedLevel: 20, bossFindChancePerMinute: 0.20, guaranteedFindMinutes: 8,
                bossEnemyID: "dragon_enemy", mobEnemyIDs: ["demon", "angel"]),
        // カオス: エンドレス。発見時間は青天井(保証なし)
        Dungeon(id: "chaos", name: "混沌の狭間", kind: .chaos, arc: nil, mapIndex: nil,
                recommendedLevel: 50, bossFindChancePerMinute: 0.04, guaranteedFindMinutes: nil,
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
