import Foundation

/// 敵の定義。
/// stats は「推奨レベル45相当」の基準値で持ち、戦闘時にダンジョンの
/// 推奨レベルに応じてスケーリングされる(BattleSetup.enemyUnit)。
/// アンカー: 無貌の回廊 最終ボス(ニャルラトホテプ、推奨Lv45)が
/// 調整シミュレーターのヒュドラ(HP3200/攻145/速75/魔50)と同格。
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
        // --- 雑魚(ボスの取り巻き。2体まで同時に出る前提で弱め) ---
        Enemy(id: "goblin", name: "ゴブリン", element: .fire,
              stats: BaseStats(hp: 450, attack: 55, defense: 0, speed: 60, magic: 10), isBoss: false, spriteKey: "goblin"),
        Enemy(id: "angel", name: "天使", element: .electric,
              stats: BaseStats(hp: 550, attack: 60, defense: 0, speed: 70, magic: 60), isBoss: false, spriteKey: "angel"),
        Enemy(id: "demon", name: "悪魔", element: .dark,
              stats: BaseStats(hp: 600, attack: 65, defense: 0, speed: 65, magic: 45), isBoss: false, spriteKey: "demon"),
        Enemy(id: "golem", name: "ゴーレム", element: .water,
              stats: BaseStats(hp: 900, attack: 60, defense: 0, speed: 30, magic: 10), isBoss: false, spriteKey: "golem"),
        Enemy(id: "cyclops", name: "サイクロプス", element: .fire,
              stats: BaseStats(hp: 850, attack: 80, defense: 0, speed: 40, magic: 15), isBoss: false, spriteKey: "cyclops"),
        Enemy(id: "ogre", name: "オーガ", element: .fire,
              stats: BaseStats(hp: 750, attack: 75, defense: 0, speed: 50, magic: 10), isBoss: false, spriteKey: "ogre"),
        Enemy(id: "giant", name: "ジャイアント", element: .water,
              stats: BaseStats(hp: 1100, attack: 85, defense: 0, speed: 28, magic: 10), isBoss: false, spriteKey: "giant"),
        // --- ボス ---
        Enemy(id: "dragon_enemy", name: "ドラゴン", element: .fire,
              stats: BaseStats(hp: 2600, attack: 120, defense: 0, speed: 70, magic: 40), isBoss: true, spriteKey: "dragon"),
        // メインダンジョンの最終ボス(クトゥルフ神話)
        Enemy(id: "cthulhu_boss", name: "クトゥルフ", element: .water,
              stats: BaseStats(hp: 3600, attack: 135, defense: 0, speed: 60, magic: 70), isBoss: true, spriteKey: "cthulhu"),
        // ★アンカー: シミュレーターのヒュドラと同値(推奨Lv45で等倍)
        Enemy(id: "nyarlathotep_boss", name: "ニャルラトホテプ", element: .dark,
              stats: BaseStats(hp: 3200, attack: 145, defense: 0, speed: 75, magic: 50), isBoss: true, spriteKey: "nyarlathotep"),
        Enemy(id: "azathoth_boss", name: "アザトース", element: .dark,
              stats: BaseStats(hp: 4200, attack: 160, defense: 0, speed: 50, magic: 80), isBoss: true, spriteKey: "azathoth"),
        Enemy(id: "necronomicon_boss", name: "ネクロノミコン", element: .dark,
              stats: BaseStats(hp: 2800, attack: 130, defense: 0, speed: 95, magic: 90), isBoss: true, spriteKey: "necronomicon"),
    ]

    static func enemy(id: String) -> Enemy {
        all.first { $0.id == id } ?? all[0] // fallback: ゴブリン
    }

    static var normalEnemies: [Enemy] { all.filter { !$0.isBoss } }
}
