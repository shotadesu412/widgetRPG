import Foundation

struct Enemy: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let element: Element
    let stats: BaseStats
    let isBoss: Bool
    let spriteKey: String
}

enum EnemyCatalog {
    static let all: [Enemy] = [
        Enemy(id: "angel", name: "天使", element: .electric,
              stats: BaseStats(hp: 90, attack: 18, defense: 12, speed: 20, magic: 22), isBoss: false, spriteKey: "angel"),
        Enemy(id: "demon", name: "悪魔", element: .dark,
              stats: BaseStats(hp: 110, attack: 22, defense: 14, speed: 16, magic: 20), isBoss: false, spriteKey: "demon"),
        Enemy(id: "golem", name: "ゴーレム", element: .water,
              stats: BaseStats(hp: 180, attack: 20, defense: 30, speed: 6, magic: 4), isBoss: false, spriteKey: "golem"),
        Enemy(id: "cyclops", name: "サイクロプス", element: .fire,
              stats: BaseStats(hp: 160, attack: 28, defense: 18, speed: 8, magic: 6), isBoss: false, spriteKey: "cyclops"),
        Enemy(id: "goblin", name: "ゴブリン", element: .fire,
              stats: BaseStats(hp: 60, attack: 12, defense: 8, speed: 18, magic: 4), isBoss: false, spriteKey: "goblin"),
        Enemy(id: "ogre", name: "オーガ", element: .fire,
              stats: BaseStats(hp: 140, attack: 26, defense: 16, speed: 10, magic: 4), isBoss: false, spriteKey: "ogre"),
        Enemy(id: "giant", name: "ジャイアント", element: .water,
              stats: BaseStats(hp: 220, attack: 30, defense: 22, speed: 5, magic: 4), isBoss: false, spriteKey: "giant"),
        Enemy(id: "dragon_enemy", name: "ドラゴン", element: .fire,
              stats: BaseStats(hp: 260, attack: 34, defense: 24, speed: 14, magic: 18), isBoss: true, spriteKey: "dragon"),
        // メインダンジョンの最終ボス(クトゥルフ神話)
        Enemy(id: "cthulhu_boss", name: "クトゥルフ", element: .water,
              stats: BaseStats(hp: 800, attack: 48, defense: 32, speed: 14, magic: 40), isBoss: true, spriteKey: "cthulhu"),
        Enemy(id: "nyarlathotep_boss", name: "ニャルラトホテプ", element: .dark,
              stats: BaseStats(hp: 700, attack: 42, defense: 26, speed: 26, magic: 46), isBoss: true, spriteKey: "nyarlathotep"),
        Enemy(id: "azathoth_boss", name: "アザトース", element: .dark,
              stats: BaseStats(hp: 1000, attack: 56, defense: 36, speed: 10, magic: 56), isBoss: true, spriteKey: "azathoth"),
        Enemy(id: "necronomicon_boss", name: "ネクロノミコン", element: .dark,
              stats: BaseStats(hp: 600, attack: 36, defense: 30, speed: 18, magic: 50), isBoss: true, spriteKey: "necronomicon"),
    ]

    static func enemy(id: String) -> Enemy {
        all.first { $0.id == id } ?? all[4] // fallback: ゴブリン
    }

    static var normalEnemies: [Enemy] { all.filter { !$0.isBoss } }
}
