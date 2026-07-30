import Foundation

// MARK: - 行動(スロット/必殺技の効果定義)

/// 対象の取り方
enum ActionTarget: Hashable {
    case singleEnemy         // 敵単体(生存からランダム)
    case allEnemies          // 敵全体
    case randomEnemies(Int)  // ランダムな敵にヒット数ぶん(毎回抽選)
    case lowestAlly          // 最もHP割合の低い味方
    case allAllies           // 味方全体
    case randomAlly          // ランダムな味方
    case selfUnit            // 自分
}

/// ダメージの参照ステータス
enum DamageStat: Hashable {
    case attack           // 攻撃力
    case magic            // 魔力
    case attackPlusMagic  // 攻撃力+魔力の合計
}

// 状態異常(Ailment)の定義は Shared/Models/Skill.swift に移動

/// 戦闘中の1行動。スキル・必殺技・通常攻撃を統一して表現する。
struct BattleAction: Hashable {
    var name: String
    var kind: Kind

    enum Kind: Hashable {
        /// ダメージ。pct=参照ステータスに対する%。
        /// critChance=会心率(%、2倍)。hits=ヒット回数(リボルバー等はランダム)。
        /// inflict/inflictChance=付与する状態異常とその確率(%)。
        /// drainPct=与ダメージの自己回復%(吸血)。bonusVsAilment=状態異常の敵に1.3倍
        case damage(pct: Int, target: ActionTarget, stat: DamageStat = .attack,
                    critChance: Int = 0, hits: ClosedRange<Int> = 1...1,
                    inflict: Ailment? = nil, inflictChance: Int = 0,
                    drainPct: Int = 0, bonusVsAilment: Bool = false)
        /// 術者の魔力×pct% を回復
        case healByMagic(pct: Int, target: ActionTarget)
        /// 対象の最大HPの pct% を回復(割合回復)
        case healPercent(pct: Int, target: ActionTarget)
        /// 固定量回復(+任意で自身の防御を一定時間上昇)
        case healFlat(amount: Int, defBuffPct: Int = 0)
        /// 対象の攻撃を一定%上昇(術者の次行動まで)
        case buffAttack(pct: Int, target: ActionTarget)
        /// 対象の素早さを一定%低下(術者の次行動まで)
        case debuffSpeed(pct: Int, target: ActionTarget)
        /// 自身の防御を上昇(自分のスロットが指定回数発動するまで)
        case defenseStance(pct: Int, slots: Int)
        /// カオス: ランダムな数の敵に、毒/速度低下/攻撃低下をそれぞれ確率で付与
        case chaos(chance: Int, spdDownPct: Int, atkDownPct: Int, turns: Int)
        /// 瞑想: 自分の魔力を一定%恒久上昇し、最大HPの一定%を回復
        case meditate(magicUpPct: Int, healPctMaxHP: Int)
        /// 供物の選定: ランダムな味方1体の攻撃と防御を倍化し、対象を記憶(サクリファイスへ変化)
        case offeringSelect(mul: Double)
        /// サクリファイス: 記憶した味方を戦闘不能にし、その全ステータスの一定%を自分に加算
        case sacrifice(gainPct: Int)

        // MARK: 特殊キャラ用

        /// 術者の攻撃力×pct% を回復(獣使いの回復・ゾンビの再生)
        case healByAttack(pct: Int, target: ActionTarget)
        /// 大当たり付き攻撃: 通常は basePct、chance% で bigPct に跳ねる(セブンスラッシュ)
        case jackpot(basePct: Int, bigPct: Int, chance: Int)
        /// 身代わり: turns ターンのあいだ単体攻撃を自分に集め、味方の全体攻撃を aoeReductionPct% 軽減
        case taunt(turns: Int, aoeReductionPct: Int)
        /// 鼓舞: 味方全体の攻撃を turns ターン buffPct% 上げ、ランダムな敵1体に attackPct% の攻撃
        case rally(buffPct: Int, turns: Int, attackPct: Int)
        /// 行動停止を付与(タイムキーパー)。chance=付与確率(%)
        case stun(turns: Int, target: ActionTarget, chance: Int)
        /// ランダムな味方のスロットを count 個進める(スキップ)
        case advanceAllySlot(count: Int)
        /// 遅延ダメージ: 対象の次の行動時に pct% のダメージが発生する(ディレイ)
        case delayedDamage(pct: Int, target: ActionTarget)
        /// 状態異常のみを付与する(逆光・ウイルス)
        case inflictAilment(Ailment, chance: Int, target: ActionTarget)
        /// 味方全体に「戦闘不能時にミニゾンビを召喚する」バフを付与(死者の宴)
        case grantDeathSpawn
        /// 場にいるオトモのスロット技をランダムに times 回発動する(群れの咆哮)
        case triggerOtomoSkills(times: Int)

        /// 空きスロット=通常攻撃(攻撃力100%単体)
        case normalAttack
    }

    static let normal = BattleAction(name: "通常攻撃", kind: .normalAttack)

    /// キャラ絵に渡すアニメ状態
    var spriteState: SpriteState {
        switch kind {
        case .normalAttack, .damage: .attackNormal
        default: .attackSkill
        }
    }
}

/// 悪魔の第四スロット(供物の選定 ↔ サクリファイス)
enum AkumaActions {
    static let offering = BattleAction(name: "供物の選定", kind: .offeringSelect(mul: 1.5))
    static let sacrifice = BattleAction(name: "サクリファイス", kind: .sacrifice(gainPct: 30))
}

/// 戦闘中のパッシブ
enum BattlePassive: Hashable {
    case evenLoopAttack(mul: Double)                 // 偶数巡目の攻撃を強化
    case lowHPRegen(thresholdPct: Int, amount: Int)  // HPが閾値以下で毎行動回復
    case drainAlliesMagic(pct: Int)                  // 戦闘開始時、味方の魔力を0にして合計の一定%を自分に加算
    /// スロットマシン: 開戦時とスロット一巡ごとに4種の効果から1つをランダムに発動
    case slotMachineRoulette
    /// タイムキーパー: 自分の行動ごとに、敵全体へ確率で行動停止(自分の次の行動まで)
    case stunAura(chance: Int)
    /// ゾンビ: 戦闘不能のたびに確率で復活。復活のたびに復活時HPが decayPct ポイントずつ下がる
    case undying(chance: Int, hpPct: Int, decayPct: Int)

    /// 簡易詳細のパッシブ効果一覧に表示する説明
    var label: String {
        switch self {
        case .evenLoopAttack(let mul):
            "偶数巡目の攻撃\(String(format: "%.1f", mul))倍"
        case .lowHPRegen(let threshold, let amount):
            "HP\(threshold)%以下で毎行動\(amount)回復"
        case .drainAlliesMagic(let pct):
            "開戦時に味方の魔力の\(pct)%を吸収"
        case .slotMachineRoulette:
            "開戦時と一巡ごとにランダムな効果"
        case .stunAura(let chance):
            "毎行動、敵全体に\(chance)%で行動停止"
        case .undying(let chance, let hpPct, let decayPct):
            "戦闘不能時\(chance)%でHP\(hpPct)%復活(毎回-\(decayPct)%)"
        }
    }
}

/// 遅延ダメージ(ディレイ)。対象が次に行動するときに発生する
struct PendingDamage: Hashable {
    var sourceName: String
    var label: String
    var amount: Int
    var element: Element
}

/// 一時的なステータス補正
struct StatModifier: Hashable {
    enum Stat { case attack, defense, speed }
    enum Expiry: Hashable {
        case ownerNextAction(UUID) // 付与者の次行動まで
        case selfSlots             // 自分のスロット発動回数で管理(slotsLeftを使う)
        case turns(Int)            // 対象が行動する回数で管理
        case permanent             // 戦闘中ずっと
    }
    var stat: Stat
    var mul: Double
    var expiry: Expiry
    var slotsLeft: Int = 0
    var turnsLeft: Int = 0
}

/// 頭上に浮かべる数値(ダメージ・回復・毒)
struct FloatingNumber: Identifiable {
    enum Kind { case damage, heal, poison }
    let id = UUID()
    var value: Int
    var kind: Kind
    var age: Double = 0
    var life: Double = 0.9
}

// MARK: - 戦闘エンジン

/// ボス戦(アクティブタイムバトル)のエンジン。
/// ゲージはメモリ無しで緑→赤のグラデーション表示(行動に近づくほど赤)。
/// 行動は1体ずつ処理し、行動ごとに少し間(actionBeat)を置く。
final class BattleEngine: ObservableObject {

    struct Unit: Identifiable {
        let id = UUID()
        var name: String
        var isAlly: Bool
        var element: Element
        var maxHP: Int
        var hp: Int
        var attack: Int
        var defense: Int
        var speed: Int
        var magic: Int
        /// 0〜1。1で行動
        var gauge: Double = Double.random(in: 0...0.2)
        var slots: [BattleAction]
        var slotIndex = 0
        /// スロット周回数(必殺技の発動条件)
        var loops = 0
        var ultimate: BattleAction?
        var ultimateLoops = 0
        var reviveChance = 0
        /// ダメージを肩代わりするバリア量(プチバリア等)
        var barrier = 0
        var spriteKey: String
        var passives: [BattlePassive] = []
        /// キャラ/防具/オトモ由来のパッシブ(奇偶スロット強化・属性強化などを戦闘に反映)
        var gamePassives: [Passive] = []
        /// 現在の行動に適用するスロット系パッシブのダメージ倍率(行動ごとに再計算)
        var slotDamageMul: Double = 1.0

        // 簡易詳細(戦闘中に見る詳細)用の表示情報
        /// メインキャラかどうか(タブ分類用。オトモ・敵は false)
        var isMainCharacter = false
        /// 武器の表示(アイコン+名前)。オトモは装備なし
        var weaponInfo: (icon: String, name: String)?
        /// 防具の表示(アイコン+名前)
        var armorInfo: (icon: String, name: String)?
        /// 防具などのパッシブ効果一覧(表示用テキスト)
        var extraPassiveLabels: [String] = []

        // 状態
        var ailments: Set<Ailment> = []
        var modifiers: [StatModifier] = []
        /// サクリファイス用: 供物の選定で記憶した対象
        var offeringTargetID: UUID?
        var transientState: SpriteState?
        var stateTimer: Double = 0

        // MARK: 特殊キャラ用の状態

        /// オトモかどうか(獣使いのパッシブ・必殺技の対象判定に使う)
        var isOtomo = false
        /// 召喚ユニット(ミニゾンビ等)。全滅判定からは除外しない
        var isSummon = false
        /// 行動停止の残りターン。1以上なら行動を飛ばして1減らす
        var stunTurns = 0
        /// 身代わりの残りターン。1以上なら敵の単体攻撃をこのユニットに集める
        var tauntTurns = 0
        /// 身代わり中に味方が受ける全体攻撃の軽減率(%)
        var tauntAoEReductionPct = 0
        /// 追撃状態: 次の抽選まで、攻撃時に攻撃力の followUpPct% の追撃が発生する
        var followUpPct = 0
        /// 復活時のHP割合(%)。0なら復活しない。復活のたびに undying の decayPct ぶん下がる
        var reviveHPPct = 0
        var reviveDecayPct = 0
        /// 戦闘不能時にミニゾンビを召喚する(死者の宴のバフ)
        var spawnMiniOnDeath = false
        /// 次の行動時に受ける遅延ダメージ(ディレイ)
        var pendingDamage: [PendingDamage] = []

        /// UI互換用(毒表示)
        var poisoned: Bool { ailments.contains(.poison) }
        var hasAilment: Bool { !ailments.isEmpty }
        var ailmentList: [Ailment] { Ailment.allCases.filter { ailments.contains($0) } }

        // 演出用
        /// 行動中に足元へ出すスキル名
        var actionLabel: String?
        var actionLabelTimer: Double = 0
        /// 被弾・回復時に頭上へ出す数値
        var floating: FloatingNumber?

        var isAlive: Bool { hp > 0 }

        var visualState: SpriteState {
            if !isAlive { return .down }
            return transientState ?? .idle
        }

        var ultimateReady: Bool { ultimate != nil && loops >= ultimateLoops }

        /// 現在の巡目(1始まり)
        var currentLoop: Int { loops + 1 }

        func modMultiplier(_ stat: StatModifier.Stat) -> Double {
            modifiers.filter { $0.stat == stat }.reduce(1.0) { $0 * $1.mul }
        }

        var effectiveSpeed: Int {
            var value = Double(speed) * modMultiplier(.speed)
            if ailments.contains(.speedDown) { value *= 0.7 } // 速度低下: 速度30%低下
            return max(1, Int(value))
        }
        var effectiveDefense: Int { max(0, Int(Double(defense) * modMultiplier(.defense))) }
        /// 簡易詳細表示用の実効攻撃(バフ・攻撃低下込み。巡目パッシブは除く)
        var effectiveAttackDisplay: Int {
            var value = Double(attack) * modMultiplier(.attack)
            if ailments.contains(.attackDown) { value *= 0.7 }
            return max(0, Int(value))
        }
    }

    enum BattleResult { case victory, defeat }

    @Published var allies: [Unit] = []
    @Published var enemies: [Unit] = []
    @Published var log: [String] = []
    @Published var result: BattleResult?
    /// 戦闘中に獲得したコイン(スロットマシンのルーレット)。
    /// 加算のたびに onGoldEarned が呼ばれ、画面側が即座にセーブへ反映する
    @Published private(set) var goldEarned = 0
    /// コイン獲得時のコールバック(セーブへの加算は画面側の責務)
    var onGoldEarned: ((Int) -> Void)?

    /// 行動後の待ち時間(この間はゲージが止まる)
    private var actionPause: Double = 0
    /// 行動ごとに置く間の長さ(秒)
    private let actionBeat: Double = 0.6

    /// 戦闘開始時のパッシブを適用する(ユニット組み立て後に一度だけ呼ぶ)
    func applyBattleStart() {
        for i in allies.indices {
            for passive in allies[i].passives {
                switch passive {
                case let .drainAlliesMagic(pct):
                    var total = 0
                    for j in allies.indices where j != i {
                        total += allies[j].magic
                        allies[j].magic = 0
                    }
                    let gain = total * pct / 100
                    allies[i].magic += gain
                    appendLog("\(allies[i].name)の儀式! 味方の魔力を吸収した(魔力+\(gain))")
                case let .undying(_, hpPct, decayPct):
                    // ゾンビ: 復活時HPの初期値と減衰量を設定する
                    allies[i].reviveHPPct = hpPct
                    allies[i].reviveDecayPct = decayPct
                case .slotMachineRoulette:
                    break // 抽選は下でまとめて行う(ログ順を開戦メッセージの後にするため)
                default:
                    break
                }
            }
        }
        // スロットマシン: 開戦時にも1回抽選する
        for unit in allies + enemies where unit.passives.contains(.slotMachineRoulette) {
            spinRoulette(for: unit.id)
        }
    }

    // MARK: - スロットマシンのルーレット

    /// スロットマシンのパッシブ。開戦時とスロット一巡ごとに4種から1つ発動する
    private func spinRoulette(for unitID: UUID) {
        guard var unit = findUnit(id: unitID), unit.isAlive else { return }
        unit.followUpPct = 0 // 追撃は「次の抽選まで」なので、抽選のたびに一度切る
        switch Int.random(in: 0..<4) {
        case 0:
            unit.modifiers.append(StatModifier(stat: .attack, mul: 1.30, expiry: .permanent))
            appendLog("\(unit.name)のルーレット! 攻撃力が30%上がった")
            updateUnit(unit)
        case 1:
            appendLog("\(unit.name)のルーレット! 味方全員の防御が25%上がった")
            updateUnit(unit)
            for id in resolveTargets(.allAllies, from: unit) {
                addModifier(StatModifier(stat: .defense, mul: 1.25, expiry: .permanent), to: id)
            }
        case 2:
            // 次の抽選(=次の一巡)まで、攻撃に攻撃力50%の追撃が乗る
            unit.followUpPct = 50
            appendLog("\(unit.name)のルーレット! 攻撃に追撃が付いた")
            updateUnit(unit)
        default:
            // 獲得量は攻撃力に比例(レベル帯に追従させるため)
            let gain = max(10, unit.attack * 2)
            goldEarned += gain
            onGoldEarned?(gain)
            appendLog("\(unit.name)のルーレット! コインを\(gain)獲得した")
            updateUnit(unit)
        }
    }

    // MARK: - 進行

    func tick(deltaTime: Double) {
        guard result == nil else { return }

        // 演出タイマー(スキル名・頭上数値・アニメ)は常に進める
        decayPresentation(&allies, deltaTime: deltaTime)
        decayPresentation(&enemies, deltaTime: deltaTime)

        // 行動直後は少し止まる
        if actionPause > 0 {
            actionPause -= deltaTime
            return
        }

        advanceGauges(&allies, deltaTime: deltaTime)
        advanceGauges(&enemies, deltaTime: deltaTime)

        // ゲージが満ちたユニットを1体だけ行動させ、間を置く
        if let actorID = nextReadyActor() {
            act(unitID: actorID)
            actionPause = actionBeat
        }
        checkEnd()
    }

    private func decayPresentation(_ units: inout [Unit], deltaTime: Double) {
        for i in units.indices {
            if units[i].transientState != nil {
                units[i].stateTimer -= deltaTime
                if units[i].stateTimer <= 0 { units[i].transientState = nil }
            }
            if units[i].actionLabel != nil {
                units[i].actionLabelTimer -= deltaTime
                if units[i].actionLabelTimer <= 0 { units[i].actionLabel = nil }
            }
            if units[i].floating != nil {
                units[i].floating!.age += deltaTime
                if units[i].floating!.age >= units[i].floating!.life { units[i].floating = nil }
            }
        }
    }

    private func advanceGauges(_ units: inout [Unit], deltaTime: Double) {
        // 行動頻度 = 50 + 素早さ/2(逓減式)。
        // 素早さ100(剣士アンカー)で従来と同じ頻度になり、
        // 速いキャラの伸びを圧縮・遅いキャラを底上げする(速度=防御とのトレードオフ設計)
        for i in units.indices where units[i].isAlive {
            let rate = 50.0 + Double(units[i].effectiveSpeed) / 2.0
            units[i].gauge = min(1.0, units[i].gauge + deltaTime * rate / 60.0)
        }
    }

    /// ゲージが満ちた中で最も進んでいる1体を返す
    private func nextReadyActor() -> UUID? {
        (allies + enemies)
            .filter { $0.isAlive && $0.gauge >= 1.0 }
            .max { $0.effectiveSpeed < $1.effectiveSpeed }?
            .id
    }

    // MARK: - 1体の行動

    private func act(unitID: UUID) {
        guard result == nil, var unit = findUnit(id: unitID), unit.isAlive else { return }
        unit.gauge = 0

        // 0. 遅延ダメージ(ディレイ): この行動の頭で受ける
        if !unit.pendingDamage.isEmpty {
            let pending = unit.pendingDamage
            unit.pendingDamage = []
            for hit in pending {
                let defense = unit.isAlly ? unit.effectiveDefense : 0
                let raw = Double(hit.amount) * 250.0 / (250.0 + Double(defense))
                let damage = max(1, Int(raw * hit.element.multiplier(against: unit.element)))
                unit.hp = max(0, unit.hp - damage)
                unit.floating = FloatingNumber(value: damage, kind: .damage)
                appendLog("\(hit.sourceName)の\(hit.label)が炸裂! \(unit.name)に\(damage)ダメージ")
                if !unit.isAlive { break }
            }
            if !unit.isAlive {
                handleDeath(&unit)
                updateUnit(unit)
                checkEnd()
                return
            }
        }

        // 0-2. 行動停止(タイムキーパー): ターンを消費して何もしない
        if unit.stunTurns > 0 {
            unit.stunTurns -= 1
            decrementTauntTurns(on: &unit)
            appendLog("\(unit.name)は動けない!")
            updateUnit(unit)
            return
        }

        // 1. 行動開始時の継続ダメージ(毒: 現在HPの5% / 火傷: 自分の攻撃力の25%)
        if unit.ailments.contains(.poison) {
            let dmg = max(1, Int(Double(unit.hp) * 0.05))
            unit.hp = max(0, unit.hp - dmg)
            unit.floating = FloatingNumber(value: dmg, kind: .poison)
            appendLog("\(unit.name)は毒で\(dmg)ダメージ")
        }
        if unit.isAlive, unit.ailments.contains(.burn) {
            let dmg = max(1, unit.attack * 25 / 100)
            unit.hp = max(0, unit.hp - dmg)
            unit.floating = FloatingNumber(value: dmg, kind: .poison)
            appendLog("\(unit.name)は火傷で\(dmg)ダメージ")
        }
        if !unit.isAlive {
            handleDeath(&unit)
            updateUnit(unit)
            checkEnd()
            return
        }

        // 2. 低HP再生パッシブ
        for passive in unit.passives {
            if case let .lowHPRegen(thresholdPct, amount) = passive,
               unit.hp <= unit.maxHP * thresholdPct / 100 {
                unit.hp = min(unit.maxHP, unit.hp + amount)
                unit.floating = FloatingNumber(value: amount, kind: .heal)
                appendLog("\(unit.name)の再生能力! HPが\(amount)回復")
            }
        }

        // 3. 「付与者の次行動まで」の補正を解除(自分が付与した分)、ターン制の補正を1減らす
        clearOwnerModifiers(ownerID: unit.id)
        decrementTurnModifiers(on: &unit)
        decrementTauntTurns(on: &unit)

        // 3-2. タイムキーパーのパッシブ: 敵全体に確率で行動停止(自分の次の行動まで)
        for passive in unit.passives {
            if case let .stunAura(chance) = passive {
                for foe in (unit.isAlly ? enemies : allies).filter(\.isAlive)
                where Int.random(in: 0..<100) < chance {
                    guard var t = findUnit(id: foe.id) else { continue }
                    t.stunTurns = max(t.stunTurns, 1)
                    updateUnit(t)
                    appendLog("\(unit.name)の時間干渉! \(t.name)の動きが止まった")
                }
            }
        }

        // 4. 行動本体。足元にスキル名を出す
        if unit.ultimateReady, let ultimate = unit.ultimate {
            unit.slotDamageMul = 1.0 // スロット系パッシブは必殺技に乗らない
            setActionLabel(ultimate.name, on: &unit)
            setTransientState(.ultimate, on: &unit)
            appendLog("必殺技! \(unit.name)の「\(ultimate.name)」!!")
            perform(ultimate, by: &unit)
            unit.loops = 0
        } else {
            // 二回行動パッシブ: 1回目の行動後に確率でもう一度(1回まで)
            var actionsLeft = 1
            var extraGranted = false
            while actionsLeft > 0, unit.isAlive, result == nil {
                actionsLeft -= 1
                let original = unit.slots.isEmpty ? BattleAction.normal : unit.slots[unit.slotIndex]
                // 空きスロットの通常攻撃か(洗脳による通常攻撃化には emptySlotBoost は乗らない)
                let isEmptySlotNormal: Bool = {
                    if case .normalAttack = original.kind { return true }
                    return false
                }()
                var action = original
                // 洗脳: スロットが50%で通常攻撃に変わる
                if unit.ailments.contains(.brainwash), Int.random(in: 0..<100) < 50, action.kind != .normalAttack {
                    appendLog("\(unit.name)は洗脳されている……!")
                    action = .normal
                }
                // スロット系パッシブ(奇偶/1周目/2周目/空きスロット強化)の倍率
                unit.slotDamageMul = Self.slotPassiveMul(
                    unit, slotIndex: unit.slotIndex, emptySlotNormal: isEmptySlotNormal)
                setActionLabel(action.name, on: &unit)
                setTransientState(action.spriteState, on: &unit)
                perform(action, by: &unit)
                // 供物の選定 ↔ サクリファイス はスロットが交互に変化する
                toggleAkumaSlot(action, on: &unit)
                // スロット発動回数で切れる補正(防御の構えなど)を減らす
                decrementSlotModifiers(on: &unit)
                advanceSlot(on: &unit)

                if !extraGranted,
                   let doubleAct = unit.gamePassives.first(where: { $0.kind == .doubleAct }),
                   Int.random(in: 0..<100) < doubleAct.value {
                    extraGranted = true
                    actionsLeft += 1
                    appendLog("\(unit.name)は続けて動いた!(二回行動)")
                }
            }
        }

        // 5. ターンの終わりに状態異常の解除判定
        for ailment in unit.ailmentList where Int.random(in: 0..<100) < ailment.cureChance {
            unit.ailments.remove(ailment)
            appendLog("\(unit.name)の\(ailment.label)が解けた")
        }

        updateUnit(unit)
        checkEnd()
    }

    /// スロットの進行。逆光中は逆回りする(周回は進まないが必殺ターンは減らない)。
    /// 一巡したユニットがスロットマシンのパッシブを持つ場合はルーレットを回す
    private func advanceSlot(on unit: inout Unit) {
        guard !unit.slots.isEmpty else { return }
        if unit.ailments.contains(.reverse) {
            unit.slotIndex -= 1
            if unit.slotIndex < 0 {
                unit.slotIndex = unit.slots.count - 1
            }
        } else {
            unit.slotIndex += 1
            if unit.slotIndex >= unit.slots.count {
                unit.slotIndex = 0
                unit.loops += 1
                if unit.passives.contains(.slotMachineRoulette) {
                    // ルーレットは自分の状態を書き換えるので、
                    // 先に現在の unit を反映してから回し、結果を読み戻す
                    updateUnit(unit)
                    spinRoulette(for: unit.id)
                    if let refreshed = findUnit(id: unit.id) { unit = refreshed }
                }
            }
        }
    }

    /// 身代わりの残りターンを減らす(自分の行動を1ターンと数える)
    private func decrementTauntTurns(on unit: inout Unit) {
        guard unit.tauntTurns > 0 else { return }
        unit.tauntTurns -= 1
        if unit.tauntTurns == 0 {
            unit.tauntAoEReductionPct = 0
            appendLog("\(unit.name)の身代わりが解けた")
        }
    }

    private func toggleAkumaSlot(_ action: BattleAction, on unit: inout Unit) {
        guard unit.slotIndex < unit.slots.count else { return }
        switch action.kind {
        case .offeringSelect: unit.slots[unit.slotIndex] = AkumaActions.sacrifice
        case .sacrifice:      unit.slots[unit.slotIndex] = AkumaActions.offering
        default: break
        }
    }

    private func decrementTurnModifiers(on unit: inout Unit) {
        for i in unit.modifiers.indices {
            if case .turns = unit.modifiers[i].expiry { unit.modifiers[i].turnsLeft -= 1 }
        }
        unit.modifiers.removeAll {
            if case .turns = $0.expiry { return $0.turnsLeft <= 0 }
            return false
        }
    }

    private func setActionLabel(_ label: String, on unit: inout Unit) {
        unit.actionLabel = label
        unit.actionLabelTimer = actionBeat + 0.3
    }

    /// スロット系パッシブのダメージ倍率(奇数/偶数スロット・1周目/2周目・空きスロット通常攻撃)
    static func slotPassiveMul(_ unit: Unit, slotIndex: Int, emptySlotNormal: Bool) -> Double {
        var mul = 1.0
        let slotNumber = slotIndex + 1 // 1始まり
        for p in unit.gamePassives {
            let bonus = 1.0 + Double(p.value) / 100
            switch p.kind {
            case .oddSlotBoost where slotNumber % 2 == 1: mul *= bonus
            case .evenSlotBoost where slotNumber % 2 == 0: mul *= bonus
            case .firstLoopBoost where unit.currentLoop == 1: mul *= bonus
            case .secondLoopBoost where unit.currentLoop == 2: mul *= bonus
            case .emptySlotBoost where emptySlotNormal: mul *= bonus
            default: break
            }
        }
        return mul
    }

    /// 開戦時パッシブの適用(全ステータス上昇・プチバリア)。ユニット組み立て後に呼ぶ
    static func applyStaticPassives(_ unit: inout Unit) {
        for p in unit.gamePassives {
            switch p.kind {
            case .statBoost:
                let mul = 1.0 + Double(p.value) / 100
                unit.maxHP = Int(Double(unit.maxHP) * mul)
                unit.hp = Int(Double(unit.hp) * mul)
                unit.attack = Int(Double(unit.attack) * mul)
                unit.defense = Int(Double(unit.defense) * mul)
                unit.speed = Int(Double(unit.speed) * mul)
                unit.magic = Int(Double(unit.magic) * mul)
            case .miniBarrier:
                unit.barrier += unit.maxHP * p.value / 100
            default:
                break
            }
        }
    }

    // MARK: - 行動の解決

    private func perform(_ action: BattleAction, by unit: inout Unit) {
        switch action.kind {
        case .normalAttack:
            dealToTargets(from: &unit, pct: 100, target: .singleEnemy, stat: .attack,
                          critChance: 0, hits: 1...1, inflict: nil, inflictChance: 0,
                          drainPct: 0, bonusVsAilment: false, label: "攻撃")
        case let .damage(pct, target, stat, critChance, hits, inflict, inflictChance, drainPct, bonusVsAilment):
            dealToTargets(from: &unit, pct: pct, target: target, stat: stat,
                          critChance: critChance, hits: hits,
                          inflict: inflict, inflictChance: inflictChance,
                          drainPct: drainPct, bonusVsAilment: bonusVsAilment, label: action.name)
        case let .healByMagic(pct, target):
            let amount = max(1, unit.magic * pct / 100)
            for id in resolveTargets(target, from: unit) {
                heal(id: id, amount: amount)
            }
            appendLog("\(unit.name)の\(action.name)! HPを\(amount)回復")
        case let .healPercent(pct, target):
            // 割合回復: 対象それぞれの最大HPの pct% を回復
            for id in resolveTargets(target, from: unit) {
                if let t = findUnit(id: id) {
                    heal(id: id, amount: max(1, t.maxHP * pct / 100))
                }
            }
            appendLog("\(unit.name)の\(action.name)! 最大HPの\(pct)%を回復")
        case let .healFlat(amount, defBuffPct):
            let before = unit.hp
            unit.hp = min(unit.maxHP, unit.hp + amount)
            let healed = unit.hp - before
            if healed > 0 { unit.floating = FloatingNumber(value: healed, kind: .heal) }
            appendLog("\(unit.name)の\(action.name)! HPが\(amount)回復")
            if defBuffPct > 0 {
                unit.modifiers.append(StatModifier(stat: .defense, mul: 1.0 + Double(defBuffPct) / 100,
                                                   expiry: .ownerNextAction(unit.id)))
            }
        case let .buffAttack(pct, target):
            for id in resolveTargets(target, from: unit) {
                addModifier(StatModifier(stat: .attack, mul: 1.0 + Double(pct) / 100,
                                         expiry: .ownerNextAction(unit.id)), to: id)
            }
            appendLog("\(unit.name)の\(action.name)! 味方の攻撃が上がった")
        case let .debuffSpeed(pct, target):
            for id in resolveTargets(target, from: unit) {
                addModifier(StatModifier(stat: .speed, mul: 1.0 - Double(pct) / 100,
                                         expiry: .ownerNextAction(unit.id)), to: id)
            }
            appendLog("\(unit.name)の\(action.name)! 相手の素早さが下がった")
        case let .defenseStance(pct, slots):
            unit.modifiers.append(StatModifier(stat: .defense, mul: 1.0 + Double(pct) / 100,
                                               expiry: .selfSlots, slotsLeft: slots))
            appendLog("\(unit.name)の\(action.name)! 防御を固めた")
        case let .chaos(chance, spdDown, atkDown, turns):
            performChaos(from: unit, chance: chance, spdDown: spdDown, atkDown: atkDown, turns: turns, label: action.name)
        case let .meditate(magicUpPct, healPctMaxHP):
            unit.magic = Int(Double(unit.magic) * (1.0 + Double(magicUpPct) / 100))
            let heal = unit.maxHP * healPctMaxHP / 100
            let before = unit.hp
            unit.hp = min(unit.maxHP, unit.hp + heal)
            if unit.hp - before > 0 { unit.floating = FloatingNumber(value: unit.hp - before, kind: .heal) }
            appendLog("\(unit.name)の\(action.name)! 魔力上昇・HP回復")
        case let .offeringSelect(mul):
            performOffering(from: &unit, mul: mul, label: action.name)
        case let .sacrifice(gainPct):
            performSacrifice(from: &unit, gainPct: gainPct, label: action.name)

        // MARK: 特殊キャラ

        case let .healByAttack(pct, target):
            let amount = max(1, effectiveAttack(of: unit) * pct / 100)
            let ids = resolveTargets(target, from: unit)
            for id in ids {
                if id == unit.id {
                    let before = unit.hp
                    unit.hp = min(unit.maxHP, unit.hp + amount)
                    if unit.hp - before > 0 {
                        unit.floating = FloatingNumber(value: unit.hp - before, kind: .heal)
                    }
                } else {
                    heal(id: id, amount: amount)
                }
            }
            appendLog("\(unit.name)の\(action.name)! HPを\(amount)回復")

        case let .jackpot(basePct, bigPct, chance):
            let hit = Int.random(in: 0..<100) < chance
            if hit { appendLog("\(unit.name)の\(action.name)……大当たり!!") }
            dealToTargets(from: &unit, pct: hit ? bigPct : basePct, target: .singleEnemy,
                          stat: .attack, critChance: 0, hits: 1...1,
                          inflict: nil, inflictChance: 0, drainPct: 0,
                          bonusVsAilment: false, label: action.name)

        case let .taunt(turns, aoeReductionPct):
            unit.tauntTurns = turns
            unit.tauntAoEReductionPct = aoeReductionPct
            appendLog("\(unit.name)の\(action.name)! 攻撃を引き受ける")

        case let .rally(buffPct, turns, attackPct):
            for id in resolveTargets(.allAllies, from: unit) {
                addModifier(StatModifier(stat: .attack, mul: 1.0 + Double(buffPct) / 100,
                                         expiry: .turns(turns), turnsLeft: turns), to: id)
            }
            appendLog("\(unit.name)の\(action.name)! 味方全員の攻撃が\(buffPct)%上がった")
            dealToTargets(from: &unit, pct: attackPct, target: .singleEnemy,
                          stat: .attack, critChance: 0, hits: 1...1,
                          inflict: nil, inflictChance: 0, drainPct: 0,
                          bonusVsAilment: false, label: action.name)

        case let .stun(turns, target, chance):
            var stunned: [String] = []
            for id in resolveTargets(target, from: unit) where Int.random(in: 0..<100) < chance {
                guard var t = findUnit(id: id) else { continue }
                t.stunTurns = max(t.stunTurns, turns)
                updateUnit(t)
                stunned.append(t.name)
            }
            appendLog(stunned.isEmpty
                      ? "\(unit.name)の\(action.name)! だが効かなかった"
                      : "\(unit.name)の\(action.name)! \(stunned.joined(separator: "・"))の時が止まった")

        case let .advanceAllySlot(count):
            // 自分以外の味方を優先(自分しかいなければ自分を進める)
            let friends = (unit.isAlly ? allies : enemies)
                .filter { $0.isAlive && !$0.slots.isEmpty }
            let others = friends.filter { $0.id != unit.id }
            guard var target = (others.isEmpty ? friends : others).randomElement() else {
                appendLog("\(unit.name)の\(action.name)! だが対象がいない")
                break
            }
            let isSelf = target.id == unit.id
            for _ in 0..<count { advanceSlot(on: &target) }
            if isSelf {
                // 自分を進めた場合は、呼び出し元が持つ unit 側に反映する
                unit.slotIndex = target.slotIndex
                unit.loops = target.loops
            } else {
                updateUnit(target)
            }
            appendLog("\(unit.name)の\(action.name)! \(target.name)のスロットが進んだ")

        case let .delayedDamage(pct, target):
            let amount = max(1, effectiveAttack(of: unit) * pct / 100)
            for id in resolveTargets(target, from: unit) {
                guard var t = findUnit(id: id) else { continue }
                t.pendingDamage.append(PendingDamage(sourceName: unit.name, label: action.name,
                                                     amount: amount, element: unit.element))
                updateUnit(t)
                appendLog("\(unit.name)の\(action.name)! \(t.name)に時限の一撃を仕掛けた")
            }

        case let .inflictAilment(ailment, chance, target):
            var affected: [String] = []
            for id in resolveTargets(target, from: unit) {
                guard var t = findUnit(id: id), t.isAlive, !t.ailments.contains(ailment),
                      Int.random(in: 0..<100) < chance else { continue }
                if let guardPassive = t.gamePassives.first(where: { $0.kind == .ailmentGuard }),
                   Int.random(in: 0..<100) < guardPassive.value {
                    appendLog("\(t.name)は\(ailment.label)を耐性で防いだ")
                    continue
                }
                t.ailments.insert(ailment)
                updateUnit(t)
                affected.append(t.name)
            }
            appendLog(affected.isEmpty
                      ? "\(unit.name)の\(action.name)! だが効かなかった"
                      : "\(unit.name)の\(action.name)! \(affected.joined(separator: "・"))は\(ailment.label)状態になった!")

        case .grantDeathSpawn:
            for id in resolveTargets(.allAllies, from: unit) {
                guard var t = findUnit(id: id) else { continue }
                t.spawnMiniOnDeath = true
                updateUnit(t)
            }
            appendLog("\(unit.name)の\(action.name)! 味方が倒れると死者が起き上がる")

        case let .triggerOtomoSkills(times):
            performOtomoSkills(from: &unit, times: times, label: action.name)
        }
    }

    // MARK: - 獣使い / ゾンビの固有処理

    /// 群れの咆哮: 場にいるオトモのスロット技をランダムに times 回発動する。
    /// 発動役はオトモ本人(ステータスもオトモのものを使う)
    private func performOtomoSkills(from unit: inout Unit, times: Int, label: String) {
        let otomos = (unit.isAlly ? allies : enemies).filter { $0.isAlive && $0.isOtomo }
        guard !otomos.isEmpty else {
            appendLog("\(unit.name)の\(label)! だがオトモがいない")
            return
        }
        appendLog("\(unit.name)の\(label)!")
        for _ in 0..<times {
            guard let picked = otomos.randomElement(),
                  var actor = findUnit(id: picked.id), actor.isAlive,
                  !actor.slots.isEmpty else { continue }
            let skill = actor.slots.randomElement() ?? .normal
            actor.slotDamageMul = 1.0
            setActionLabel(skill.name, on: &actor)
            setTransientState(skill.spriteState, on: &actor)
            perform(skill, by: &actor)
            updateUnit(actor)
            if result != nil { return }
        }
    }

    /// ミニゾンビを召喚する(元になったユニットのステータスの60%)
    private func summonMiniZombie(from origin: Unit) {
        let pct = 60
        var mini = Unit(
            name: "ミニゾンビ", isAlly: origin.isAlly, element: .dark,
            maxHP: max(1, origin.maxHP * pct / 100), hp: max(1, origin.maxHP * pct / 100),
            attack: max(1, origin.attack * pct / 100),
            defense: max(0, origin.defense * pct / 100),
            speed: max(1, origin.speed * pct / 100),
            magic: max(0, origin.magic * pct / 100),
            slots: Array(repeating: BattleAction(
                name: "ゾンビアタック",
                kind: .damage(pct: 120, target: .singleEnemy, inflict: .poison, inflictChance: 40)),
                count: 3),
            spriteKey: "zombie")
        mini.isSummon = true
        if origin.isAlly { allies.append(mini) } else { enemies.append(mini) }
        appendLog("\(origin.name)の亡骸から\(mini.name)が起き上がった!")
    }

    private func dealToTargets(from unit: inout Unit, pct: Int, target: ActionTarget,
                               stat: DamageStat, critChance: Int, hits: ClosedRange<Int>,
                               inflict: Ailment?, inflictChance: Int,
                               drainPct: Int, bonusVsAilment: Bool, label: String) {
        var value: Int
        switch stat {
        case .attack: value = effectiveAttack(of: unit)
        case .magic: value = unit.magic
        case .attackPlusMagic: value = effectiveAttack(of: unit) + unit.magic
        }
        // パッシブ補正: スロット系(行動時に計算済み)+属性強化(自属性攻撃)
        var passiveMul = unit.slotDamageMul
        var flatBonus = 0
        var totalDrainPct = drainPct
        for p in unit.gamePassives {
            switch p.kind {
            case .elementBoost:
                passiveMul *= 1.0 + Double(p.value) / 100
            case .lowHPBoost:
                // 背水の陣: 失ったHPの割合に応じて増加(HP0%で効果値の満額)
                let missing = 1.0 - Double(unit.hp) / Double(max(1, unit.maxHP))
                passiveMul *= 1.0 + Double(p.value) / 100 * missing
            case .flatDamage:
                flatBonus += p.value * 3
            case .drain:
                totalDrainPct += p.value
            default: break
            }
        }
        value = max(1, Int(Double(value) * passiveMul))
        // ヒット回数(双剣・リボルバー等)。ランダム対象は毎ヒット抽選し直す
        let hitCount = Int.random(in: hits)
        let isAreaAttack = target == .allEnemies
        var totalDealt = 0
        for _ in 0..<hitCount {
            let targets = resolveTargets(target, from: unit)
            guard !targets.isEmpty else { break }
            for id in targets {
                totalDealt += dealDamage(
                    fromName: unit.name, attackStat: value, pct: pct,
                    element: unit.element, to: id, critChance: critChance,
                    inflict: inflict, inflictChance: inflictChance,
                    flatBonus: flatBonus, bonusVsAilment: bonusVsAilment,
                    isAreaAttack: isAreaAttack, label: label)
            }
        }
        // 追撃(スロットマシンのルーレット): 攻撃のあとに攻撃力の一定%を単体へ追加
        if unit.followUpPct > 0, totalDealt > 0, unit.isAlive {
            let followUpValue = max(1, Int(Double(effectiveAttack(of: unit)) * passiveMul))
            for id in resolveTargets(.singleEnemy, from: unit) {
                totalDealt += dealDamage(
                    fromName: unit.name, attackStat: followUpValue, pct: unit.followUpPct,
                    element: unit.element, to: id, critChance: 0,
                    inflict: nil, inflictChance: 0, label: "追撃")
            }
        }
        // 吸血: 与えた合計ダメージの一部を自己回復
        if totalDrainPct > 0, totalDealt > 0, unit.isAlive {
            let healed = min(unit.maxHP - unit.hp, max(1, totalDealt * totalDrainPct / 100))
            if healed > 0 {
                unit.hp += healed
                unit.floating = FloatingNumber(value: healed, kind: .heal)
                appendLog("\(unit.name)は\(healed)吸収した")
            }
        }
        // 反撃: 被弾した敵が確率で反撃してくる(反撃は反撃を誘発しない)
        applyCounters(against: &unit)
    }

    /// 直前の攻撃対象からの反撃処理。反撃パッシブ持ちの生存者が確率で通常攻撃を返す
    private var lastHitTargets: [UUID] = []
    private func applyCounters(against unit: inout Unit) {
        let targets = lastHitTargets
        lastHitTargets = []
        for id in targets {
            guard unit.isAlive,
                  let foe = findUnit(id: id), foe.isAlive,
                  let counter = foe.gamePassives.first(where: { $0.kind == .counter }),
                  Int.random(in: 0..<100) < counter.value else { continue }
            let defense = unit.isAlly ? unit.effectiveDefense : 0
            let raw = Double(foe.attack) * 250.0 / (250.0 + Double(defense))
            let damage = max(1, Int(raw * foe.element.multiplier(against: unit.element)))
            unit.hp = max(0, unit.hp - damage)
            unit.floating = FloatingNumber(value: damage, kind: .damage)
            appendLog("\(foe.name)の反撃! \(unit.name)に\(damage)ダメージ")
            if !unit.isAlive { handleDeath(&unit) }
        }
    }

    // MARK: - 悪魔の固有行動

    private func performChaos(from unit: Unit, chance: Int, spdDown: Int, atkDown: Int, turns: Int, label: String) {
        // ランダムな数の敵に、毒・速度低下・攻撃低下をそれぞれ確率で付与(状態異常として扱う)
        let foes = (unit.isAlly ? enemies : allies).filter(\.isAlive)
        guard !foes.isEmpty else { return }
        let n = Int.random(in: 1...foes.count)
        appendLog("\(unit.name)の\(label)! \(n)体を狙う")
        for foe in foes.shuffled().prefix(n) {
            guard var t = findUnit(id: foe.id) else { continue }
            var inflicted: [Ailment] = []
            for ailment in [Ailment.poison, .speedDown, .attackDown]
            where Int.random(in: 0..<100) < chance && !t.ailments.contains(ailment) {
                t.ailments.insert(ailment)
                inflicted.append(ailment)
            }
            if !inflicted.isEmpty {
                appendLog("\(t.name)は\(inflicted.map(\.label).joined(separator: "・"))状態になった!")
                updateUnit(t)
            }
        }
    }

    private func performOffering(from unit: inout Unit, mul: Double, label: String) {
        let allies = (unit.isAlly ? self.allies : self.enemies).filter { $0.isAlive && $0.id != unit.id }
        guard let target = allies.randomElement() else {
            appendLog("\(unit.name)の\(label)! だが供物がいない")
            return
        }
        addModifier(StatModifier(stat: .attack, mul: mul, expiry: .permanent), to: target.id)
        addModifier(StatModifier(stat: .defense, mul: mul, expiry: .permanent), to: target.id)
        unit.offeringTargetID = target.id
        appendLog("\(unit.name)の\(label)! \(target.name)の攻撃と防御が\(String(format: "%.1f", mul))倍に")
    }

    private func performSacrifice(from unit: inout Unit, gainPct: Int, label: String) {
        guard let tid = unit.offeringTargetID, var target = findUnit(id: tid), target.isAlive else {
            appendLog("\(unit.name)の\(label)! だが供物がいない……失敗")
            unit.offeringTargetID = nil
            return
        }
        // 対象の全ステータスの一定%を自分に加算
        unit.maxHP += target.maxHP * gainPct / 100
        unit.hp = min(unit.maxHP, unit.hp + target.maxHP * gainPct / 100)
        unit.attack += target.attack * gainPct / 100
        unit.defense += target.defense * gainPct / 100
        unit.speed += target.speed * gainPct / 100
        unit.magic += target.magic * gainPct / 100
        // 対象を戦闘不能に
        target.hp = 0
        target.ailments = []
        updateUnit(target)
        appendLog("\(unit.name)の\(label)! \(target.name)を捧げ、力を得た")
        unit.offeringTargetID = nil
        checkEnd()
    }

    /// 偶数巡目パッシブ・攻撃低下などを反映した実効攻撃力
    private func effectiveAttack(of unit: Unit) -> Int {
        var value = Double(unit.attack) * unit.modMultiplier(.attack)
        for passive in unit.passives {
            if case let .evenLoopAttack(mul) = passive, unit.currentLoop % 2 == 0 {
                value *= mul
            }
        }
        if unit.ailments.contains(.attackDown) { value *= 0.7 } // 攻撃低下: 攻撃30%低下
        return Int(value)
    }

    /// 与えたダメージ量を返す
    @discardableResult
    private func dealDamage(fromName: String, attackStat: Int, pct: Int, element: Element,
                            to targetID: UUID, critChance: Int,
                            inflict: Ailment?, inflictChance: Int,
                            flatBonus: Int = 0, bonusVsAilment: Bool = false,
                            isAreaAttack: Bool = false,
                            label: String) -> Int {
        guard var target = findUnit(id: targetID), target.isAlive else { return 0 }
        // 敵は防御ステータスを持たない(味方のみ防御でダメージ軽減)。
        // 防御は割合軽減: ×250/(250+防御)。引き算式と違い、
        // 積んでも無敵にならず逓減する(防御150で-38%、300で-55%)
        let defense = target.isAlly ? target.effectiveDefense : 0
        let raw = Double(attackStat) * Double(pct) / 100.0 * 250.0 / (250.0 + Double(defense))
        var damage = max(1, Int(raw * element.multiplier(against: target.element)))
        // クリティカル(短剣など): 2倍
        let isCrit = critChance > 0 && Int.random(in: 0..<100) < critChance
        if isCrit { damage *= 2 }
        // 追い討ち: 状態異常の敵に1.3倍
        if bonusVsAilment, !target.ailments.isEmpty { damage = Int(Double(damage) * 1.3) }
        // 弱体化: 被ダメージ20%アップ
        if target.ailments.contains(.weakness) { damage = Int(Double(damage) * 1.2) }
        // 身代わり(獣使い): 味方に挑発中のユニットがいると全体攻撃を軽減する。
        // 挑発者本人は単体攻撃を集める役なので軽減の対象外
        if isAreaAttack, target.tauntTurns == 0 {
            let friends = target.isAlly ? allies : enemies
            if let reduction = friends.filter({ $0.isAlive && $0.tauntTurns > 0 })
                .map(\.tauntAoEReductionPct).max(), reduction > 0 {
                damage = max(1, Int(Double(damage) * (1.0 - Double(reduction) / 100)))
            }
        }
        // 固定ダメージ追加パッシブ(ヒットごと)
        damage += flatBonus
        // バリア(プチバリア等)が先にダメージを肩代わりする
        if target.barrier > 0 {
            let absorbed = min(target.barrier, damage)
            target.barrier -= absorbed
            damage -= absorbed
        }
        target.hp = max(0, target.hp - damage)
        target.floating = FloatingNumber(value: damage, kind: .damage)
        appendLog("\(fromName)の\(label) → \(target.name)に\(damage)ダメージ\(isCrit ? "(会心!)" : "")")
        lastHitTargets.append(target.id)

        if target.isAlive {
            setTransientState(.hurt, on: &target)
            if let inflict, !target.ailments.contains(inflict), Int.random(in: 0..<100) < inflictChance {
                // 状態異常耐性: 確率で防ぐ
                if let guardPassive = target.gamePassives.first(where: { $0.kind == .ailmentGuard }),
                   Int.random(in: 0..<100) < guardPassive.value {
                    appendLog("\(target.name)は\(inflict.label)を耐性で防いだ")
                } else {
                    target.ailments.insert(inflict)
                    appendLog("\(target.name)は\(inflict.label)状態になった!")
                }
            }
        } else {
            handleDeath(&target)
        }
        updateUnit(target)
        return damage
    }

    private func handleDeath(_ target: inout Unit) {
        // ゾンビの不死パッシブ: 復活のたびに復活時HPが減っていく(いずれ復活しなくなる)
        if let undying = target.passives.first(where: {
            if case .undying = $0 { return true } else { return false }
        }), case let .undying(chance, _, _) = undying,
           target.reviveHPPct > 0, Int.random(in: 0..<100) < chance {
            target.hp = max(1, target.maxHP * target.reviveHPPct / 100)
            target.reviveHPPct = max(0, target.reviveHPPct - target.reviveDecayPct)
            target.ailments = []
            target.stunTurns = 0
            appendLog("\(target.name)は倒れたが……再び起き上がった!!")
            return
        }
        if target.reviveChance > 0, Int.random(in: 0..<100) < target.reviveChance {
            target.hp = target.maxHP / 3
            target.reviveChance = 0
            target.ailments = []
            appendLog("\(target.name)は倒れたが……蘇った!!")
            return
        }
        appendLog("\(target.name)を倒した!")
        // 死者の宴のバフ: 倒れたユニットからミニゾンビが起き上がる(召喚は連鎖しない)
        if target.spawnMiniOnDeath, !target.isSummon {
            target.spawnMiniOnDeath = false
            summonMiniZombie(from: target)
        }
    }

    private func heal(id: UUID, amount: Int) {
        guard var target = findUnit(id: id), target.isAlive else { return }
        let before = target.hp
        target.hp = min(target.maxHP, target.hp + amount)
        let healed = target.hp - before
        if healed > 0 { target.floating = FloatingNumber(value: healed, kind: .heal) }
        updateUnit(target)
    }

    // MARK: - 対象解決

    private func resolveTargets(_ target: ActionTarget, from unit: Unit) -> [UUID] {
        let foes = (unit.isAlly ? enemies : allies).filter(\.isAlive)
        let friends = (unit.isAlly ? allies : enemies).filter(\.isAlive)
        switch target {
        case .singleEnemy:
            // 身代わり(獣使い): 単体攻撃は挑発中のユニットに吸われる
            if let taunter = foes.first(where: { $0.tauntTurns > 0 }) {
                return [taunter.id]
            }
            return foes.randomElement().map { [$0.id] } ?? []
        case .allEnemies:
            return foes.map(\.id)
        case .randomEnemies(let n):
            guard !foes.isEmpty else { return [] }
            return (0..<n).map { _ in foes.randomElement()!.id }
        case .lowestAlly:
            return friends.min { $0.hpRatio < $1.hpRatio }.map { [$0.id] } ?? []
        case .allAllies:
            return friends.map(\.id)
        case .randomAlly:
            return friends.randomElement().map { [$0.id] } ?? []
        case .selfUnit:
            return [unit.id]
        }
    }

    // MARK: - 補正の管理

    private func addModifier(_ modifier: StatModifier, to id: UUID) {
        guard var unit = findUnit(id: id) else { return }
        unit.modifiers.append(modifier)
        updateUnit(unit)
    }

    private func clearOwnerModifiers(ownerID: UUID) {
        func strip(_ units: inout [Unit]) {
            for i in units.indices {
                units[i].modifiers.removeAll {
                    if case .ownerNextAction(ownerID) = $0.expiry { return true }
                    return false
                }
            }
        }
        strip(&allies); strip(&enemies)
    }

    private func decrementSlotModifiers(on unit: inout Unit) {
        for i in unit.modifiers.indices where unit.modifiers[i].expiry == .selfSlots {
            unit.modifiers[i].slotsLeft -= 1
        }
        unit.modifiers.removeAll { $0.expiry == .selfSlots && $0.slotsLeft <= 0 }
    }

    // MARK: - 補助

    private func setTransientState(_ state: SpriteState, on unit: inout Unit) {
        unit.transientState = state
        unit.stateTimer = state.holdDuration ?? 0
    }

    private func findUnit(id: UUID) -> Unit? {
        allies.first { $0.id == id } ?? enemies.first { $0.id == id }
    }

    private func updateUnit(_ unit: Unit) {
        if let i = allies.firstIndex(where: { $0.id == unit.id }) { allies[i] = unit }
        else if let i = enemies.firstIndex(where: { $0.id == unit.id }) { enemies[i] = unit }
    }

    private func appendLog(_ message: String) {
        log.append(message)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }

    private func checkEnd() {
        guard result == nil else { return }
        if !enemies.contains(where: \.isAlive) {
            result = .victory
            appendLog("勝利!! ダンジョンを攻略した!")
        } else if !allies.contains(where: \.isAlive) {
            result = .defeat
            appendLog("全滅してしまった……")
        }
    }
}

private extension BattleEngine.Unit {
    var hpRatio: Double { Double(hp) / Double(max(maxHP, 1)) }
}
