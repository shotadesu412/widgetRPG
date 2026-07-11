import Foundation

enum DungeonKind: String, Codable, CaseIterable, Identifiable {
    case main      // メイン: 各ボスごとに15マップ、順に攻略
    case egg       // 卵: 進行度で高難易度・強キャラの卵ダンジョン解禁
    case equipment // 装備: 進行度で武器種・属性ごとのダンジョン解禁
    case material  // 素材: 武器や拠点の強化素材
    case event     // イベント: ウィジェットにゲリラ表示されるレイド等
    case chaos     // カオス: エンドレス。装飾アイテムがレアドロップ

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: "メイン"
        case .egg: "卵"
        case .equipment: "装備"
        case .material: "素材"
        case .event: "イベント"
        case .chaos: "カオス"
        }
    }

    var symbolName: String {
        switch self {
        case .main: "crown.fill"
        case .egg: "oval.portrait.fill"
        case .equipment: "shield.lefthalf.filled"
        case .material: "hammer.fill"
        case .event: "exclamationmark.triangle.fill"
        case .chaos: "hurricane"
        }
    }
}

/// メインダンジョンの4系統(クトゥルフ神話の3神 + 魔導書)
enum MainArc: String, Codable, CaseIterable, Identifiable {
    case cthulhu, nyarlathotep, azathoth, necronomicon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cthulhu: "クトゥルフ"
        case .nyarlathotep: "ニャルラトホテプ"
        case .azathoth: "アザトース"
        case .necronomicon: "ネクロノミコン"
        }
    }

    var areaName: String {
        switch self {
        case .cthulhu: "ルルイエ海淵"
        case .nyarlathotep: "無貌の回廊"
        case .azathoth: "混沌の中枢"
        case .necronomicon: "禁書の迷宮"
        }
    }

    var bossEnemyID: String {
        switch self {
        case .cthulhu: "cthulhu_boss"
        case .nyarlathotep: "nyarlathotep_boss"
        case .azathoth: "azathoth_boss"
        case .necronomicon: "necronomicon_boss"
        }
    }

    static let mapsPerArc = 15
}

struct Dungeon: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let kind: DungeonKind
    let arc: MainArc?
    /// メインダンジョンのマップ番号(1〜15)
    let mapIndex: Int?
    let recommendedLevel: Int
    /// 1分あたりのボス発見確率
    let bossFindChancePerMinute: Double
    /// この時間(分)経過で確実にボス発見。カオスは nil(青天井)
    let guaranteedFindMinutes: Int?
    let bossEnemyID: String
    /// 道中に出る雑魚
    let mobEnemyIDs: [String]
}

struct LootLogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var message: String
}

/// ダンジョン潜入の進行状態。潜入後は基本放置でウィジェットで見守る
struct DungeonRun: Codable, Hashable {
    var dungeonID: String
    var enteredAt: Date
    var lastProcessed: Date
    var bossFound = false
    var bossFoundAt: Date?
    var collectedCoins = 0
    var collectedExp = 0
    var collectedMaterials = 0
    var log: [LootLogEntry] = []

    init(dungeonID: String, now: Date = Date()) {
        self.dungeonID = dungeonID
        self.enteredAt = now
        self.lastProcessed = now
    }

    func dungeon() -> Dungeon { DungeonCatalog.dungeon(id: dungeonID) }

    /// 確実発見までの進行度(0〜1)。カオスは常に nil
    func searchProgress(now: Date = Date()) -> Double? {
        guard let minutes = dungeon().guaranteedFindMinutes else { return nil }
        return min(1.0, now.timeIntervalSince(enteredAt) / (Double(minutes) * 60))
    }
}
