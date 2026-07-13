import Foundation

/// 状態異常。解除判定はかかったキャラの行動の終わりに行う
enum Ailment: String, CaseIterable, Codable, Hashable {
    case poison     // 毒: 現在HPの5%のダメージを行動ごとに受ける
    case brainwash  // 洗脳: スロットが50%で通常攻撃に変わる
    case burn       // 火傷: かかったキャラの攻撃力の25%のダメージを行動ごとに受ける
    case reverse    // 逆光: スロットが逆に回る。1→3を跨いだら必殺ターンも1下がる
    case weakness   // 弱体化: 被ダメージ20%アップ
    case attackDown // 攻撃低下: 攻撃30%低下
    case speedDown  // 速度低下: 速度30%低下

    var label: String {
        switch self {
        case .poison: "毒"
        case .brainwash: "洗脳"
        case .burn: "火傷"
        case .reverse: "逆光"
        case .weakness: "弱体化"
        case .attackDown: "攻撃低下"
        case .speedDown: "速度低下"
        }
    }

    /// 行動の終わりに解除される確率(%)
    var cureChance: Int {
        switch self {
        case .poison: 20
        case .brainwash: 40
        case .burn: 30
        case .reverse: 40
        case .weakness: 30
        case .attackDown: 30
        case .speedDown: 40
        }
    }
}

/// スキル種別(通常技とは別。武器付与 or キャラ習得)
enum SkillKind: String, Codable, CaseIterable {
    case attack, specialAttack, magic, heal, buff, debuff, barrier

    var label: String {
        switch self {
        case .attack: "攻撃"
        case .specialAttack: "特殊攻撃"
        case .magic: "魔法"
        case .heal: "回復"
        case .buff: "バフ"
        case .debuff: "デバフ"
        case .barrier: "バリア"
        }
    }

    var symbolName: String {
        switch self {
        case .attack: "figure.fencing"
        case .specialAttack: "burst.fill"
        case .magic: "sparkles"
        case .heal: "cross.case.fill"
        case .buff: "arrow.up.circle.fill"
        case .debuff: "arrow.down.circle.fill"
        case .barrier: "shield.fill"
        }
    }
}

/// 武器種由来のスキル効果傾向(戦闘アクションへの変換ヒント)。
/// 会心・複数回攻撃などの特徴は武器種そのものではなくスキルが持つ
enum WeaponEffect: String, Codable, Hashable {
    case single     // 剣: 単体
    case aoe        // 大剣: 全体攻撃
    case crit       // 短剣: クリティカル
    case multiHit   // 双剣: 複数回攻撃
    case magic      // 杖: 魔力依存
    case randomHits // リボルバー: ランダムな回数攻撃
    case debuff     // 弓: デバフ
}

/// スキルの対象(攻撃系=敵、回復系=味方に読み替える)
enum SkillTargetKind: String, Codable, Hashable {
    case single   // 単体
    case all      // 全体
    case random2  // ランダム2体
}

struct Skill: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: SkillKind
    /// 威力・効果量(攻撃力/魔力に対する百分率。バリアは防御上昇%)
    var power: Int
    var element: Element?
    /// 武器スキルの場合の効果傾向
    var weaponEffect: WeaponEffect?
    /// 抽選レアリティ(普通/やや珍しい/珍しい)。抽選以外で得たスキルは nil
    var tier: DrawTier?
    /// 対象(nil = 単体)
    var target: SkillTargetKind?
    /// 付与する状態異常とその確率(%)
    var ailment: Ailment?
    var ailmentChance: Int = 0
    /// 回復のとき: true なら対象の最大HPの power% を回復(割合回復)
    var percentBased: Bool = false

    /// スキル効果の説明文。戦闘での実際の挙動(BattleSetup.action(from:))と対応させる
    var effectText: String {
        let elem = element.map { "\($0.label)属性で" } ?? ""
        var base: String
        if let weaponEffect {
            switch weaponEffect {
            case .single: base = "\(elem)敵単体に攻撃力\(power)%のダメージ"
            case .aoe: base = "\(elem)敵全体に攻撃力\(power)%のダメージ"
            case .crit: base = "\(elem)敵単体に攻撃力\(power)%(40%で会心2倍)"
            case .multiHit: base = "\(elem)敵単体に攻撃力\(power)%のダメージを2回"
            case .magic: base = "\(elem)敵単体に魔力\(power)%のダメージ"
            case .randomHits: base = "\(elem)敵単体に攻撃力\(power)%のダメージを1〜5回"
            case .debuff: base = "\(elem)敵単体に攻撃力\(power)% + 40%で攻撃低下か速度低下"
            }
        } else {
            let tgt = target ?? .single
            let enemyTarget = tgt == .all ? "敵全体" : tgt == .random2 ? "ランダムな敵2体" : "敵単体"
            switch kind {
            case .attack, .specialAttack:
                base = "\(elem)\(enemyTarget)に攻撃力\(power)%のダメージ"
            case .magic:
                base = "\(elem)\(enemyTarget)に魔力\(power)%のダメージ"
            case .heal:
                let healTarget = tgt == .all ? "味方全体" : "最もHPの低い味方"
                base = percentBased
                    ? "\(healTarget)の最大HPの\(power)%を回復"
                    : "\(healTarget)を魔力×\(power)%回復"
            case .buff:
                base = "自分の攻撃を\(max(5, power / 10))%上げる(次の行動まで)"
            case .debuff:
                base = "\(enemyTarget)の素早さを\(max(5, power / 10))%下げる(次の行動まで)"
            case .barrier:
                base = "防御+\(power)%(自分のスロット2回発動まで)"
            }
        }
        if let ailment, ailmentChance > 0 {
            base += " + \(ailmentChance)%で\(ailment.label)"
        }
        return base
    }
}

/// 通常攻撃(空きスロット)の効果説明
enum NormalAttackInfo {
    static let effectText = "敵単体に攻撃力100%のダメージ"
}

/// 必殺技(スロット一定周回で発動)
enum UltimateKind: String, Codable, CaseIterable {
    case damageSingle      // 単純火力(単体)
    case damageAll         // 単純火力(全体)
    case buff
    case heal
    case triggerWeaponSkills // 全員の武器スキルをそれぞれ一回発動
    case extraActions        // 次回攻撃ターンまで他キャラ2回行動
    case stopEnemies         // 一定時間敵の行動停止
    case barrier

    var label: String {
        switch self {
        case .damageSingle: "単体火力"
        case .damageAll: "全体火力"
        case .buff: "バフ"
        case .heal: "回復"
        case .triggerWeaponSkills: "武器スキル一斉発動"
        case .extraActions: "追加行動付与"
        case .stopEnemies: "敵行動停止"
        case .barrier: "バリア"
        }
    }
}

struct UltimateSkill: Codable, Hashable {
    var name: String
    var kind: UltimateKind
    var power: Int
    /// 発動に必要なスロット周回数(必殺技の強さで決まる)
    var requiredLoops: Int

    /// 必殺技の強さ(威力%)に応じた必要周回数。敵味方共通ルール。
    /// 今後ダメージ以外の必殺技を実装する際は、効果の強さに応じて別途調整する
    static func loops(forPower power: Int) -> Int {
        if power <= 250 { return 2 }
        if power <= 330 { return 3 }
        return 4
    }
}

/// パッシブ(防具・キャラ・オトモが持つ。抽選プールは SkillCatalog で管理)
enum PassiveKind: String, Codable, CaseIterable {
    case doubleAct        // ランダムで2回行動(未実装)
    case statBoost        // ステータス上昇
    case oddSlotBoost     // 奇数番目強化
    case evenSlotBoost    // 偶数番目強化
    case firstLoopBoost   // 1周目強化
    case secondLoopBoost  // 2周目強化
    case emptySlotBoost   // 空きスロットの通常攻撃強化
    case elementBoost     // 属性強化
    case otomoBoost       // オトモステータスアップ(未実装)
    case lowHPBoost       // HP低下で強化(未実装)
    case flatDamage       // 特定行動に固定ダメージ追加(未実装)
    case miniBarrier      // プチバリア

    var label: String {
        switch self {
        case .doubleAct: "二回行動(確率)"
        case .statBoost: "ステータス上昇"
        case .oddSlotBoost: "奇数スロット強化"
        case .evenSlotBoost: "偶数スロット強化"
        case .firstLoopBoost: "一周目強化"
        case .secondLoopBoost: "二周目強化"
        case .emptySlotBoost: "通常攻撃強化"
        case .elementBoost: "属性強化"
        case .otomoBoost: "オトモ強化"
        case .lowHPBoost: "背水の陣"
        case .flatDamage: "固定ダメージ追加"
        case .miniBarrier: "プチバリア"
        }
    }

    /// 強パッシブかどうか(強い効果ほど軽い防具=指輪に付く)
    var isStrong: Bool {
        switch self {
        case .doubleAct, .lowHPBoost: true
        default: false
        }
    }

    /// パッシブ効果の説明文(戦闘での実挙動と対応。未実装のものは今後実装)
    var effectDescription: String {
        switch self {
        case .doubleAct: "確率で2回行動する"
        case .statBoost: "全ステータスが上がる"
        case .oddSlotBoost: "奇数番スロットの技のダメージが上がる"
        case .evenSlotBoost: "偶数番スロットの技のダメージが上がる"
        case .firstLoopBoost: "1周目の技のダメージが上がる"
        case .secondLoopBoost: "2周目の技のダメージが上がる"
        case .emptySlotBoost: "空きスロットの通常攻撃のダメージが上がる"
        case .elementBoost: "自属性の攻撃ダメージが上がる"
        case .otomoBoost: "オトモのステータスが上がる"
        case .lowHPBoost: "HPが低いほど強化される"
        case .flatDamage: "攻撃に固定ダメージを追加する"
        case .miniBarrier: "開戦時に最大HPに応じたバリアを張る"
        }
    }
}

struct Passive: Codable, Hashable {
    var kind: PassiveKind
    /// 効果量(%)
    var value: Int
    /// 抽選レアリティ(普通/やや珍しい/珍しい)
    var tier: DrawTier?
}
