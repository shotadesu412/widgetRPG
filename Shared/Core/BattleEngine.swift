import Foundation

// MARK: - 行動(スロット/必殺技の効果定義)

/// 対象の取り方
enum ActionTarget: Hashable {
    case singleEnemy         // 敵単体(生存からランダム)
    case allEnemies          // 敵全体
    case randomEnemies(Int)  // ランダムな敵にヒット数ぶん(毎回抽選)
    case lowestAlly          // 最もHP割合の低い味方
    case randomAlly          // ランダムな味方
    case selfUnit            // 自分
}

/// ダメージの参照ステータス
enum DamageStat: Hashable {
    case attack           // 攻撃力
    case magic            // 魔力
    case attackPlusMagic  // 攻撃力+魔力の合計
}

/// 戦闘中の1行動。スキル・必殺技・通常攻撃を統一して表現する。
struct BattleAction: Hashable {
    var name: String
    var kind: Kind

    enum Kind: Hashable {
        /// ダメージ。pct=参照ステータスに対する%。poisonChance=毒付与確率(%)
        case damage(pct: Int, target: ActionTarget, stat: DamageStat = .attack, poisonChance: Int = 0)
        /// 術者の魔力ぶん回復
        case healByMagic(target: ActionTarget)
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
        var spriteKey: String
        var passives: [BattlePassive] = []

        // 状態
        var poisoned = false
        var modifiers: [StatModifier] = []
        /// サクリファイス用: 供物の選定で記憶した対象
        var offeringTargetID: UUID?
        var transientState: SpriteState?
        var stateTimer: Double = 0

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

        var effectiveSpeed: Int { max(1, Int(Double(speed) * modMultiplier(.speed))) }
        var effectiveDefense: Int { max(0, Int(Double(defense) * modMultiplier(.defense))) }
    }

    enum BattleResult { case victory, defeat }

    @Published var allies: [Unit] = []
    @Published var enemies: [Unit] = []
    @Published var log: [String] = []
    @Published var result: BattleResult?

    /// 行動後の待ち時間(この間はゲージが止まる)
    private var actionPause: Double = 0
    /// 行動ごとに置く間の長さ(秒)
    private let actionBeat: Double = 0.6

    /// 戦闘開始時のパッシブを適用する(ユニット組み立て後に一度だけ呼ぶ)
    func applyBattleStart() {
        for i in allies.indices {
            for passive in allies[i].passives {
                if case let .drainAlliesMagic(pct) = passive {
                    var total = 0
                    for j in allies.indices where j != i {
                        total += allies[j].magic
                        allies[j].magic = 0
                    }
                    let gain = total * pct / 100
                    allies[i].magic += gain
                    appendLog("\(allies[i].name)の儀式! 味方の魔力を吸収した(魔力+\(gain))")
                }
            }
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
        for i in units.indices where units[i].isAlive {
            units[i].gauge = min(1.0, units[i].gauge + deltaTime * Double(units[i].effectiveSpeed) / 60.0)
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

        // 1. 毒ダメージ(現在HPの5%)。20%で解除
        if unit.poisoned {
            let dmg = max(1, Int(Double(unit.hp) * 0.05))
            unit.hp = max(0, unit.hp - dmg)
            unit.floating = FloatingNumber(value: dmg, kind: .poison)
            appendLog("\(unit.name)は毒で\(dmg)ダメージ")
            if Int.random(in: 0..<100) < 20 {
                unit.poisoned = false
                appendLog("\(unit.name)の毒が解けた")
            }
            if !unit.isAlive {
                handleDeath(&unit)
                updateUnit(unit)
                checkEnd()
                return
            }
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

        // 4. 行動本体。足元にスキル名を出す
        if unit.ultimateReady, let ultimate = unit.ultimate {
            setActionLabel(ultimate.name, on: &unit)
            setTransientState(.ultimate, on: &unit)
            appendLog("必殺技! \(unit.name)の「\(ultimate.name)」!!")
            perform(ultimate, by: &unit)
            unit.loops = 0
        } else {
            let action = unit.slots.isEmpty ? .normal : unit.slots[unit.slotIndex]
            setActionLabel(action.name, on: &unit)
            setTransientState(action.spriteState, on: &unit)
            perform(action, by: &unit)
            // 供物の選定 ↔ サクリファイス はスロットが交互に変化する
            toggleAkumaSlot(action, on: &unit)
            // スロット発動回数で切れる補正(防御の構えなど)を減らす
            decrementSlotModifiers(on: &unit)
            unit.slotIndex += 1
            if unit.slotIndex >= unit.slots.count {
                unit.slotIndex = 0
                unit.loops += 1
            }
        }

        updateUnit(unit)
        checkEnd()
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

    // MARK: - 行動の解決

    private func perform(_ action: BattleAction, by unit: inout Unit) {
        switch action.kind {
        case .normalAttack:
            dealToTargets(from: &unit, pct: 100, target: .singleEnemy, stat: .attack,
                          poisonChance: 0, label: "攻撃")
        case let .damage(pct, target, stat, poisonChance):
            dealToTargets(from: &unit, pct: pct, target: target, stat: stat,
                          poisonChance: poisonChance, label: action.name)
        case let .healByMagic(target):
            for id in resolveTargets(target, from: unit) {
                heal(id: id, amount: unit.magic)
            }
            appendLog("\(unit.name)の\(action.name)! 魔力ぶん回復した")
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
        }
    }

    private func dealToTargets(from unit: inout Unit, pct: Int, target: ActionTarget,
                               stat: DamageStat, poisonChance: Int, label: String) {
        let targets = resolveTargets(target, from: unit)
        guard !targets.isEmpty else { return }
        let value: Int
        switch stat {
        case .attack: value = effectiveAttack(of: unit)
        case .magic: value = unit.magic
        case .attackPlusMagic: value = effectiveAttack(of: unit) + unit.magic
        }
        for id in targets {
            dealDamage(fromName: unit.name, attackStat: value, pct: pct,
                       element: unit.element, to: id, poisonChance: poisonChance, label: label)
        }
    }

    // MARK: - 悪魔の固有行動

    private func performChaos(from unit: Unit, chance: Int, spdDown: Int, atkDown: Int, turns: Int, label: String) {
        let foes = (unit.isAlly ? enemies : allies).filter(\.isAlive)
        guard !foes.isEmpty else { return }
        let n = Int.random(in: 1...foes.count) // ランダムな数の敵
        appendLog("\(unit.name)の\(label)! \(n)体を狙う")
        for foe in foes.shuffled().prefix(n) {
            guard var t = findUnit(id: foe.id) else { continue }
            var hit = false
            if Int.random(in: 0..<100) < chance, !t.poisoned { t.poisoned = true; hit = true }
            if Int.random(in: 0..<100) < chance {
                t.modifiers.append(StatModifier(stat: .speed, mul: 1.0 - Double(spdDown) / 100, expiry: .turns(turns), turnsLeft: turns)); hit = true
            }
            if Int.random(in: 0..<100) < chance {
                t.modifiers.append(StatModifier(stat: .attack, mul: 1.0 - Double(atkDown) / 100, expiry: .turns(turns), turnsLeft: turns)); hit = true
            }
            if hit { updateUnit(t) }
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
        target.poisoned = false
        updateUnit(target)
        appendLog("\(unit.name)の\(label)! \(target.name)を捧げ、力を得た")
        unit.offeringTargetID = nil
        checkEnd()
    }

    /// 偶数巡目パッシブ等を反映した実効攻撃力
    private func effectiveAttack(of unit: Unit) -> Int {
        var value = Double(unit.attack) * unit.modMultiplier(.attack)
        for passive in unit.passives {
            if case let .evenLoopAttack(mul) = passive, unit.currentLoop % 2 == 0 {
                value *= mul
            }
        }
        return Int(value)
    }

    private func dealDamage(fromName: String, attackStat: Int, pct: Int, element: Element,
                            to targetID: UUID, poisonChance: Int, label: String) {
        guard var target = findUnit(id: targetID), target.isAlive else { return }
        // 敵は防御ステータスを持たない(味方のみ防御でダメージ軽減)
        let defense = target.isAlly ? target.effectiveDefense : 0
        let raw = Double(attackStat) * Double(pct) / 100.0 - Double(defense) / 2.0
        let damage = max(1, Int(raw * element.multiplier(against: target.element)))
        target.hp = max(0, target.hp - damage)
        target.floating = FloatingNumber(value: damage, kind: .damage)
        appendLog("\(fromName)の\(label) → \(target.name)に\(damage)ダメージ")

        if target.isAlive {
            setTransientState(.hurt, on: &target)
            if poisonChance > 0, !target.poisoned, Int.random(in: 0..<100) < poisonChance {
                target.poisoned = true
                appendLog("\(target.name)は毒におかされた!")
            }
        } else {
            handleDeath(&target)
        }
        updateUnit(target)
    }

    private func handleDeath(_ target: inout Unit) {
        if target.reviveChance > 0, Int.random(in: 0..<100) < target.reviveChance {
            target.hp = target.maxHP / 3
            target.reviveChance = 0
            target.poisoned = false
            appendLog("\(target.name)は倒れたが……蘇った!!")
        } else {
            appendLog("\(target.name)を倒した!")
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
            return foes.randomElement().map { [$0.id] } ?? []
        case .allEnemies:
            return foes.map(\.id)
        case .randomEnemies(let n):
            guard !foes.isEmpty else { return [] }
            return (0..<n).map { _ in foes.randomElement()!.id }
        case .lowestAlly:
            return friends.min { $0.hpRatio < $1.hpRatio }.map { [$0.id] } ?? []
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
