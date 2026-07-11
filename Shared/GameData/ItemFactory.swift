import Foundation

/// 武器・防具・卵・ショップ商品などのランダム生成
enum ItemFactory {

    // MARK: - 武器

    private static let weaponNamePrefixes = ["錆びた", "鉄の", "無銘の", "輝く", "呪われた", "月光の", "深淵の"]

    /// 武器種ごとのスキル(名前と効果傾向)
    private static func weaponSkill(for type: WeaponType, rarity: Rarity, element: Element?) -> Skill {
        let r = Double(rarity.rawValue)
        switch type {
        case .sword:
            return Skill(name: "強斬り", kind: .attack, power: Int(130 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .single)
        case .greatsword:
            return Skill(name: "大回転斬り", kind: .attack, power: Int(90 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .aoe)
        case .dagger:
            return Skill(name: "急所突き", kind: .attack, power: Int(100 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .crit)
        case .twinBlade:
            return Skill(name: "二連撃", kind: .attack, power: Int(70 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .multiHit)
        case .staff:
            return Skill(name: "魔力弾", kind: .magic, power: Int(130 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .magic)
        case .revolver:
            return Skill(name: "乱れ撃ち", kind: .attack, power: Int(45 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .randomHits)
        case .bow:
            return Skill(name: "狙い撃ち", kind: .debuff, power: Int(80 * (1.0 + r * 0.15)),
                         element: element, weaponEffect: .debuff)
        }
    }

    static func randomWeapon(rarity: Rarity? = nil) -> Weapon {
        let type = WeaponType.allCases.randomElement()!
        let rarity = rarity ?? rollEquipmentRarity()
        let element = Bool.random() ? Element.allCases.randomElement() : nil

        // 同じ武器でも個体ごとにステータスが少し異なる
        let bonus = BaseStats(
            hp: 0,
            attack: Int.random(in: 4...8) * rarity.rawValue,
            defense: 0,
            speed: type == .dagger || type == .twinBlade ? Int.random(in: 1...3) : 0,
            magic: type == .staff ? Int.random(in: 4...8) * rarity.rawValue : Int.random(in: 0...2)
        )

        // 武器スキルは1〜2個、ランダムな位置に付与(スロット3個想定の位置0〜2)
        let skillCount = Int.random(in: 1...2)
        var positions: [Int: Skill] = [:]
        var slots = Array(0..<3).shuffled()
        for _ in 0..<skillCount {
            let pos = slots.removeFirst()
            positions[pos] = weaponSkill(for: type, rarity: rarity, element: element)
        }

        let name = "\(weaponNamePrefixes.randomElement()!)\(type.label)"
        return Weapon(name: name, type: type, rarity: rarity, bonus: bonus,
                      element: element, skillPositions: positions)
    }

    // MARK: - 防具

    private static let armorNamePrefixes = ["ぼろの", "革の", "騎士の", "隠者の", "王家の", "夜闇の"]

    static func randomArmor(rarity: Rarity? = nil) -> Armor {
        let type = ArmorType.allCases.randomElement()!
        let rarity = rarity ?? rollEquipmentRarity()
        let weight = max(1, type.baseWeight + Int.random(in: -5...5))

        // 重量が高いほど防御・HPの基礎上昇値が高い
        let bonus = BaseStats(
            hp: weight / 2 * rarity.rawValue,
            attack: 0,
            defense: weight / 4 * rarity.rawValue,
            speed: 0,
            magic: type == .robe ? 4 * rarity.rawValue : 0
        )

        // 星と同じ数のパッシブを防具種の傾向から付与(強化で順に解放)
        let pool = type.passivePool
        let valueScale = type == .ring ? 1 : 2 // 指輪は微量
        let passives = (0..<rarity.rawValue).compactMap { _ in
            pool.randomElement().map {
                Passive(kind: $0, value: Int.random(in: 4...12) * valueScale * rarity.rawValue)
            }
        }

        let name = "\(armorNamePrefixes.randomElement()!)\(type.label)"
        return Armor(name: name, type: type, rarity: rarity, weight: weight,
                     bonus: bonus, passives: passives)
    }

    /// 装備の星の抽選(基本: 星1 80% / 星2 17% / 星3 3%)
    static func rollEquipmentRarity() -> Rarity {
        let x = Double.random(in: 0..<100)
        if x < 80 { return .star1 }
        if x < 97 { return .star2 }
        return .star3
    }

    // MARK: - 卵

    /// 卵の種類の抽選(基本: 普通80% / 珍しい17% / 伝説3%)
    static func rollEggGrade() -> EggGrade {
        let x = Double.random(in: 0..<100)
        if x < 80 { return .normal }
        if x < 97 { return .uncommon }
        return .legendary
    }

    static func makeEgg(grade: EggGrade, fixedSpeciesID: String? = nil, now: Date = Date()) -> Egg {
        Egg(grade: grade, fixedSpeciesID: fixedSpeciesID, obtainedAt: now)
    }

    /// 卵からオトモを孵化させる。星・種族・個体値は孵化時に確定する。
    /// 伝説キャラは伝説の卵の星3枠(のうち30%)からのみ生まれる
    static func hatch(_ egg: Egg) -> Otomo {
        let rarity = egg.grade.rollRarity()

        let species: OtomoSpecies
        if let fixed = egg.fixedSpeciesID {
            species = OtomoCatalog.species(id: fixed)
        } else if egg.grade == .legendary, rarity == .star3,
                  Double.random(in: 0..<100) < EggGrade.legendarySpeciesChanceInStar3 {
            let pool = OtomoCatalog.all.filter { $0.category == .legendary }
            species = pool.randomElement() ?? OtomoCatalog.all[1]
        } else {
            let pool = OtomoCatalog.all.filter { $0.category != .legendary && $0.category != .mythic }
            species = pool.randomElement() ?? OtomoCatalog.all[1]
        }

        var otomo = Otomo(speciesID: species.id, rarity: rarity)
        // 個体値: 星1・2は完全ランダム、星3はプラス寄り。伝説の卵は優遇
        otomo.ivs = IndividualValues.roll(rarity: rarity, favored: egg.grade == .legendary)
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

    // MARK: - ショップ(枠ごとに 基本60% / やや珍しい39% / 低確率1%)

    static func randomShopItems(now: Date = Date()) -> [ShopItem] {
        (0..<ShopState.itemCount).map { _ in shopItem(tier: ShopTier.roll()) }
    }

    private static func shopItem(tier: ShopTier) -> ShopItem {
        switch tier {
        case .basic:
            switch Int.random(in: 0..<4) {
            case 0:
                let element = Element.allCases.randomElement()!
                return ShopItem(tier: tier, kind: .elementStone,
                                name: "\(element.label)の石", price: Int.random(in: 120...200),
                                detail: "\(element.label)属性キャラの進化に使う", element: element)
            case 1:
                return ShopItem(tier: tier, kind: .material,
                                name: "強化素材の束", price: Int.random(in: 80...150),
                                detail: "装備の強化に使う素材×5", amount: 5)
            case 2:
                return ShopItem(tier: tier, kind: .egg,
                                name: EggGrade.normal.label, price: Int.random(in: 250...400),
                                detail: "孵化に2時間。何が生まれるかはお楽しみ", eggGrade: .normal)
            default:
                return ShopItem(tier: tier, kind: .coinPack,
                                name: "小さなコイン袋", price: Int.random(in: 80...150),
                                detail: "開けるとコインが少し増える(気がする)")
            }
        case .uncommon:
            switch Int.random(in: 0..<3) {
            case 0:
                let element = Element.allCases.randomElement()!
                return ShopItem(tier: tier, kind: .elementStone,
                                name: "\(element.label)の石×3", price: Int.random(in: 300...450),
                                detail: "\(element.label)属性キャラの進化に使う", element: element, amount: 3)
            case 1:
                return ShopItem(tier: tier, kind: .material,
                                name: "強化素材の大束", price: Int.random(in: 200...320),
                                detail: "装備の強化に使う素材×15", amount: 15)
            default:
                return ShopItem(tier: tier, kind: .egg,
                                name: EggGrade.uncommon.label, price: Int.random(in: 700...1000),
                                detail: "孵化に5時間。星2以上が出やすい", eggGrade: .uncommon)
            }
        case .lowChance:
            switch Int.random(in: 0..<4) {
            case 0:
                return ShopItem(tier: tier, kind: .guildTicket,
                                name: "ギルドチケット", price: Int.random(in: 400...600),
                                detail: "その日のスカウトをもう一度行える")
            case 1:
                return ShopItem(tier: tier, kind: .armor,
                                name: "星3防具くじ", price: Int.random(in: 1000...1500),
                                detail: "星3の防具がランダムで1つ", equipRarity: .star3)
            case 2:
                return ShopItem(tier: tier, kind: .weapon,
                                name: "星3武器くじ", price: Int.random(in: 1000...1500),
                                detail: "星3の武器がランダムで1つ", equipRarity: .star3)
            default:
                return ShopItem(tier: tier, kind: .egg,
                                name: EggGrade.legendary.label, price: Int.random(in: 1800...2600),
                                detail: "孵化に10時間。星2以上確定、稀に伝説のオトモも。個体値優遇",
                                eggGrade: .legendary)
            }
        }
    }
}
