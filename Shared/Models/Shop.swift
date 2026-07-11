import Foundation

enum ShopItemKind: String, Codable, CaseIterable {
    case egg, weapon, armor, material, coinPack

    var label: String {
        switch self {
        case .egg: "卵"
        case .weapon: "武器"
        case .armor: "防具"
        case .material: "素材"
        case .coinPack: "コイン袋"
        }
    }

    var symbolName: String {
        switch self {
        case .egg: "oval.portrait.fill"
        case .weapon: "sword.fill"
        case .armor: "shield.fill"
        case .material: "cube.fill"
        case .coinPack: "bag.fill"
        }
    }
}

/// ショップ商品。ウィジェットでは見た目のみ表示され、詳細はアプリで確認する
struct ShopItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: ShopItemKind
    var name: String
    var price: Int
    var detail: String
}

/// ショップはランダムな時間に更新され、6種類の商品がランダムに並ぶ
struct ShopState: Codable, Hashable {
    var items: [ShopItem] = []
    var nextRefresh = Date()
    static let itemCount = 6
}

/// ギルド来訪者。毎日3人来訪し、1人を選んで確率でスカウト
struct GuildVisitor: Identifiable, Codable, Hashable {
    var id = UUID()
    var jobID: String
}

struct GuildState: Codable, Hashable {
    var visitors: [GuildVisitor] = []
    /// 最後に来訪者を更新した日(日付単位)
    var lastVisitDay: Date?
    /// スカウト失敗ごとに確率が上がっていく
    var scoutFailCount = 0
    /// 本日スカウト済みか
    var scoutedToday = false

    /// スカウト成功率(初期は低め、失敗ごとに上昇)
    var scoutChance: Double { min(0.9, 0.2 + Double(scoutFailCount) * 0.06) }
}
