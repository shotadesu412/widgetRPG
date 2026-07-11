import Foundation

/// レア度(星3まで)
enum Rarity: Int, Codable, CaseIterable, Comparable {
    case star1 = 1, star2, star3

    var stars: String { String(repeating: "★", count: rawValue) }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 武器種()内はスキルの効果傾向
enum WeaponType: String, Codable, CaseIterable, Identifiable {
    case sword      // 剣(単体)
    case greatsword // 大剣(全体攻撃)
    case dagger     // 短剣(クリティカル)
    case twinBlade  // 双剣(複数回攻撃)
    case staff      // 杖(魔力依存)
    case revolver   // リボルバー(ランダムな回数攻撃)
    case bow        // 弓(デバフ)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sword: "剣"
        case .greatsword: "大剣"
        case .dagger: "短剣"
        case .twinBlade: "双剣"
        case .staff: "杖"
        case .revolver: "リボルバー"
        case .bow: "弓"
        }
    }

    var flavor: String {
        switch self {
        case .sword: "単体"
        case .greatsword: "全体攻撃"
        case .dagger: "クリティカル"
        case .twinBlade: "複数回攻撃"
        case .staff: "魔力依存"
        case .revolver: "ランダムな回数攻撃"
        case .bow: "デバフ"
        }
    }

    var symbolName: String {
        switch self {
        case .sword, .greatsword: "sword.fill"
        case .dagger, .twinBlade: "scissors"
        case .staff: "wand.and.stars"
        case .revolver: "target"
        case .bow: "arrow.up.right"
        }
    }
}

/// 装備強化の共通定数
enum EquipmentUpgrade {
    /// 最大3段階強化
    static let maxLevel = 3
    /// 強化に必要な素材数
    static func materialCost(toLevel level: Int) -> Int { level * 20 }
}

/// 武器。同じ武器でもステータス・スキルの位置や中身が個体ごとに異なる。
/// 強化(最大3段階)ごとにステータスが上がる
struct Weapon: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: WeaponType
    var rarity: Rarity
    var bonus: BaseStats
    var element: Element?
    /// スロット位置(0開始) → 付与された武器スキル(1〜2個、位置はランダム)
    var skillPositions: [Int: Skill]
    /// 強化段階(0〜3)。強化ごとにステータス+10%
    var upgradeLevel = 0

    var upgradedBonus: BaseStats { bonus.scaled(by: 1.0 + 0.1 * Double(upgradeLevel)) }

    var canUpgrade: Bool { upgradeLevel < EquipmentUpgrade.maxLevel }
}

/// 防具種()内は強化対象のステータス傾向
enum ArmorType: String, Codable, CaseIterable, Identifiable {
    case plate  // 鎧: 重量高め(防御干渉)
    case cloak  // マント: 重量中程度(属性干渉)
    case robe   // ローブ: 重量中程度(魔力干渉)
    case ring   // 指輪: 重量低め(ステータス干渉微量)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plate: "鎧"
        case .cloak: "マント"
        case .robe: "ローブ"
        case .ring: "指輪"
        }
    }

    /// 基準重量。重いほど素早さが下がるが基礎ステータス上昇値が高い
    var baseWeight: Int {
        switch self {
        case .plate: 50
        case .cloak, .robe: 30
        case .ring: 10
        }
    }

    /// 防具種ごとのパッシブ傾向
    var passivePool: [PassiveKind] {
        switch self {
        case .plate: [.statBoost, .miniBarrier, .lowHPBoost]          // 防御干渉
        case .cloak: [.elementBoost, .oddSlotBoost, .evenSlotBoost]   // 属性干渉
        case .robe: [.statBoost, .secondLoopBoost, .otomoBoost]       // 魔力干渉
        case .ring: [.doubleAct, .flatDamage, .emptySlotBoost, .firstLoopBoost] // 微量・強レア
        }
    }
}

/// 防具。星と同じ数のパッシブが付与され、強化(最大3段階)ごとに1つずつ解放される。
/// 重量が高いほど防御・HPの上昇値が高く、素早さが下がる
struct Armor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: ArmorType
    var rarity: Rarity
    var weight: Int
    var bonus: BaseStats
    /// 星と同じ数だけ付与されるパッシブ(強化で順に解放)
    var passives: [Passive]
    /// 強化段階(0〜3)。強化ごとにパッシブを1つ解放
    var upgradeLevel = 0

    /// 強化で解放済みのパッシブ
    var activePassives: [Passive] { Array(passives.prefix(upgradeLevel)) }

    var canUpgrade: Bool { upgradeLevel < EquipmentUpgrade.maxLevel }

    /// 重量による素早さ減少
    var speedPenalty: Int { weight / 5 }
}
