import Foundation

enum OtomoCatalog {
    static let all: [OtomoSpecies] = {
        var list: [OtomoSpecies] = []

        func add(_ id: String, _ name: String, _ category: OtomoCategory, _ element: Element,
                 hp: Int, atk: Int, def: Int, spd: Int, mag: Int, hatchMinutes: Double) {
            list.append(OtomoSpecies(
                id: id, name: name, category: category, element: element,
                baseStats: BaseStats(hp: hp, attack: atk, defense: def, speed: spd, magic: mag),
                baseHatchSeconds: hatchMinutes * 60))
        }

        // 特殊
        add("balloon", "風船", .special, .electric, hp: 40, atk: 4, def: 2, spd: 18, mag: 10, hatchMinutes: 5)
        add("slime", "スライム", .special, .water, hp: 60, atk: 6, def: 8, spd: 8, mag: 6, hatchMinutes: 5)

        // 地上
        add("dog", "犬", .ground, .fire, hp: 70, atk: 10, def: 6, spd: 14, mag: 2, hatchMinutes: 15)
        add("cat", "猫", .ground, .dark, hp: 60, atk: 9, def: 5, spd: 18, mag: 4, hatchMinutes: 15)
        add("wolf", "狼", .ground, .dark, hp: 80, atk: 14, def: 7, spd: 16, mag: 2, hatchMinutes: 30)
        add("lizard", "トカゲ", .ground, .fire, hp: 65, atk: 9, def: 8, spd: 12, mag: 4, hatchMinutes: 20)
        add("snake", "蛇", .ground, .dark, hp: 60, atk: 12, def: 5, spd: 14, mag: 6, hatchMinutes: 25)
        add("bear", "熊", .ground, .fire, hp: 120, atk: 16, def: 12, spd: 6, mag: 2, hatchMinutes: 45)
        add("fox", "狐", .ground, .fire, hp: 65, atk: 10, def: 6, spd: 16, mag: 10, hatchMinutes: 30)

        // 水生生物
        add("octopus", "タコ", .aquatic, .water, hp: 75, atk: 11, def: 8, spd: 8, mag: 8, hatchMinutes: 25)
        add("goldfish", "金魚", .aquatic, .water, hp: 45, atk: 5, def: 4, spd: 12, mag: 8, hatchMinutes: 10)
        add("koi", "錦鯉", .aquatic, .water, hp: 70, atk: 8, def: 8, spd: 10, mag: 10, hatchMinutes: 40)
        add("frog", "カエル", .aquatic, .water, hp: 55, atk: 8, def: 6, spd: 14, mag: 6, hatchMinutes: 15)
        add("jellyfish", "クラゲ", .aquatic, .electric, hp: 50, atk: 6, def: 4, spd: 10, mag: 14, hatchMinutes: 20)
        add("shark", "サメ", .aquatic, .water, hp: 100, atk: 18, def: 8, spd: 12, mag: 2, hatchMinutes: 60)

        // 鳥
        add("owl", "フクロウ", .bird, .dark, hp: 60, atk: 9, def: 5, spd: 15, mag: 12, hatchMinutes: 30)
        add("crow", "カラス", .bird, .dark, hp: 55, atk: 10, def: 4, spd: 17, mag: 8, hatchMinutes: 25)
        add("hawk", "鷹", .bird, .electric, hp: 65, atk: 14, def: 5, spd: 20, mag: 4, hatchMinutes: 45)
        add("bat", "コウモリ", .bird, .dark, hp: 50, atk: 8, def: 4, spd: 18, mag: 8, hatchMinutes: 20)
        add("penguin", "ペンギン", .bird, .water, hp: 70, atk: 8, def: 8, spd: 10, mag: 8, hatchMinutes: 25)

        // 虫
        add("spider", "蜘蛛", .insect, .dark, hp: 55, atk: 10, def: 5, spd: 14, mag: 6, hatchMinutes: 20)
        add("butterfly", "蝶", .insect, .electric, hp: 45, atk: 5, def: 3, spd: 16, mag: 12, hatchMinutes: 15)
        add("centipede", "ムカデ", .insect, .dark, hp: 65, atk: 13, def: 7, spd: 12, mag: 2, hatchMinutes: 30)
        add("bee", "ハチ", .insect, .electric, hp: 50, atk: 12, def: 4, spd: 18, mag: 4, hatchMinutes: 25)

        // 伝説(進化しない)
        add("ryu_western", "竜", .legendary, .fire, hp: 200, atk: 30, def: 20, spd: 14, mag: 20, hatchMinutes: 480)
        add("ryu_eastern", "龍", .legendary, .water, hp: 190, atk: 26, def: 18, spd: 16, mag: 26, hatchMinutes: 480)
        add("dragon", "ドラゴン", .legendary, .fire, hp: 210, atk: 32, def: 22, spd: 12, mag: 18, hatchMinutes: 480)
        add("phoenix", "フェニックス", .legendary, .fire, hp: 170, atk: 22, def: 14, spd: 20, mag: 28, hatchMinutes: 480)
        add("pegasus", "ペガサス", .legendary, .electric, hp: 160, atk: 22, def: 14, spd: 28, mag: 20, hatchMinutes: 420)
        add("cerberus", "ケルベロス", .legendary, .dark, hp: 190, atk: 30, def: 18, spd: 16, mag: 12, hatchMinutes: 480)
        add("fenrir", "フェンリル", .legendary, .dark, hp: 185, atk: 28, def: 16, spd: 24, mag: 12, hatchMinutes: 480)
        add("griffon", "グリフォン", .legendary, .electric, hp: 180, atk: 26, def: 16, spd: 22, mag: 14, hatchMinutes: 420)
        add("kirin", "麒麟", .legendary, .electric, hp: 175, atk: 22, def: 16, spd: 22, mag: 26, hatchMinutes: 480)
        add("unicorn", "ユニコーン", .legendary, .water, hp: 165, atk: 20, def: 14, spd: 24, mag: 26, hatchMinutes: 420)
        add("leviathan", "リヴァイアサン", .legendary, .water, hp: 220, atk: 28, def: 22, spd: 10, mag: 24, hatchMinutes: 540)
        add("bahamut", "バハムート", .legendary, .dark, hp: 230, atk: 34, def: 24, spd: 12, mag: 22, hatchMinutes: 600)
        add("behemoth", "ベヒーモス", .legendary, .fire, hp: 240, atk: 32, def: 26, spd: 8, mag: 10, hatchMinutes: 540)
        add("hydra", "ヒュドラ", .legendary, .water, hp: 210, atk: 28, def: 18, spd: 10, mag: 20, hatchMinutes: 480)
        add("medjed", "メジェド", .legendary, .dark, hp: 150, atk: 20, def: 20, spd: 14, mag: 32, hatchMinutes: 600)

        // 神話(メインダンジョン最終ボス討伐で卵が確率ドロップ)
        add("cthulhu", "クトゥルフ", .mythic, .water, hp: 260, atk: 36, def: 26, spd: 12, mag: 34, hatchMinutes: 1440)
        add("azathoth", "アザトース", .mythic, .dark, hp: 300, atk: 40, def: 30, spd: 8, mag: 40, hatchMinutes: 1440)
        add("nyarlathotep", "ニャルラトホテプ", .mythic, .dark, hp: 250, atk: 34, def: 24, spd: 22, mag: 38, hatchMinutes: 1440)

        return list
    }()

    static func species(id: String) -> OtomoSpecies {
        all.first { $0.id == id } ?? all[1] // fallback: スライム
    }

    /// 卵ダンジョン等のドロップ抽選プール
    static func randomSpecies(includeLegendary: Bool = false) -> OtomoSpecies {
        let pool = all.filter {
            includeLegendary ? $0.category != .mythic : ($0.category != .legendary && $0.category != .mythic)
        }
        return pool.randomElement() ?? all[1]
    }
}
