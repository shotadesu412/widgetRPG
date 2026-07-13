import Foundation

/// ショップの陳列レア度。枠ごとに抽選される
enum ShopTier: String, Codable, CaseIterable {
    case basic     // 基本(60%): アイテム、普通の卵
    case uncommon  // やや珍しい(39%): 基本より多めのアイテム、珍しい卵
    case lowChance // 低確率(1%): ギルドチケット、星3装備、伝説の卵

    var label: String {
        switch self {
        case .basic: "基本"
        case .uncommon: "珍"
        case .lowChance: "稀"
        }
    }

    /// 陳列率(%)
    static func roll() -> ShopTier {
        let x = Double.random(in: 0..<100)
        if x < 60 { return .basic }
        if x < 99 { return .uncommon }
        return .lowChance
    }
}

enum ShopItemKind: String, Codable, CaseIterable {
    case elementStone // 属性石(属性ごとに5種。キャラの進化に使用)
    case material     // 装備強化などに使う素材
    case coinPack
    case egg
    case weapon
    case armor
    case guildTicket  // その日のスカウトをもう一度行える

    var symbolName: String {
        switch self {
        case .elementStone: "diamond.fill"
        case .material: "cube.fill"
        case .coinPack: "bag.fill"
        case .egg: "oval.portrait.fill"
        case .weapon: "figure.fencing"
        case .armor: "shield.fill"
        case .guildTicket: "ticket.fill"
        }
    }
}

/// ショップ商品。ウィジェットでは見た目のみ表示され、詳細はアプリで確認する
struct ShopItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var tier: ShopTier
    var kind: ShopItemKind
    var name: String
    var price: Int
    var detail: String
    /// 属性石の属性
    var element: Element?
    /// 卵の種類
    var eggGrade: EggGrade?
    /// 装備のレア度指定(低確率枠の星3くじ等)
    var equipRarity: Rarity?
    /// 素材などの個数
    var amount = 1
}

/// ショップはランダムな時間に更新され、6枠の商品がランダムに並ぶ
struct ShopState: Codable, Hashable {
    var items: [ShopItem] = []
    var nextRefresh = Date()
    static let itemCount = 6
}

/// ギルド来訪者。毎日3人来訪し、1人を選び確率でスカウト
struct GuildVisitor: Identifiable, Codable, Hashable {
    var id = UUID()
    var jobID: String
}

struct GuildState: Codable, Hashable {
    var visitors: [GuildVisitor] = []
    /// 最後に来訪者を更新した日(日付単位)
    var lastVisitDay: Date?
    /// キャラごとのスカウト失敗回数(失敗で確率が上がる。成功でリセット)
    var scoutFails: [String: Int] = [:]
    /// 本日スカウト済みか(ギルドチケットで追加スカウト可)
    var scoutedToday = false

    /// キャラごとのスカウト成功率。
    /// ティア別: 基本 初期25%+失敗5% / 特殊 初期10%+失敗4% / レア 30%固定
    func scoutChance(forJobID jobID: String) -> Double {
        guard let tier = GachaCore.tier(ofJobID: jobID) else { return 0.2 }
        let rate = tier.initialScoutRate + tier.scoutFailStep * Double(scoutFails[jobID] ?? 0)
        return min(0.95, rate / 100)
    }
}
