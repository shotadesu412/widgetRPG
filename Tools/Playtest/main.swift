// ヘッドレス・プレイテスト。
// ゲーム本体の Shared ロジック(IdleEngine/BattleEngine/カタログ)をそのまま使い、
// 新規データからメイン4系統クリアまでを「普通のプレイヤー」の方針で自動プレイして
// 進行ペース・経済・戦闘のボトルネックを計測する。
//
// 実行: Tools/Playtest/run.sh

import Foundation

// MARK: - 設定

let maxDays = 120.0            // 打ち切り(日)
let tickMinutes = 10           // 時間送りの粒度
let battleTimeCap = 900.0      // 1戦闘の上限(シミュレーション秒)

// MARK: - 状態

var data = SaveData.newGame(now: Date(timeIntervalSince1970: 0))
var now = Date(timeIntervalSince1970: 0)
var log: [String] = []
var stats = PlayStats()

struct PlayStats {
    var battles = 0
    var defeats = 0
    var retries: [String: Int] = [:]      // dungeonID → 敗北数
    var mapClearDay: [String: Double] = [:]
    var stoneShortageEvents = 0
    var stoneWaitHours = 0.0
    var shopStonesSeen = 0
    var shopStonesBought = 0
    var eggsObtained = 0
    var eggsHatched = 0
    var eggBacklogMax = 0
    var coinsSpent = 0
    var battleSeconds: [Double] = []
    var levelAtClear: [String: Int] = [:]
}

func day() -> Double { now.timeIntervalSince1970 / 86400 }
func hhmm() -> String { String(format: "%5.1f日", day()) }
func note(_ s: String) { log.append("[\(hhmm())] \(s)") }

// MARK: - プレイヤー方針(普通のプレイヤーを想定)

func mainCharIndex() -> Int { data.characters.firstIndex { $0.id == data.partyCharacterIDs.first } ?? 0 }

func manageEquipment() {
    // 最良の武器/防具を装備
    let i = mainCharIndex()
    if let best = data.weapons.max(by: { ($0.upgradedBonus.attack + $0.upgradedBonus.magic) < ($1.upgradedBonus.attack + $1.upgradedBonus.magic) }) {
        data.characters[i].weaponID = best.id
    }
    if let best = data.armors.max(by: { ($0.bonus.defense + $0.bonus.hp) < ($1.bonus.defense + $1.bonus.hp) }) {
        data.characters[i].armorID = best.id
    }
    // 素材が潤沢なら装備を強化(武器優先)
    if let wi = data.weapons.firstIndex(where: { $0.id == data.characters[i].weaponID }) {
        while data.weapons[wi].canUpgrade,
              data.materials >= EquipmentUpgrade.materialCost(toLevel: data.weapons[wi].upgradeLevel + 1) {
            data.materials -= EquipmentUpgrade.materialCost(toLevel: data.weapons[wi].upgradeLevel + 1)
            data.weapons[wi].upgradeLevel += 1
            note("武器強化 → Lv\(data.weapons[wi].upgradeLevel)")
        }
    }
    if let ai = data.armors.firstIndex(where: { $0.id == data.characters[i].armorID }) {
        while data.armors[ai].canUpgrade,
              data.materials >= EquipmentUpgrade.materialCost(toLevel: data.armors[ai].upgradeLevel + 1) {
            data.materials -= EquipmentUpgrade.materialCost(toLevel: data.armors[ai].upgradeLevel + 1)
            data.armors[ai].upgradeLevel += 1
        }
    }
}

func manageEvolution() {
    let i = mainCharIndex()
    let chara = data.characters[i]
    guard chara.canEvolve else { return }
    let element = chara.job().element
    if data.stoneCount(element) > 0 {
        data.elementStones[element.rawValue, default: 1] -= 1
        data.characters[i].stage += 1
        let job = chara.job()
        data.characters[i].learnedSkills.append(
            Skill(name: "\(job.name(atStage: chara.stage + 1))の奥義", kind: .specialAttack,
                  power: 140 + (chara.stage + 1) * 40, element: job.element))
        // 新スキルを空きスロットに配置
        if let slot = data.characters[i].placedSkills.firstIndex(where: { $0 == nil }) {
            data.characters[i].placedSkills[slot] = data.characters[i].learnedSkills.last
        }
        note("進化! → \(data.characters[i].displayName)(石消費、残\(data.stoneCount(element)))")
    } else {
        stats.stoneShortageEvents += 1
        stats.stoneWaitHours += Double(tickMinutes) / 60
    }
}

func manageShop() {
    let element = data.characters[mainCharIndex()].job().element
    for item in data.shop.items {
        guard data.coins >= item.price else { continue }
        var buy = false
        switch item.kind {
        case .elementStone:
            stats.shopStonesSeen += 1
            if item.element == element { buy = true; stats.shopStonesBought += 1 }
        case .material where data.materials < 100: buy = true
        case .egg where item.eggGrade != .normal: buy = true  // 珍しい/伝説の卵は買う
        default: break
        }
        if buy, let idx = data.shop.items.firstIndex(where: { $0.id == item.id }) {
            data.coins -= item.price
            stats.coinsSpent += item.price
            data.shop.items.remove(at: idx)
            switch item.kind {
            case .elementStone: data.elementStones[item.element!.rawValue, default: 0] += item.amount
            case .material: data.materials += item.amount
            case .egg:
                data.eggs.append(ItemFactory.makeEgg(grade: item.eggGrade ?? .normal, now: now))
                stats.eggsObtained += 1
            default: break
            }
            note("購入: \(item.name)(\(item.price)コイン)")
        }
    }
}

func manageEggs() {
    // 孵化完了 → 迎える
    if let egg = data.incubatingEgg, egg.isReady(now: now) {
        if let idx = data.eggs.firstIndex(where: { $0.id == egg.id }) {
            data.eggs.remove(at: idx)
            data.incubatingEggID = nil
            let otomo = ItemFactory.hatch(egg)
            data.otomos.append(otomo)
            stats.eggsHatched += 1
            note("孵化: \(otomo.displayName) \(otomo.rarity.stars)(個体値計\(otomo.ivs.total >= 0 ? "+" : "")\(otomo.ivs.total))")
        }
    }
    // 良い卵からセット(伝説>珍しい>普通)
    if data.incubatingEggID == nil {
        let order: [EggGrade] = [.legendary, .uncommon, .normal]
        for grade in order {
            if let idx = data.eggs.firstIndex(where: { $0.grade == grade && !$0.isIncubating }) {
                data.eggs[idx].incubationStartedAt = now
                data.eggs[idx].hatchSeconds = grade.hatchSeconds
                data.incubatingEggID = data.eggs[idx].id
                break
            }
        }
    }
    stats.eggBacklogMax = max(stats.eggBacklogMax, data.eggs.count)
    // パーティに最強オトモ2匹
    let sorted = data.otomos.sorted {
        let a = $0.grownStats, b = $1.grownStats
        return a.hp + a.attack * 3 > b.hp + b.attack * 3
    }
    data.partyOtomoIDs = sorted.prefix(2).map(\.id)
}

// MARK: - 戦闘

func fightBoss(dungeon: Dungeon) -> Bool {
    let engine = BattleEngine.make(
        data: data, bossEnemyID: dungeon.bossEnemyID,
        mobEnemyIDs: dungeon.mobEnemyIDs, level: dungeon.recommendedLevel)
    var t = 0.0
    while engine.result == nil && t < battleTimeCap {
        engine.tick(deltaTime: 0.1)
        t += 0.1
    }
    stats.battles += 1
    stats.battleSeconds.append(t)
    let win = engine.result == .victory
    if !win {
        stats.defeats += 1
        stats.retries[dungeon.id, default: 0] += 1
    }
    return win
}

// MARK: - メインループ

var arcs = MainArc.allCases
note("プレイ開始: \(data.characters[0].displayName) / コイン\(data.coins)")

outer: while day() < maxDays {
    // 攻略対象 = 次のメインマップ
    let unlocked = DungeonCatalog.unlocked(mainProgress: data.mainProgress)
    guard let target = unlocked.first(where: { $0.kind == .main }) else {
        note("メイン全クリア!")
        break
    }

    // 潜入
    data.activeRun = DungeonRun(dungeonID: target.id, now: now)

    // ボス発見まで時間を送る(その間に日課)
    var found = false
    while !found && day() < maxDays {
        now = now.addingTimeInterval(TimeInterval(tickMinutes * 60))
        IdleEngine.process(&data, now: now)
        manageEggs()
        manageShop()
        manageEvolution()
        if data.activeRun?.bossFound == true { found = true }
    }
    guard found else { break }

    manageEquipment()

    // ボス戦(負けたら撤退→再潜入で再挑戦)
    let win = fightBoss(dungeon: target)
    IdleEngine.settleRun(&data, bossDefeated: win)
    if win {
        let d = day()
        stats.mapClearDay[target.id] = d
        stats.levelAtClear[target.id] = data.characters[mainCharIndex()].level
        if target.mapIndex == MainArc.mapsPerArc {
            note("★系統クリア: \(target.name) Lv\(data.characters[mainCharIndex()].level)")
        } else if target.mapIndex! % 5 == 0 {
            note("攻略: \(target.name) Lv\(data.characters[mainCharIndex()].level) コイン\(data.coins) 素材\(data.materials)")
        }
    } else {
        note("敗北: \(target.name)(Lv\(data.characters[mainCharIndex()].level))→ 再挑戦")
    }
}

// MARK: - レポート

print("================ プレイログ(抜粋) ================")
for line in log { print(line) }

print("\n================ 統計 ================")
let hero = data.characters[mainCharIndex()]
print("経過: \(String(format: "%.1f", day()))日 / 最終Lv\(hero.level)(\(hero.displayName))")
print("戦闘: \(stats.battles)回(敗北\(stats.defeats)回)")
if !stats.battleSeconds.isEmpty {
    let sorted = stats.battleSeconds.sorted()
    print("戦闘時間: 中央値\(Int(sorted[sorted.count/2]))秒 / 最長\(Int(sorted.last!))秒")
}
if !stats.retries.isEmpty {
    print("敗北したマップ:")
    for (id, count) in stats.retries.sorted(by: { $0.value > $1.value }).prefix(8) {
        print("  \(DungeonCatalog.dungeon(id: id).name): \(count)敗")
    }
}
for arc in arcs {
    let id = "main_\(arc.rawValue)_\(MainArc.mapsPerArc)"
    if let d = stats.mapClearDay[id] {
        print("\(arc.areaName)クリア: \(String(format: "%.1f", d))日目(Lv\(stats.levelAtClear[id] ?? 0))")
    } else {
        print("\(arc.areaName): 未クリア")
    }
}
print("属性石: 不足で進化待ちになった時間 \(String(format: "%.1f", stats.stoneWaitHours))時間(ショップで石を見た回数\(stats.shopStonesSeen)/買えた\(stats.shopStonesBought))")
print("卵: 入手\(stats.eggsObtained + stats.eggsHatched)個 孵化\(stats.eggsHatched)体 未処理の最大在庫\(stats.eggBacklogMax)個")
print("経済: コイン残\(data.coins)(消費\(stats.coinsSpent)) 素材残\(data.materials)")
print("オトモ: \(data.otomos.count)体 パーティ=\(data.partyOtomos.map { "\($0.displayName)\($0.rarity.stars)Lv\($0.level)" }.joined(separator: ","))")
let gradeCount = Dictionary(grouping: data.eggs, by: \.grade).mapValues(\.count)
print("卵在庫内訳: \(gradeCount.map { "\($0.key.label)×\($0.value)" }.sorted().joined(separator: " "))")
