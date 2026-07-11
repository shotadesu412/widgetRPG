import Foundation

/// 武器・防具・卵などのランダム生成
enum ItemFactory {

    // MARK: - 武器

    private static let weaponNamePrefixes = ["錆びた", "鉄の", "無銘の", "輝く", "呪われた", "月光の", "深淵の"]

    private static let weaponSkillNames: [WeaponType: [String]] = [
        .sword: ["強斬り", "十字斬り"],
        .greatsword: ["兜割り", "大回転斬り"],
        .dagger: ["急所突き", "毒塗りの刃"],
        .twinBlade: ["二連撃", "旋風刃"],
        .staff: ["魔力弾", "属性爆発"],
        .revolver: ["乱れ撃ち", "狙撃"],
        .glove: ["連打", "気孔弾"],
        .bow: ["貫通の矢", "矢の雨"],
    ]

    static func randomWeapon(rarityBias: Int = 0) -> Weapon {
        let type = WeaponType.allCases.randomElement()!
        let rarity = randomRarity(bias: rarityBias)
        let element = Bool.random() ? Element.allCases.randomElement() : nil
        let r = Double(rarity.rawValue)

        // 同じ武器でも個体ごとにステータスが少し異なる
        let bonus = BaseStats(
            hp: 0,
            attack: Int.random(in: 4...8) * rarity.rawValue,
            defense: 0,
            speed: type == .dagger || type == .twinBlade ? Int.random(in: 1...3) : 0,
            magic: type == .staff ? Int.random(in: 4...8) * rarity.rawValue : Int.random(in: 0...2)
        )

        // 武器スキルは1〜2個、ランダムな位置に付与(スロット3個想定の位置0〜2)
        let names = weaponSkillNames[type] ?? ["一撃"]
        let skillCount = Int.random(in: 1...2)
        var positions: [Int: Skill] = [:]
        var slots = Array(0..<3).shuffled()
        for i in 0..<skillCount {
            let pos = slots.removeFirst()
            positions[pos] = Skill(
                name: names[i % names.count],
                kind: type == .staff ? .magic : .attack,
                power: Int(100 * (1.0 + r * 0.2)),
                element: element
            )
        }

        let name = "\(weaponNamePrefixes.randomElement()!)\(type.label)"
        return Weapon(name: name, type: type, rarity: rarity, bonus: bonus,
                      element: element, skillPositions: positions)
    }

    // MARK: - 防具

    private static let armorNamePrefixes = ["ぼろの", "革の", "騎士の", "隠者の", "王家の", "夜闇の"]

    static func randomArmor(rarityBias: Int = 0) -> Armor {
        let type = ArmorType.allCases.randomElement()!
        let rarity = randomRarity(bias: rarityBias)
        let weight = max(1, type.baseWeight + Int.random(in: -5...5))

        // 重量が高いほど防御・HPの基礎上昇値が高い
        let bonus = BaseStats(
            hp: weight / 2 * rarity.rawValue,
            attack: 0,
            defense: weight / 4 * rarity.rawValue,
            speed: 0,
            magic: type == .robe ? 4 * rarity.rawValue : 0
        )

        // 強いパッシブは低重量の防具(指輪・仮面)に割り振られる
        let pool = PassiveKind.allCases.filter { weight <= 15 ? true : !$0.isStrong }
        let passives = (0..<rarity.rawValue).compactMap { _ in
            pool.randomElement().map { Passive(kind: $0, value: Int.random(in: 5...20) * rarity.rawValue) }
        }

        let name = "\(armorNamePrefixes.randomElement()!)\(type.label)"
        return Armor(name: name, type: type, rarity: rarity, weight: weight,
                     bonus: bonus, passives: passives)
    }

    // MARK: - 卵

    static func randomEgg(includeLegendary: Bool = false, hatchTimeScale: Double = 1.0, now: Date = Date()) -> Egg {
        let species = OtomoCatalog.randomSpecies(includeLegendary: includeLegendary)
        let rarity: Rarity = species.canEvolve ? randomRarity(bias: 0) : .star3
        // 強い個体(高レア)ほど孵化時間が長い
        let seconds = species.baseHatchSeconds * (1.0 + Double(rarity.rawValue - 1) * 0.5) * hatchTimeScale
        return Egg(speciesID: species.id, rarity: rarity, obtainedAt: now, hatchSeconds: seconds)
    }

    /// 卵からオトモを孵化させる
    static func hatch(_ egg: Egg) -> Otomo {
        let species = OtomoCatalog.species(id: egg.speciesID)
        var otomo = Otomo(speciesID: egg.speciesID, rarity: egg.rarity)
        // キャラクタースロットにランダムでスキルが付与されている
        otomo.skills = [
            Skill(name: "\(species.name)の牙", kind: .attack, power: 100, element: species.element)
        ]
        if Int.random(in: 0..<5) == 0 { // 必殺技持ちは少なめ
            otomo.ultimate = UltimateSkill(name: "\(species.name)の咆哮", kind: .damageAll,
                                           power: 200, requiredLoops: 3)
        }
        return otomo
    }

    // MARK: - ショップ

    static func randomShopItems(now: Date = Date()) -> [ShopItem] {
        (0..<ShopState.itemCount).map { _ in
            let kind = ShopItemKind.allCases.randomElement()!
            let price: Int
            let name: String
            let detail: String
            switch kind {
            case .egg:
                price = Int.random(in: 200...800)
                name = "怪しい卵"
                detail = "何が生まれるかは孵化してのお楽しみ"
            case .weapon:
                price = Int.random(in: 150...600)
                name = "武器くじ"
                detail = "ランダムな武器を1つ入手"
            case .armor:
                price = Int.random(in: 150...600)
                name = "防具くじ"
                detail = "ランダムな防具を1つ入手"
            case .material:
                price = Int.random(in: 50...200)
                name = "強化素材の束"
                detail = "武器や拠点の強化に使う素材"
            case .coinPack:
                price = Int.random(in: 80...150)
                name = "小さなコイン袋"
                detail = "開けるとコインが少し増える(気がする)"
            }
            return ShopItem(kind: kind, name: name, price: price, detail: detail)
        }
    }

    private static func randomRarity(bias: Int) -> Rarity {
        let roll = Int.random(in: 0..<100) + bias
        if roll >= 95 { return .star3 }
        if roll >= 70 { return .star2 }
        return .star1
    }
}
