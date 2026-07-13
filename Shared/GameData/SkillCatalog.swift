import Foundation

// MARK: - 抽選レアリティ(強さ3段階)

/// スキル・パッシブの抽選カテゴリ。強いものほど珍しい。
/// 新しいスキル/パッシブは SkillCatalog の該当プールにエントリを追加するだけで
/// 抽選対象になる(コード側の抽選ロジックは共通)。
enum DrawTier: String, Codable, CaseIterable {
    case common    // 普通
    case uncommon  // やや珍しい
    case rare      // 珍しい

    var label: String {
        switch self {
        case .common: "普通"
        case .uncommon: "やや珍しい"
        case .rare: "珍しい"
        }
    }

    /// 排出重み(%)。抽選率の調整はここ一箇所で行う
    var weight: Double {
        switch self {
        case .common: 70
        case .uncommon: 25
        case .rare: 5
        }
    }
}

/// 抽選対象の共通インターフェース
protocol DrawableEntry {
    var tier: DrawTier { get }
}

// MARK: - エントリ(雛形)

/// 抽選テーブルに登録するスキルの雛形。実体化時に属性と威力スケールを与える
struct SkillEntry: Identifiable, DrawableEntry {
    let id: String
    let tier: DrawTier
    let name: String
    let kind: SkillKind
    let power: Int
    var weaponEffect: WeaponEffect?
    /// 対象(nil = 単体)
    var target: SkillTargetKind?
    /// 付与する状態異常と確率(%)。目安: 普通20 / やや珍しい30 / 珍しい40
    var ailment: Ailment?
    var ailmentChance: Int = 0
    /// 回復のとき: 最大HPの power% を回復する割合回復
    var percentBased: Bool = false

    init(_ id: String, _ tier: DrawTier, _ name: String, _ kind: SkillKind, _ power: Int,
         _ weaponEffect: WeaponEffect? = nil,
         target: SkillTargetKind? = nil,
         ailment: Ailment? = nil, ailmentChance: Int = 0,
         percentBased: Bool = false) {
        self.id = id
        self.tier = tier
        self.name = name
        self.kind = kind
        self.power = power
        self.weaponEffect = weaponEffect
        self.target = target
        self.ailment = ailment
        self.ailmentChance = ailmentChance
        self.percentBased = percentBased
    }

    func make(element: Element?, powerScale: Double = 1.0) -> Skill {
        Skill(name: name, kind: kind, power: max(1, Int(Double(power) * powerScale)),
              element: element, weaponEffect: weaponEffect, tier: tier,
              target: target, ailment: ailment, ailmentChance: ailmentChance,
              percentBased: percentBased)
    }
}

/// 抽選テーブルに登録するパッシブの雛形
struct PassiveEntry: Identifiable, DrawableEntry {
    let id: String
    let tier: DrawTier
    let kind: PassiveKind
    let valueRange: ClosedRange<Int>

    init(_ id: String, _ tier: DrawTier, _ kind: PassiveKind, _ valueRange: ClosedRange<Int>) {
        self.id = id
        self.tier = tier
        self.kind = kind
        self.valueRange = valueRange
    }

    func make(valueScale: Double = 1.0) -> Passive {
        Passive(kind: kind, value: max(1, Int(Double(Int.random(in: valueRange)) * valueScale)),
                tier: tier)
    }
}

// MARK: - カタログ本体

/// スキル・パッシブの抽選テーブル。
/// 「どのキャラ/装備に何が出るか」はここのプール定義だけで管理する。
enum SkillCatalog {

    // MARK: 武器スキル(武器種ごとのプール)

    static let weaponSkills: [WeaponType: [SkillEntry]] = [
        .sword: [
            SkillEntry("sword_c1", .common, "強斬り", .attack, 130, .single),
            SkillEntry("sword_u1", .uncommon, "渾身の一撃", .attack, 170, .single),
            SkillEntry("sword_r1", .rare, "秘剣・一閃", .attack, 220, .single),
        ],
        .greatsword: [
            SkillEntry("gs_c1", .common, "薙ぎ払い", .attack, 80, .aoe),
            SkillEntry("gs_u1", .uncommon, "大回転斬り", .attack, 100, .aoe),
            SkillEntry("gs_r1", .rare, "断罪の一振り", .attack, 130, .aoe),
        ],
        .dagger: [
            SkillEntry("dg_c1", .common, "急所突き", .attack, 90, .crit),
            SkillEntry("dg_u1", .uncommon, "背刺し", .attack, 110, .crit),
            SkillEntry("dg_r1", .rare, "絶命の刃", .attack, 140, .crit),
        ],
        .twinBlade: [
            SkillEntry("tb_c1", .common, "二連撃", .attack, 65, .multiHit),
            SkillEntry("tb_u1", .uncommon, "連舞", .attack, 80, .multiHit),
            SkillEntry("tb_r1", .rare, "残像剣", .attack, 100, .multiHit),
        ],
        .staff: [
            SkillEntry("st_c1", .common, "魔力弾", .magic, 120, .magic),
            SkillEntry("st_u1", .uncommon, "魔閃光", .magic, 150, .magic),
            SkillEntry("st_r1", .rare, "星霜の理", .magic, 190, .magic),
        ],
        .revolver: [
            SkillEntry("rv_c1", .common, "乱れ撃ち", .attack, 45, .randomHits),
            SkillEntry("rv_u1", .uncommon, "速射", .attack, 55, .randomHits),
            SkillEntry("rv_r1", .rare, "デッドアイ", .attack, 70, .randomHits),
        ],
        .bow: [
            SkillEntry("bw_c1", .common, "狙い撃ち", .debuff, 80, .debuff),
            SkillEntry("bw_u1", .uncommon, "鷹の目", .debuff, 100, .debuff),
            SkillEntry("bw_r1", .rare, "呪縛の矢", .debuff, 120, .debuff),
        ],
    ]

    // MARK: 防具パッシブ(防具種ごとのプール)

    /// 共通エントリ定義(プールから id で参照される)
    private static let passiveEntries: [PassiveEntry] = [
        // 普通
        PassiveEntry("p_stat", .common, .statBoost, 4...8),
        PassiveEntry("p_mini", .common, .miniBarrier, 5...10),
        PassiveEntry("p_empty", .common, .emptySlotBoost, 5...10),
        // やや珍しい
        PassiveEntry("p_odd", .uncommon, .oddSlotBoost, 8...15),
        PassiveEntry("p_even", .uncommon, .evenSlotBoost, 8...15),
        PassiveEntry("p_loop1", .uncommon, .firstLoopBoost, 8...15),
        PassiveEntry("p_loop2", .uncommon, .secondLoopBoost, 8...15),
        PassiveEntry("p_elem", .uncommon, .elementBoost, 8...15),
        PassiveEntry("p_otomo", .uncommon, .otomoBoost, 8...15),
        // 珍しい
        PassiveEntry("p_double", .rare, .doubleAct, 5...10),
        PassiveEntry("p_lowhp", .rare, .lowHPBoost, 15...25),
        PassiveEntry("p_flat", .rare, .flatDamage, 10...20),
    ]

    private static func passives(_ ids: [String]) -> [PassiveEntry] {
        ids.compactMap { id in passiveEntries.first { $0.id == id } }
    }

    /// 防具種ごとに出るパッシブの管理(鎧=防御系 / マント=属性系 / ローブ=魔力・オトモ系 / 指輪=強レア寄り)。
    /// 各プールにレア度3段階が揃うようにしておくと排出率(70/25/5)が安定する
    static let armorPassives: [ArmorType: [PassiveEntry]] = [
        .plate: passives(["p_stat", "p_mini", "p_empty", "p_loop1", "p_lowhp"]),
        .cloak: passives(["p_stat", "p_mini", "p_elem", "p_odd", "p_even", "p_flat"]),
        .robe: passives(["p_stat", "p_empty", "p_loop2", "p_otomo", "p_elem", "p_lowhp"]),
        .ring: passives(["p_empty", "p_mini", "p_loop1", "p_double", "p_lowhp", "p_flat"]),
    ]

    // MARK: オトモスキル(カテゴリ共通プール+種族固有プール)

    /// カテゴリ共通で出るスキル。
    /// 威力の目安: 普通90〜130 / やや珍しい130〜180 / 珍しい180〜240(単体基準)。
    /// 全体は単体の約60%、状態異常付与は 普通20 / やや珍30 / 珍40%
    static let otomoCategorySkills: [OtomoCategory: [SkillEntry]] = [
        .ground: [
            SkillEntry("gr_c1", .common, "かみつき", .attack, 110),
            SkillEntry("gr_c2", .common, "ひっかき", .attack, 95),
            SkillEntry("gr_u1", .uncommon, "突進", .attack, 150),
            SkillEntry("gr_u2", .uncommon, "毒牙", .attack, 120, ailment: .poison, ailmentChance: 30),
            SkillEntry("gr_r1", .rare, "大暴れ", .specialAttack, 130, target: .all),
            SkillEntry("gr_r2", .rare, "捕食", .specialAttack, 220),
        ],
        .aquatic: [
            SkillEntry("aq_c1", .common, "水鉄砲", .magic, 110),
            SkillEntry("aq_c2", .common, "体当たり", .attack, 100),
            SkillEntry("aq_c3", .common, "水の膜", .barrier, 15),
            SkillEntry("aq_u1", .uncommon, "渦潮", .magic, 100, target: .random2),
            SkillEntry("aq_u2", .uncommon, "冷水", .magic, 130, ailment: .speedDown, ailmentChance: 30),
            SkillEntry("aq_r1", .rare, "大津波", .specialAttack, 140, target: .all),
            SkillEntry("aq_r2", .rare, "命の潮", .heal, 20, target: .all, percentBased: true),
        ],
        .bird: [
            SkillEntry("bd_c1", .common, "つつく", .attack, 100),
            SkillEntry("bd_c2", .common, "羽ばたき", .attack, 90, target: .random2),
            SkillEntry("bd_u1", .uncommon, "急降下", .attack, 155),
            SkillEntry("bd_u2", .uncommon, "目つぶし", .attack, 110, ailment: .attackDown, ailmentChance: 30),
            SkillEntry("bd_r1", .rare, "風切羽", .specialAttack, 135, target: .all),
        ],
        .insect: [
            SkillEntry("in_c1", .common, "針刺し", .attack, 100),
            SkillEntry("in_c2", .common, "群がり", .attack, 65, target: .random2),
            SkillEntry("in_u1", .uncommon, "毒針", .attack, 120, ailment: .poison, ailmentChance: 30),
            SkillEntry("in_u2", .uncommon, "麻痺鱗粉", .attack, 100, ailment: .speedDown, ailmentChance: 30),
            SkillEntry("in_r1", .rare, "百足乱舞", .specialAttack, 200),
        ],
        .special: [
            SkillEntry("sp_c1", .common, "ぷにぷに", .attack, 95),
            SkillEntry("sp_c2", .common, "やわらか壁", .barrier, 15),
            SkillEntry("sp_u1", .uncommon, "ふくらむ", .buff, 100),
            SkillEntry("sp_r1", .rare, "はじける", .specialAttack, 130, target: .all),
        ],
        .legendary: [
            SkillEntry("lg_c1", .common, "爪撃", .attack, 125),
            SkillEntry("lg_u1", .uncommon, "咆哮", .buff, 130),
            SkillEntry("lg_u2", .uncommon, "ブレス", .magic, 110, target: .all, ailment: .burn, ailmentChance: 30),
            SkillEntry("lg_r1", .rare, "神威", .specialAttack, 150, target: .all),
            SkillEntry("lg_r2", .rare, "竜鱗", .barrier, 30),
        ],
        .mythic: [
            SkillEntry("my_c1", .common, "異形の触手", .attack, 130),
            SkillEntry("my_u1", .uncommon, "狂気の囁き", .attack, 120, ailment: .brainwash, ailmentChance: 30),
            SkillEntry("my_r1", .rare, "星の彼方", .specialAttack, 150, target: .all, ailment: .weakness, ailmentChance: 40),
        ],
    ]

    /// 種族固有で追加されるスキル(speciesID → エントリ)。
    /// 「このキャラにだけ出したい」スキルはここに足す
    static let otomoSpeciesSkills: [String: [SkillEntry]] = [
        "spider": [SkillEntry("spider_u1", .uncommon, "イト吐き", .debuff, 100)],
        "bee": [SkillEntry("bee_u1", .uncommon, "毒針の一撃", .attack, 130, ailment: .poison, ailmentChance: 30)],
        "octopus": [SkillEntry("octo_u1", .uncommon, "タコヒール", .heal, 100)],
        "snake": [SkillEntry("snake_u1", .uncommon, "絞めつけ", .attack, 110, ailment: .speedDown, ailmentChance: 30)],
        "phoenix": [SkillEntry("phx_r1", .rare, "再生の炎", .heal, 25, target: .all, percentBased: true)],
        "unicorn": [SkillEntry("uni_u1", .uncommon, "癒しの角", .heal, 120)],
        "medjed": [SkillEntry("mjd_r1", .rare, "メジェドの目", .attack, 180, ailment: .brainwash, ailmentChance: 40)],
    ]

    /// オトモのパッシブプール(付与時に効果値0.7倍で弱められる)
    static let otomoPassives: [PassiveEntry] =
        passives(["p_stat", "p_empty", "p_odd", "p_even", "p_elem", "p_mini", "p_lowhp"])

    /// 種族のスキル抽選プール(カテゴリ共通+種族固有)
    static func otomoPool(for species: OtomoSpecies) -> [SkillEntry] {
        (otomoCategorySkills[species.category] ?? []) + (otomoSpeciesSkills[species.id] ?? [])
    }

    // MARK: ジョブ(メインキャラ)のレベル習得プール

    /// ジョブごとに出るスキルの管理(Lv10/70の習得抽選用)。
    /// 未定義のジョブは jobDefaultSkills から抽選される
    static let jobSkills: [String: [SkillEntry]] = [:]

    /// ジョブ共通のスキルプール(Lv10/70)。バリアは 15/20/30% の3段階
    static let jobDefaultSkills: [SkillEntry] = [
        SkillEntry("job_c1", .common, "薙ぎの一撃", .attack, 120),
        SkillEntry("job_c2", .common, "気合いため", .buff, 100),
        SkillEntry("job_c3", .common, "応急手当", .heal, 80),
        SkillEntry("job_c4", .common, "身がまえ", .barrier, 15),
        SkillEntry("job_u1", .uncommon, "闘気斬", .specialAttack, 160),
        SkillEntry("job_u2", .uncommon, "威圧", .debuff, 120),
        SkillEntry("job_u3", .uncommon, "鉄壁", .barrier, 20),
        SkillEntry("job_u4", .uncommon, "薙ぎ払い", .attack, 90, target: .all),
        SkillEntry("job_r1", .rare, "極撃", .specialAttack, 220),
        SkillEntry("job_r2", .rare, "絶対防御", .barrier, 30),
        SkillEntry("job_r3", .rare, "燃焼撃", .attack, 160, ailment: .burn, ailmentChance: 40),
    ]

    /// ジョブごとに出るパッシブの管理(Lv30/60/80の習得抽選用)。
    /// 未定義のジョブは characterPassives から抽選される
    static let jobPassives: [String: [PassiveEntry]] = [:]

    /// キャラ共通のパッシブプール(Lv30/60/80)
    static let characterPassives: [PassiveEntry] =
        passives(["p_stat", "p_empty", "p_odd", "p_even", "p_elem", "p_lowhp", "p_double"])

    // MARK: - 抽選

    /// レアリティ重み付きで1件抽選する。
    /// まずレア度を重み(70/25/5)で決め、そのレア度の中から均等に選ぶ。
    /// エントリを何件追加しても各レア度の排出率は変わらない
    static func draw<T: DrawableEntry>(from pool: [T]) -> T? {
        guard !pool.isEmpty else { return nil }
        let byTier = Dictionary(grouping: pool) { $0.tier }
        let present = DrawTier.allCases.filter { byTier[$0] != nil }
        let total = present.reduce(0.0) { $0 + $1.weight }
        var x = Double.random(in: 0..<total)
        for tier in present {
            x -= tier.weight
            if x < 0 { return byTier[tier]!.randomElement() }
        }
        return byTier[present.last!]!.randomElement()
    }

    /// 重複なしで count 件抽選する(プールが足りなければあるだけ)
    static func draw<T: DrawableEntry & Identifiable>(from pool: [T], count: Int) -> [T] {
        var remaining = pool
        var result: [T] = []
        for _ in 0..<count {
            guard let picked = draw(from: remaining) else { break }
            result.append(picked)
            remaining.removeAll { $0.id == picked.id }
        }
        return result
    }
}
