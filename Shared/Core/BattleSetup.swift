import Foundation

// 戦闘ユニットの組み立て(通常のボス戦 / 開発用の調整ステージ)
extension BattleEngine {

    // MARK: - 通常のボス戦(セーブデータから編成)

    static func make(data: SaveData, bossEnemyID: String, mobEnemyIDs: [String]) -> BattleEngine {
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
            engine.allies.append(Unit(
                name: chara.displayName, isAlly: true, element: job.element,
                maxHP: stats.hp, hp: stats.hp,
                attack: stats.attack, defense: stats.defense, speed: stats.speed, magic: stats.magic,
                slots: slots, ultimate: ult, ultimateLoops: chara.ultimate?.requiredLoops ?? 0,
                reviveChance: chara.jobID == "zombie" ? 40 : 0,
                spriteKey: chara.jobID
            ))
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
        engine.enemies.append(enemyUnit(boss))
        for mobID in mobEnemyIDs.shuffled().prefix(2) {
            engine.enemies.append(enemyUnit(EnemyCatalog.enemy(id: mobID)))
        }
        engine.log.append("\(boss.name)が立ちはだかる!")
        return engine
    }

    private static func enemyUnit(_ enemy: Enemy) -> Unit {
        Unit(name: enemy.name, isAlly: false, element: enemy.element,
             maxHP: enemy.stats.hp, hp: enemy.stats.hp,
             attack: enemy.stats.attack, defense: enemy.stats.defense,
             speed: enemy.stats.speed, magic: enemy.stats.magic,
             slots: [.normal, .normal, .normal], spriteKey: enemy.spriteKey)
    }

    /// ゲーム内スキル → 戦闘アクションの変換
    private static func action(from skill: Skill) -> BattleAction {
        switch skill.kind {
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
            Unit(name: "剣士 Lv50", isAlly: true, element: .wind,
                 maxHP: 600, hp: 600, attack: 200 + 55, defense: 150 + 70, speed: 100, magic: 30,
                 slots: [
                    BattleAction(name: "サイクロンソード", kind: .damage(pct: 50, target: .allEnemies)),
                    BattleAction(name: "踏み込み切り", kind: .damage(pct: 140, target: .singleEnemy)),
                    BattleAction(name: "防御の構え", kind: .defenseStance(pct: 30, slots: 2)),
                 ],
                 ultimate: BattleAction(name: "切断", kind: .damage(pct: 300, target: .allEnemies)),
                 ultimateLoops: 2, spriteKey: "swordsman", passives: [.evenLoopAttack(mul: 1.1)])
        }),
        BalanceAlly(id: "spider", displayName: "蜘蛛 Lv50", element: .electric, spriteKey: "spider", make: {
            Unit(name: "蜘蛛 Lv50", isAlly: true, element: .electric,
                 maxHP: 300, hp: 300, attack: 100, defense: 80, speed: 70, magic: 30,
                 slots: [
                    BattleAction(name: "攻撃", kind: .damage(pct: 100, target: .singleEnemy)),
                    BattleAction(name: "イト吐き", kind: .debuffSpeed(pct: 20, target: .singleEnemy)),
                    BattleAction(name: "毒噛みつき", kind: .damage(pct: 80, target: .singleEnemy, poisonChance: 50)),
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
            Unit(name: "悪魔", isAlly: true, element: .dark,
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
        }),
    ]

    static func balanceHydra() -> BattleEngine.Unit {
        // ヒュドラ(中盤ボス・闇)。パッシブ: HP50%以下で毎行動120回復
        Unit(name: "ヒュドラ", isAlly: false, element: .dark,
             maxHP: 3200, hp: 3200, attack: 145, defense: 120, speed: 75, magic: 50,
             slots: [
                BattleAction(name: "毒牙", kind: .damage(pct: 150, target: .singleEnemy, poisonChance: 30)),
                BattleAction(name: "大蛇の尾", kind: .damage(pct: 90, target: .allEnemies)),
                BattleAction(name: "再生", kind: .healFlat(amount: 250, defBuffPct: 20)),
             ],
             ultimate: BattleAction(name: "九頭竜", kind: .damage(pct: 250, target: .allEnemies, poisonChance: 50)),
             ultimateLoops: 2, spriteKey: "hydra",
             passives: [.lowHPRegen(thresholdPct: 50, amount: 120)])
    }

    /// 選んだ味方でヒュドラ戦を組む
    static func makeBalanceStage(allyIDs: [String] = ["swordsman", "spider", "octopus"]) -> BattleEngine {
        let engine = BattleEngine()
        for id in allyIDs {
            if let ally = balanceRoster.first(where: { $0.id == id }) {
                engine.allies.append(ally.make())
            }
        }
        engine.enemies.append(balanceHydra())
        engine.log.append("【調整用】ヒュドラ戦 開始")
        engine.applyBattleStart()
        return engine
    }
}
