import Foundation

// 戦闘ユニットの組み立て(通常のボス戦 / 開発用の調整ステージ)
extension BattleEngine {

    // MARK: - 通常のボス戦(セーブデータから編成)

    static func make(data: SaveData, bossEnemyID: String, mobEnemyIDs: [String], level: Int = 45) -> BattleEngine {
        let engine = BattleEngine()

        for chara in data.partyCharacters {
            let stats = data.effectiveStats(of: chara)
            let job = chara.job()
            var slots: [BattleAction] = (0..<job.slotCount).map { index in
                let placed = chara.placedSkills.indices.contains(index) ? chara.placedSkills[index] : nil
                return placed.map(action(from:)) ?? .normal
            }
            if let weapon = data.weapon(id: chara.weaponID) {
                for (pos, skill) in weapon.skillPositions where pos < slots.count {
                    slots[pos] = action(from: skill)
                }
            }
            let ult = chara.ultimate.map(action(from:))
            var unit = Unit(
                name: chara.displayName, isAlly: true, element: job.element,
                maxHP: stats.hp, hp: stats.hp,
                attack: stats.attack, defense: stats.defense, speed: stats.speed, magic: stats.magic,
                slots: slots, ultimate: ult, ultimateLoops: chara.ultimate?.requiredLoops ?? 0,
                reviveChance: chara.jobID == "zombie" ? 40 : 0,
                spriteKey: chara.jobID
            )
            // 簡易詳細用の表示情報(オトモは装備なし)
            unit.isMainCharacter = true
            if let weapon = data.weapon(id: chara.weaponID) {
                unit.weaponInfo = (icon: weapon.type.symbolName, name: weapon.name)
            }
            if let armor = data.armor(id: chara.armorID) {
                unit.armorInfo = (icon: "shield.fill", name: armor.name)
                unit.extraPassiveLabels = armor.activePassives.map { "\($0.kind.label) +\($0.value)%" }
            }
            engine.allies.append(unit)
        }

        for otomo in data.partyOtomos {
            let stats = otomo.grownStats
            let species = otomo.species()
            let slots: [BattleAction] = (0..<otomo.slotCount).map { index in
                index < otomo.skills.count ? action(from: otomo.skills[index]) : .normal
            }
            let ult = otomo.ultimate.map(action(from:))
            engine.allies.append(Unit(
                name: otomo.displayName, isAlly: true, element: species.element,
                maxHP: stats.hp, hp: stats.hp,
                attack: stats.attack, defense: stats.defense, speed: stats.speed, magic: stats.magic,
                slots: slots, ultimate: ult, ultimateLoops: otomo.ultimate?.requiredLoops ?? 0,
                spriteKey: species.id
            ))
        }

        let boss = EnemyCatalog.enemy(id: bossEnemyID)
        engine.enemies.append(enemyUnit(boss, level: level))
        for mobID in mobEnemyIDs.shuffled().prefix(2) {
            engine.enemies.append(enemyUnit(EnemyCatalog.enemy(id: mobID), level: level))
        }
        engine.log.append("\(boss.name)が立ちはだかる!")
        return engine
    }

    // MARK: - 敵のレベルスケーリング

    /// 敵ステータスの倍率。カタログ値は「推奨Lv45相当」の基準値
    /// (無貌の回廊 最終ボス=シミュレーターのヒュドラと同格がアンカー)。
    static func enemyScale(level: Int) -> Double {
        Double(max(1, level)) / 45.0
    }

    /// 敵ユニットを推奨レベルに応じてスケーリングして生成する。
    /// 素早さだけは緩やかに変化(低レベル帯でも行動させ、高レベル帯で速くなりすぎない)
    static func enemyUnit(_ enemy: Enemy, level: Int = 45) -> Unit {
        let scale = enemyScale(level: level)
        let speedScale = 0.5 + 0.5 * scale
        let hp = max(10, Int(Double(enemy.stats.hp) * scale))
        let kit = bossKit(for: enemy.id, scale: scale)
        return Unit(name: enemy.name, isAlly: false, element: enemy.element,
                    maxHP: hp, hp: hp,
                    attack: max(1, Int(Double(enemy.stats.attack) * scale)),
                    defense: 0,
                    speed: max(5, Int(Double(enemy.stats.speed) * speedScale)),
                    magic: max(1, Int(Double(enemy.stats.magic) * scale)),
                    slots: kit.slots, ultimate: kit.ultimate, ultimateLoops: kit.ultimateLoops,
                    spriteKey: enemy.spriteKey, passives: kit.passives)
    }

    /// ボスの技キット。無貌の回廊最終ボスは調整基準のヒュドラ戦と同じ構成
    /// (単体150%+状態異常30% / 全体90% / 自己回復)+必殺2巡+低HP再生。
    private static func bossKit(for enemyID: String, scale: Double)
        -> (slots: [BattleAction], ultimate: BattleAction?, ultimateLoops: Int, passives: [BattlePassive]) {
        let heal = max(10, Int(250 * scale))
        let regen = max(5, Int(120 * scale))
        switch enemyID {
        case "nyarlathotep_boss":
            // アンカー: ヒュドラと同数値・同構成(毒→洗脳のフレーバー違い)
            return ([
                BattleAction(name: "無貌の爪", kind: .damage(pct: 150, target: .singleEnemy, inflict: .brainwash, inflictChance: 30)),
                BattleAction(name: "混沌の波動", kind: .damage(pct: 90, target: .allEnemies)),
                BattleAction(name: "姿なき修復", kind: .healFlat(amount: heal)),
            ],
            BattleAction(name: "千の異形", kind: .damage(pct: 250, target: .allEnemies, inflict: .brainwash, inflictChance: 50)),
            2, [.lowHPRegen(thresholdPct: 50, amount: regen)])
        case "cthulhu_boss":
            return ([
                BattleAction(name: "触手の薙ぎ払い", kind: .damage(pct: 150, target: .singleEnemy, inflict: .poison, inflictChance: 30)),
                BattleAction(name: "深淵の咆哮", kind: .damage(pct: 90, target: .allEnemies)),
                BattleAction(name: "深海の再生", kind: .healFlat(amount: heal)),
            ],
            BattleAction(name: "ルルイエの呼び声", kind: .damage(pct: 250, target: .allEnemies, inflict: .speedDown, inflictChance: 50)),
            2, [.lowHPRegen(thresholdPct: 50, amount: regen)])
        case "azathoth_boss":
            return ([
                BattleAction(name: "混沌の一撃", kind: .damage(pct: 170, target: .singleEnemy, inflict: .weakness, inflictChance: 30)),
                BattleAction(name: "星喰らい", kind: .damage(pct: 100, target: .allEnemies)),
                BattleAction(name: "無窮の脈動", kind: .healFlat(amount: heal)),
            ],
            BattleAction(name: "白痴の宴", kind: .damage(pct: 300, target: .allEnemies, inflict: .weakness, inflictChance: 50)),
            2, [.lowHPRegen(thresholdPct: 50, amount: regen)])
        case "necronomicon_boss":
            return ([
                BattleAction(name: "禁書の裁き", kind: .damage(pct: 140, target: .singleEnemy, inflict: .burn, inflictChance: 30)),
                BattleAction(name: "頁の嵐", kind: .damage(pct: 85, target: .allEnemies)),
                BattleAction(name: "綴じ直し", kind: .healFlat(amount: heal)),
            ],
            BattleAction(name: "禁断の章句", kind: .damage(pct: 250, target: .allEnemies, inflict: .reverse, inflictChance: 50)),
            2, [.lowHPRegen(thresholdPct: 50, amount: regen)])
        case "dragon_enemy":
            return ([
                BattleAction(name: "爪撃", kind: .damage(pct: 150, target: .singleEnemy)),
                BattleAction(name: "ブレス", kind: .damage(pct: 90, target: .allEnemies, inflict: .burn, inflictChance: 30)),
                .normal,
            ],
            BattleAction(name: "劫火", kind: .damage(pct: 220, target: .allEnemies, inflict: .burn, inflictChance: 40)),
            2, [])
        default:
            // 雑魚・中ボスは通常攻撃のみ
            return ([.normal, .normal, .normal], nil, 0, [])
        }
    }

    /// ゲーム内スキル → 戦闘アクションの変換
    private static func action(from skill: Skill) -> BattleAction {
        // 武器スキルは武器種の効果傾向を優先する
        if let effect = skill.weaponEffect {
            switch effect {
            case .single:     // 剣: 単体
                return BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy))
            case .aoe:        // 大剣: 全体攻撃
                return BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .allEnemies))
            case .crit:       // 短剣: クリティカル
                return BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy, critChance: 40))
            case .multiHit:   // 双剣: 複数回攻撃
                return BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy, hits: 2...2))
            case .magic:      // 杖: 魔力依存
                return BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy, stat: .magic))
            case .randomHits: // リボルバー: ランダムな回数攻撃
                return BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy, hits: 1...5))
            case .debuff:     // 弓: デバフ(攻撃低下 or 速度低下を付与)
                return BattleAction(name: skill.name, kind: .damage(
                    pct: skill.power, target: .singleEnemy,
                    inflict: Bool.random() ? .attackDown : .speedDown, inflictChance: 40))
            }
        }
        return switch skill.kind {
        case .attack, .specialAttack:
            BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy))
        case .magic:
            BattleAction(name: skill.name, kind: .damage(pct: skill.power, target: .singleEnemy, stat: .magic))
        case .heal:
            BattleAction(name: skill.name, kind: .healByMagic(target: .lowestAlly))
        case .buff:
            BattleAction(name: skill.name, kind: .buffAttack(pct: max(5, skill.power / 10), target: .selfUnit))
        case .debuff:
            BattleAction(name: skill.name, kind: .debuffSpeed(pct: max(5, skill.power / 10), target: .singleEnemy))
        case .barrier:
            BattleAction(name: skill.name, kind: .defenseStance(pct: 30, slots: 2))
        }
    }

    private static func action(from ultimate: UltimateSkill) -> BattleAction {
        let kind: BattleAction.Kind
        switch ultimate.kind {
        case .damageSingle:
            kind = .damage(pct: ultimate.power, target: .singleEnemy)
        case .damageAll, .triggerWeaponSkills:
            kind = .damage(pct: ultimate.power, target: .allEnemies)
        case .heal:
            kind = .healByMagic(target: .lowestAlly)
        case .buff, .extraActions:
            kind = .buffAttack(pct: max(10, ultimate.power / 10), target: .selfUnit)
        case .stopEnemies:
            kind = .debuffSpeed(pct: 50, target: .allEnemies)
        case .barrier:
            kind = .defenseStance(pct: 30, slots: 3)
        }
        return BattleAction(name: ultimate.name, kind: kind)
    }

    // MARK: - 開発用の調整ステージ(味方を選んで ヒュドラ と戦う)

    /// 調整ステージで選べる味方の定義
    struct BalanceAlly: Identifiable {
        let id: String
        let displayName: String
        let element: Element
        let spriteKey: String
        let make: () -> BattleEngine.Unit
    }

    static let balanceRoster: [BalanceAlly] = [
        BalanceAlly(id: "swordsman", displayName: "剣士 Lv50", element: .wind, spriteKey: "swordsman", make: {
            // 武器: 星の剣、防具: 丈夫な鎧(偶数巡目の攻撃1.1倍)
            var unit = Unit(name: "剣士 Lv50", isAlly: true, element: .wind,
                 maxHP: 600, hp: 600, attack: 200 + 55, defense: 150 + 70, speed: 100, magic: 30,
                 slots: [
                    BattleAction(name: "サイクロンソード", kind: .damage(pct: 50, target: .allEnemies)),
                    BattleAction(name: "踏み込み切り", kind: .damage(pct: 140, target: .singleEnemy)),
                    BattleAction(name: "防御の構え", kind: .defenseStance(pct: 30, slots: 2)),
                 ],
                 ultimate: BattleAction(name: "切断", kind: .damage(pct: 300, target: .allEnemies)),
                 ultimateLoops: 2, spriteKey: "swordsman", passives: [.evenLoopAttack(mul: 1.1)])
            unit.isMainCharacter = true
            unit.weaponInfo = (icon: "sword.fill", name: "星の剣 ★★")
            unit.armorInfo = (icon: "shield.fill", name: "丈夫な鎧 ★★")
            unit.extraPassiveLabels = ["偶数巡目の攻撃1.1倍(丈夫な鎧)"]
            return unit
        }),
        BalanceAlly(id: "spider", displayName: "蜘蛛 Lv50", element: .electric, spriteKey: "spider", make: {
            Unit(name: "蜘蛛 Lv50", isAlly: true, element: .electric,
                 maxHP: 300, hp: 300, attack: 100, defense: 80, speed: 70, magic: 30,
                 slots: [
                    BattleAction(name: "攻撃", kind: .damage(pct: 100, target: .singleEnemy)),
                    BattleAction(name: "イト吐き", kind: .debuffSpeed(pct: 20, target: .singleEnemy)),
                    BattleAction(name: "毒噛みつき", kind: .damage(pct: 80, target: .singleEnemy, inflict: .poison, inflictChance: 50)),
                 ],
                 spriteKey: "spider")
        }),
        BalanceAlly(id: "octopus", displayName: "タコ Lv50", element: .water, spriteKey: "octopus", make: {
            Unit(name: "タコ Lv50", isAlly: true, element: .water,
                 maxHP: 350, hp: 350, attack: 70, defense: 95, speed: 65, magic: 40,
                 slots: [
                    BattleAction(name: "タコパンチ", kind: .damage(pct: 60, target: .randomEnemies(2))),
                    BattleAction(name: "タコヒール", kind: .healByMagic(target: .lowestAlly)),
                    BattleAction(name: "タコタコ", kind: .buffAttack(pct: 10, target: .randomAlly)),
                 ],
                 ultimate: BattleAction(name: "タコラッシュ", kind: .damage(pct: 40, target: .randomEnemies(8))),
                 ultimateLoops: 2, spriteKey: "octopus")
        }),
        BalanceAlly(id: "akuma", displayName: "悪魔", element: .dark, spriteKey: "akuma", make: {
            // 悪魔(進化なし・闇・スロット4)。禊は(攻撃+魔力)基準の全体攻撃
            var unit = Unit(name: "悪魔", isAlly: true, element: .dark,
                 maxHP: 1200, hp: 1200, attack: 200, defense: 200, speed: 150, magic: 70,
                 slots: [
                    BattleAction(name: "カオス", kind: .chaos(chance: 30, spdDownPct: 30, atkDownPct: 30, turns: 3)),
                    BattleAction(name: "瞑想", kind: .meditate(magicUpPct: 5, healPctMaxHP: 10)),
                    BattleAction(name: "魔炎", kind: .damage(pct: 150, target: .singleEnemy, stat: .attackPlusMagic)),
                    AkumaActions.offering, // 供物の選定 ↔ サクリファイス
                 ],
                 ultimate: BattleAction(name: "禊", kind: .damage(pct: 400, target: .allEnemies, stat: .attackPlusMagic)),
                 ultimateLoops: 2, spriteKey: "akuma",
                 passives: [.drainAlliesMagic(pct: 50)])
            unit.isMainCharacter = true
            return unit
        }),
    ]

    /// ヒュドラ(中盤ボス)。属性は検証用に差し替え可能(既定は闇)
    static func balanceHydra(element: Element = .dark) -> BattleEngine.Unit {
        // パッシブ: HP50%以下で毎行動120回復
        Unit(name: "ヒュドラ", isAlly: false, element: element,
             maxHP: 3200, hp: 3200, attack: 145, defense: 120, speed: 75, magic: 50,
             slots: [
                BattleAction(name: "毒牙", kind: .damage(pct: 150, target: .singleEnemy, inflict: .poison, inflictChance: 30)),
                BattleAction(name: "大蛇の尾", kind: .damage(pct: 90, target: .allEnemies)),
                BattleAction(name: "再生", kind: .healFlat(amount: 250, defBuffPct: 20)),
             ],
             ultimate: BattleAction(name: "九頭竜", kind: .damage(pct: 250, target: .allEnemies, inflict: .poison, inflictChance: 50)),
             ultimateLoops: 2, spriteKey: "hydra",
             passives: [.lowHPRegen(thresholdPct: 50, amount: 120)])
    }

    /// 選んだ味方でヒュドラ戦を組む(敵属性は検証用に指定可能)
    static func makeBalanceStage(allyIDs: [String] = ["swordsman", "spider", "octopus"],
                                 enemyElement: Element = .dark) -> BattleEngine {
        let engine = BattleEngine()
        for id in allyIDs {
            if let ally = balanceRoster.first(where: { $0.id == id }) {
                engine.allies.append(ally.make())
            }
        }
        engine.enemies.append(balanceHydra(element: enemyElement))
        engine.log.append("【調整用】ヒュドラ戦 開始")
        engine.applyBattleStart()
        return engine
    }
}
