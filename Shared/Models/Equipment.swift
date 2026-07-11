import Foundation

/// レア度(星3まで)
enum Rarity: Int, Codable, CaseIterable, Comparable {
    case star1 = 1, star2, star3

    var stars: String { String(repeating: "★", count: rawValue) }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum WeaponType: String, Codable, CaseIterable, Identifiable {
    case sword, greatsword, dagger, twinBlade, staff, revolver, glove, bow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sword: "剣"
        case .greatsword: "大剣"
        case .dagger: "短剣"
        case .twinBlade: "双剣"
        case .staff: "杖"
        case .revolver: "リボルバー" // ランダムな回数攻撃
        case .glove: "グローブ"
        case .bow: "弓"
        }
    }

    var symbolName: String {
        switch self {
        case .sword, .greatsword: "sword.fill"
        case .dagger, .twinBlade: "scissors"
        case .staff: "wand.and.stars"
        case .revolver: "target"
        case .glove: "hand.raised.fill"
        case .bow: "arrow.up.right"
        }
    }
}

/// 武器。同じ武器でもステータス・スキルの位置や中身が個体ごとに異なる
struct Weapon: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: WeaponType
    var rarity: Rarity
    var bonus: BaseStats
    var element: Element?
    /// スロット位置(0開始) → 付与された武器スキル(1〜2個、位置はランダム)
    var skillPositions: [Int: Skill]
}

enum ArmorType: String, Codable, CaseIterable, Identifiable {
    case plate  // 鎧: 重量高め
    case cloak  // マント: 重量中程度
    case robe   // ローブ: 重量中程度
    case ring   // 指輪: 重量低め(強パッシブ)
    case mask   // 仮面: 重量低め

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plate: "鎧"
        case .cloak: "マント"
        case .robe: "ローブ"
        case .ring: "指輪"
        case .mask: "仮面"
        }
    }

    /// 基準重量。重いほど素早さが下がるが基礎ステータス上昇値が高い
    var baseWeight: Int {
        switch self {
        case .plate: 50
        case .cloak, .robe: 30
        case .ring, .mask: 10
        }
    }
}

/// 防具。重量が高いほど防御・HPの上昇値が高く、素早さが下がる
struct Armor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: ArmorType
    var rarity: Rarity
    var weight: Int
    var bonus: BaseStats
    /// ランダム付与のパッシブ。強い効果は低重量防具に割り振られる
    var passives: [Passive]

    /// 重量による素早さ減少
    var speedPenalty: Int { weight / 5 }
}
