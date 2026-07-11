import Foundation

/// 属性(炎、水、電気、闇、風)
enum Element: String, Codable, CaseIterable, Identifiable {
    case fire, water, electric, dark, wind

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fire: "炎"
        case .water: "水"
        case .electric: "電気"
        case .dark: "闇"
        case .wind: "風"
        }
    }

    var symbolName: String {
        switch self {
        case .fire: "flame.fill"
        case .water: "drop.fill"
        case .electric: "bolt.fill"
        case .dark: "moon.fill"
        case .wind: "wind"
        }
    }

    /// 属性相性: 炎→闇→電気→風→水→炎 の5すくみで有利
    var strongAgainst: Element {
        switch self {
        case .fire: .dark
        case .dark: .electric
        case .electric: .wind
        case .wind: .water
        case .water: .fire
        }
    }

    func multiplier(against defender: Element) -> Double {
        if strongAgainst == defender { return 1.5 }
        if defender.strongAgainst == self { return 0.75 }
        return 1.0
    }
}

/// 基本ステータス(HP、攻撃、防御、素早さ、魔力)
struct BaseStats: Codable, Equatable, Hashable {
    var hp: Int
    var attack: Int
    var defense: Int
    var speed: Int
    var magic: Int

    static let zero = BaseStats(hp: 0, attack: 0, defense: 0, speed: 0, magic: 0)

    static func + (lhs: BaseStats, rhs: BaseStats) -> BaseStats {
        BaseStats(
            hp: lhs.hp + rhs.hp,
            attack: lhs.attack + rhs.attack,
            defense: lhs.defense + rhs.defense,
            speed: lhs.speed + rhs.speed,
            magic: lhs.magic + rhs.magic
        )
    }

    func scaled(by factor: Double) -> BaseStats {
        BaseStats(
            hp: Int(Double(hp) * factor),
            attack: Int(Double(attack) * factor),
            defense: Int(Double(defense) * factor),
            speed: Int(Double(speed) * factor),
            magic: Int(Double(magic) * factor)
        )
    }
}
