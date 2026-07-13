import Foundation

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

/// 武器種由来のスキル効果傾向(戦闘アクションへの変換ヒント)
enum WeaponEffect: String, Codable, Hashable {
    case single     // 剣: 単体
    case aoe        // 大剣: 全体攻撃
    case crit       // 短剣: クリティカル
    case multiHit   // 双剣: 複数回攻撃
    case magic      // 杖: 魔力依存
    case randomHits // リボルバー: ランダムな回数攻撃
    case debuff     // 弓: デバフ
}

struct Skill: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: SkillKind
    /// 威力・効果量(攻撃力/魔力に対する百分率)
    var power: Int
    var element: Element?
    /// 武器スキルの場合の効果傾向
    var weaponEffect: WeaponEffect?
    /// 抽選レアリティ(普通/やや珍しい/珍しい)。抽選以外で得たスキルは nil
    var tier: DrawTier?

    /// スキル効果の説明文。戦闘での実際の挙動(BattleSetup.action(from:))と対応させる
    var effectText: String {
        let elem = element.map { "\($0.label)属性で" } ?? ""
        if let weaponEffect {
            switch weaponEffect {
            case .single: return "\(elem)敵単体に攻撃力\(power)%のダメージ"
            case .aoe: return "\(elem)敵全体に攻撃力\(power)%のダメージ"
            case .crit: return "\(elem)敵単体に攻撃力\(power)%(40%で会心2倍)"
            case .multiHit: return "\(elem)敵単体に攻撃力\(power)%のダメージを2回"
            case .magic: return "\(elem)敵単体に魔力\(power)%のダメージ"
            case .randomHits: return "\(elem)敵単体に攻撃力\(power)%のダメージを1〜5回"
            case .debuff: return "\(elem)敵単体に攻撃力\(power)% + 40%で攻撃低下か速度低下"
            }
        }
        switch kind {
        case .attack, .specialAttack: return "\(elem)敵単体に攻撃力\(power)%のダメージ"
        case .magic: return "\(elem)敵単体に魔力\(power)%のダメージ"
        case .heal: return "最もHPの低い味方を魔力のぶん回復"
        case .buff: return "自分の攻撃を\(max(5, power / 10))%上げる(次の行動まで)"
        case .debuff: return "敵単体の素早さを\(max(5, power / 10))%下げる(次の行動まで)"
        case .barrier: return "防御+30%(自分のスロット2回発動まで)"
        }
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
    /// 発動に必要なスロット周回数(基本3周、必殺技ごとに変動)
    var requiredLoops: Int
}

/// パッシブ(防具にランダム付与。強い効果は低重量防具に割り振られる)
enum PassiveKind: String, Codable, CaseIterable {
    case doubleAct        // ランダムで2回行動
    case statBoost        // ステータス上昇
    case oddSlotBoost     // 奇数番目強化
    case evenSlotBoost    // 偶数番目強化
    case firstLoopBoost   // 1周目強化
    case secondLoopBoost  // 2周目強化
    case emptySlotBoost   // 空きスロット攻撃強化
    case elementBoost     // 属性強化
    case otomoBoost       // オトモステータスアップ
    case lowHPBoost       // HP低下で強化
    case flatDamage       // 特定行動に固定ダメージ追加
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

    /// パッシブ効果の説明文
    var effectDescription: String {
        switch self {
        case .doubleAct: "確率で2回行動する"
        case .statBoost: "基礎ステータスが上がる"
        case .oddSlotBoost: "奇数番スロットの技が強化される"
        case .evenSlotBoost: "偶数番スロットの技が強化される"
        case .firstLoopBoost: "1周目の技が強化される"
        case .secondLoopBoost: "2周目の技が強化される"
        case .emptySlotBoost: "通常攻撃(空きスロット)が強化される"
        case .elementBoost: "自属性の攻撃が強化される"
        case .otomoBoost: "オトモのステータスが上がる"
        case .lowHPBoost: "HPが低いほど強化される"
        case .flatDamage: "攻撃に固定ダメージを追加する"
        case .miniBarrier: "開戦時に小さなバリアを張る"
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
