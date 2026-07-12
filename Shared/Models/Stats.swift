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

    /// 属性相性: 風→電気→水→炎→風 の4すくみ。闇は円環の外(特例)
    var strongAgainst: Element? {
        switch self {
        case .wind: .electric
        case .electric: .water
        case .water: .fire
        case .fire: .wind
        case .dark: nil
        }
    }

    /// ダメージ倍率。
    /// - 4すくみ: 有利1.3倍 / 不利0.85倍
    /// - 闇: 全属性に与ダメ1.2倍、かつ全属性から被ダメ1.2倍(闇同士は1.44倍)
    func multiplier(against defender: Element) -> Double {
        var value = 1.0
        if self == .dark { value *= 1.2 }      // 闇の与ダメ
        if defender == .dark { value *= 1.2 }  // 闇の被ダメ
        if self != .dark, defender != .dark {
            if strongAgainst == defender {
                value *= 1.3
            } else if defender.strongAgainst == self {
                value *= 0.85
            }
        }
        return value
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
