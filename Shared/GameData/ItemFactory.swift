import Foundation

/// 武器・防具・卵・ショップ商品などのランダム生成
enum ItemFactory {

    // MARK: - 武器

    private static let weaponNamePrefixes = ["錆びた", "鉄の", "無銘の", "輝く", "呪われた", "月光の", "深淵の"]

    /// 武器種のプール(SkillCatalog)からレアリティ重み付きで抽選する
    private static func weaponSkill(for type: WeaponType, rarity: Rarity, element: Element?) -> Skill {
        let pool = SkillCatalog.weaponSkills[type] ?? []
        let scale = 1.0 + Double(rarity.rawValue) * 0.15
        if let entry = SkillCatalog.draw(from: pool) {
            return entry.make(element: element, powerScale: scale)
        }
        // プール未定義時の保険
        return Skill(name: "一撃", kind: .attack, power: Int(100 * scale),
                     element: element, weaponEffect: .single)
    }

    static func randomWeapon(rarity: Rarity? = nil, type: WeaponType? = nil) -> Weapon {
        let type = type ?? WeaponType.allCases.randomElement()!
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

        // 星と同じ数のパッシブを防具種のプール(SkillCatalog)から抽選(強化で順に解放)
        let pool = SkillCatalog.armorPassives[type] ?? []
        let valueScale = 0.5 + Double(rarity.rawValue) * 0.5 // 星1=1.0 / 星2=1.5 / 星3=2.0
        let passives = SkillCatalog.draw(from: pool, count: rarity.rawValue)
            .map { $0.make(valueScale: valueScale) }

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

        // スキルはカテゴリ+種族のプール(SkillCatalog)からレアリティ重み付きで抽選し、
        // ランダムなスロット位置に付与する(星3は3個、それ以外は1〜2個)
        let pool = SkillCatalog.otomoPool(for: species)
        let count = rarity == .star3 ? 3 : Int.random(in: 1...2)
        let entries = SkillCatalog.draw(from: pool, count: count)
        var positions = Array(0..<otomo.slotCount).shuffled()
        for entry in entries {
            guard !positions.isEmpty else { break }
            otomo.skillPositions[positions.removeFirst()] = entry.make(element: species.element)
        }

        // パッシブを1個付与(メインキャラ・防具より弱め=効果値0.7倍)
        if let passiveEntry = SkillCatalog.draw(from: SkillCatalog.otomoPassives) {
            otomo.passives = [passiveEntry.make(valueScale: 0.7)]
        }

        if Int.random(in: 0..<5) == 0 { // 必殺技持ちは少なめ
            otomo.ultimate = UltimateSkill(name: "\(species.name)の咆哮", kind: .damageAll,
                                           power: 200, requiredLoops: UltimateSkill.loops(forPower: 200))
        }
        return otomo
    }

    // MARK: - ショップ(枠ごとに 基本60% / やや珍しい39% / 低確率1%)

    static func randomShopItems(now: Date = Date()) -> [ShopItem] {
        (0..<ShopState.itemCount).map { _ in shopItem(tier: ShopTier.roll()) }
    }

    /// ショップの価格は進化の石経済が基準:
    /// 進化には自属性の石が第一15個+第二30個=計45個必要。
    /// 石1個≒100コイン前後を軸に、まとめ売りほど割安にする
    private static func shopItem(tier: ShopTier) -> ShopItem {
        switch tier {
        case .basic:
            switch Int.random(in: 0..<4) {
            case 0:
                let element = Element.allCases.randomElement()!
                return ShopItem(tier: tier, kind: .elementStone,
                                name: "\(element.label)の石", price: Int.random(in: 90...130),
                                detail: "\(element.label)属性キャラの進化に使う(進化には15/30個必要)",
                                element: element)
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
                                name: "\(element.label)の石×5", price: Int.random(in: 400...550),
                                detail: "\(element.label)属性キャラの進化に使う(まとめ売りで割安)",
                                element: element, amount: 5)
            case 1:
                return ShopItem(tier: tier, kind: .material,
                                name: "強化素材の大束", price: Int.random(in: 200...320),
                                detail: "装備の強化に使う素材×20", amount: 20)
            default:
                return ShopItem(tier: tier, kind: .egg,
                                name: EggGrade.uncommon.label, price: Int.random(in: 700...1000),
                                detail: "孵化に5時間。星2以上が出やすい", eggGrade: .uncommon)
            }
        case .lowChance:
            switch Int.random(in: 0..<5) {
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
            case 3:
                let element = Element.allCases.randomElement()!
                return ShopItem(tier: tier, kind: .elementStone,
                                name: "\(element.label)の石×15(進化セット)", price: Int.random(in: 1000...1400),
                                detail: "第一進化1回ぶんの石をまとめて入手", element: element, amount: 15)
            default:
                return ShopItem(tier: tier, kind: .egg,
                                name: EggGrade.legendary.label, price: Int.random(in: 1800...2600),
                                detail: "孵化に10時間。星2以上確定、稀に伝説のオトモも。個体値優遇",
                                eggGrade: .legendary)
            }
        }
    }
}
