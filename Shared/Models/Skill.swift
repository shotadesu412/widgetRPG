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
        case .attack: "sword.fill"
        case .specialAttack: "burst.fill"
        case .magic: "sparkles"
        case .heal: "cross.case.fill"
        case .buff: "arrow.up.circle.fill"
        case .debuff: "arrow.down.circle.fill"
        case .barrier: "shield.fill"
        }
    }
}

struct Skill: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: SkillKind
    /// 威力・効果量(攻撃力/魔力に対する百分率)
    var power: Int
    var element: Element?
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

    /// 強パッシブかどうか(強い効果ほど軽い防具=指輪・仮面に付く)
    var isStrong: Bool {
        switch self {
        case .doubleAct, .lowHPBoost: true
        default: false
        }
    }
}

struct Passive: Codable, Hashable {
    var kind: PassiveKind
    /// 効果量(%)
    var value: Int
}
