import Foundation

/// メインキャラの固定キット。
/// スキル(Lv10/70)・パッシブ(Lv30/60/80)・必殺技(進化で習得)は
/// 職ごとに固定で、抽選しない(オトモ・装備は従来どおり抽選)。
struct JobKit {
    let skill10: Skill
    let skill70: Skill
    let passive30: Passive
    let passive60: Passive
    let passive80: Passive
    /// 第一必殺技(第一進化で習得。レア職は加入時から所持)
    let ultimate1: UltimateSkill?
    /// 第二必殺技(第二進化で更新)。一段階職・レア職は nil
    let ultimate2: UltimateSkill?
}

// 記述を短くするためのヘルパ
private func sk(_ name: String, _ kind: SkillKind, _ power: Int, _ element: Element?,
                effect: WeaponEffect? = nil, target: SkillTargetKind? = nil,
                ailment: Ailment? = nil, chance: Int = 0,
                drain: Int = 0, bonusVsAilment: Bool = false) -> Skill {
    Skill(name: name, kind: kind, power: power, element: element,
          weaponEffect: effect, target: target, ailment: ailment, ailmentChance: chance,
          drainPct: drain, bonusVsAilment: bonusVsAilment)
}

private func ps(_ kind: PassiveKind, _ value: Int) -> Passive {
    Passive(kind: kind, value: value)
}

private func ult(_ name: String, _ kind: UltimateKind, _ power: Int) -> UltimateSkill {
    UltimateSkill(name: name, kind: kind, power: power,
                  requiredLoops: UltimateSkill.loops(forPower: power))
}

extension JobCatalog {

    /// 職ID → 固定キット。全職ぶん定義する(パッシブは実装済みの種類のみ使用)
    static let kits: [String: JobKit] = [
        // MARK: 通常キャラ
        "swordsman": JobKit(
            skill10: sk("十字斬り", .attack, 140, .fire),
            skill70: sk("秘剣・燕返し", .attack, 210, .fire),
            passive30: ps(.statBoost, 6),
            passive60: ps(.oddSlotBoost, 12),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("一閃", .damageAll, 230),
            ultimate2: ult("剣豪の極み", .damageAll, 320)),
        "sage": JobKit(
            skill10: sk("癒しの水", .heal, 120, .water),
            skill70: sk("恵みの雨", .heal, 90, .water, target: .all),
            passive30: ps(.statBoost, 6),
            passive60: ps(.secondLoopBoost, 12),
            passive80: ps(.elementBoost, 12),
            ultimate1: ult("聖水の祝福", .heal, 230),
            ultimate2: ult("大賢者の恩寵", .heal, 320)),
        "berserker": JobKit(
            skill10: sk("怒りの一撃", .attack, 155, .fire),
            skill70: sk("破壊衝動", .attack, 240, .fire),
            passive30: ps(.evenSlotBoost, 10),
            passive60: ps(.elementBoost, 10),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("血の宴", .damageAll, 250),
            ultimate2: ult("修羅の咆哮", .damageAll, 340)),
        "mage": JobKit(
            skill10: sk("サンダーボルト", .magic, 150, .electric),
            skill70: sk("チェインライトニング", .magic, 120, .electric, target: .random2),
            passive30: ps(.elementBoost, 10),
            passive60: ps(.secondLoopBoost, 12),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("マナバースト", .damageAll, 230),
            ultimate2: ult("いかづちの極点", .damageAll, 320)),
        "archer": JobKit(
            skill10: sk("連射", .attack, 65, .electric, effect: .multiHit),
            skill70: sk("狙撃", .attack, 170, .electric, effect: .crit),
            passive30: ps(.firstLoopBoost, 10),
            passive60: ps(.oddSlotBoost, 12),
            passive80: ps(.elementBoost, 12),
            ultimate1: ult("矢の雨", .damageAll, 230),
            ultimate2: ult("流星群", .damageAll, 320)),
        "monk": JobKit(
            skill10: sk("連撃", .attack, 60, .fire, effect: .multiHit),
            skill70: sk("百裂拳", .attack, 45, .fire, effect: .randomHits),
            passive30: ps(.evenSlotBoost, 10),
            passive60: ps(.oddSlotBoost, 10),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("練気爆発", .damageAll, 230),
            ultimate2: ult("拳聖の型", .damageAll, 320)),
        "oni": JobKit(
            skill10: sk("金棒振り", .attack, 150, .dark),
            skill70: sk("鬼哭", .attack, 120, .dark, target: .all),
            passive30: ps(.statBoost, 6),
            passive60: ps(.counter, 20),
            passive80: ps(.elementBoost, 12),
            ultimate1: ult("鬼の宴", .damageAll, 230),
            ultimate2: ult("鬼神楽", .damageAll, 320)),
        "samurai": JobKit(
            skill10: sk("居合", .attack, 160, .fire),
            skill70: sk("兜割り", .attack, 230, .fire),
            passive30: ps(.firstLoopBoost, 12),
            passive60: ps(.oddSlotBoost, 12),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("燕一文字", .damageSingle, 250),
            ultimate2: ult("无明剣", .damageSingle, 340)),
        "ninja": JobKit(
            skill10: sk("手裏剣", .attack, 80, .dark, target: .random2),
            skill70: sk("影分身", .attack, 70, .dark, effect: .multiHit),
            passive30: ps(.evenSlotBoost, 10),
            passive60: ps(.elementBoost, 10),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("忍法・火遁", .damageAll, 230),
            ultimate2: ult("忍法・朧月", .damageAll, 320)),
        "assassin": JobKit(
            skill10: sk("毒刃", .attack, 120, .dark, ailment: .poison, chance: 30),
            skill70: sk("絶命突き", .attack, 160, .dark, effect: .crit),
            passive30: ps(.oddSlotBoost, 12),
            passive60: ps(.elementBoost, 10),
            passive80: ps(.statBoost, 10),
            ultimate1: ult("暗殺", .damageSingle, 250),
            ultimate2: ult("死告", .damageSingle, 340)),

        // MARK: 特殊戦闘キャラ
        "slot_machine": JobKit( // 必殺技なし(一巡ランダム効果は今後実装)
            skill10: sk("ラッキーヒット", .attack, 45, .electric, effect: .randomHits),
            skill70: sk("ジャックポット", .attack, 240, .electric),
            passive30: ps(.evenSlotBoost, 10),
            passive60: ps(.firstLoopBoost, 10),
            passive80: ps(.statBoost, 10),
            ultimate1: nil, ultimate2: nil),
        "time_keeper": JobKit(
            skill10: sk("時砕き", .debuff, 120, .water),
            skill70: sk("時間加速", .buff, 130, .water),
            passive30: ps(.statBoost, 6),
            passive60: ps(.secondLoopBoost, 12),
            passive80: ps(.elementBoost, 10),
            ultimate1: ult("時の楔", .stopEnemies, 230),
            ultimate2: nil),
        "beast_master": JobKit(
            skill10: sk("鞭打ち", .attack, 130, .fire),
            skill70: sk("野生の号令", .buff, 130, .fire),
            passive30: ps(.otomoBoost, 10),
            passive60: ps(.elementBoost, 10),
            passive80: ps(.otomoBoost, 15),
            ultimate1: ult("群れの咆哮", .damageAll, 230),
            ultimate2: nil),
        "zombie": JobKit(
            skill10: sk("かじりつき", .attack, 130, .dark, drain: 40),
            skill70: sk("病毒の爪", .attack, 140, .dark, ailment: .poison, chance: 40),
            passive30: ps(.drain, 15),
            passive60: ps(.statBoost, 8),
            passive80: ps(.lowHPBoost, 20),
            ultimate1: ult("死者の行進", .damageAll, 230),
            ultimate2: nil),

        // MARK: 特殊支援キャラ
        "monster_tamer": JobKit( // 進化なし=必殺技なし
            skill10: sk("応急手当", .heal, 100, .water),
            skill70: sk("仲間への号令", .buff, 120, .water),
            passive30: ps(.statBoost, 5),
            passive60: ps(.miniBarrier, 6),
            passive80: ps(.statBoost, 8),
            ultimate1: nil, ultimate2: nil),
        "professor": JobKit(
            skill10: sk("電撃実験", .magic, 130, .electric),
            skill70: sk("発明品・雷砲", .magic, 200, .electric),
            passive30: ps(.statBoost, 5),
            passive60: ps(.elementBoost, 8),
            passive80: ps(.statBoost, 8),
            ultimate1: ult("禁断の実験", .damageAll, 230),
            ultimate2: nil),
        "explorer": JobKit(
            skill10: sk("サーベル", .attack, 130, .fire),
            skill70: sk("罠仕掛け", .debuff, 130, .fire),
            passive30: ps(.statBoost, 5),
            passive60: ps(.firstLoopBoost, 8),
            passive80: ps(.statBoost, 8),
            ultimate1: ult("秘境の一撃", .damageSingle, 230),
            ultimate2: nil),
        "miner": JobKit(
            skill10: sk("ツルハシ", .attack, 135, .fire),
            skill70: sk("岩砕き", .attack, 180, .fire),
            passive30: ps(.miniBarrier, 6),
            passive60: ps(.statBoost, 8),
            passive80: ps(.emptySlotBoost, 8),
            ultimate1: ult("大発破", .damageAll, 230),
            ultimate2: nil),
        "thief": JobKit(
            skill10: sk("不意打ち", .attack, 125, .dark, effect: .crit),
            skill70: sk("早業", .attack, 150, .dark),
            passive30: ps(.oddSlotBoost, 8),
            passive60: ps(.statBoost, 8),
            passive80: ps(.elementBoost, 8),
            ultimate1: ult("宝物強奪", .damageSingle, 230),
            ultimate2: nil),
        "trainer": JobKit( // 進化なし=必殺技なし
            skill10: sk("びしばし指導", .attack, 120, .water),
            skill70: sk("熱血指導", .buff, 130, .water),
            passive30: ps(.statBoost, 5),
            passive60: ps(.otomoBoost, 12),
            passive80: ps(.miniBarrier, 8),
            ultimate1: nil, ultimate2: nil),

        // MARK: レアキャラ(進化なし・加入時から第一必殺技)
        "angel": JobKit(
            skill10: sk("裁きの雷", .magic, 160, .electric),
            skill70: sk("浄化の光", .heal, 90, .electric, target: .all),
            passive30: ps(.elementBoost, 10),
            passive60: ps(.statBoost, 8),
            passive80: ps(.miniBarrier, 10),
            ultimate1: ult("審判の雷", .damageAll, 250),
            ultimate2: nil),
        "akuma": JobKit(
            skill10: sk("魔炎", .attack, 140, .dark, ailment: .burn, chance: 20),
            skill70: sk("深淵の爪", .attack, 180, .dark, drain: 40),
            passive30: ps(.statBoost, 8),
            passive60: ps(.elementBoost, 10),
            passive80: ps(.evenSlotBoost, 10),
            ultimate1: ult("禊", .damageAll, 280),
            ultimate2: nil),
    ]

    static func kit(for jobID: String) -> JobKit? { kits[jobID] }
}
