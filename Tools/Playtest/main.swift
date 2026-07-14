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
    var fusions = 0
    var scouted = 0
    var bossWaitHours: [Double] = []
    var shrineRuns = 0
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
    if CharacterProgression.evolve(&data, characterID: chara.id) {
        note("進化! → \(data.characters[i].displayName)(必殺技: \(data.characters[i].ultimate?.name ?? "なし") / 残り石\(data.stoneCount(chara.job().element)))")
    } else {
        stats.stoneShortageEvents += 1
        // 進化待ちの時間(カジュアルはチェック間隔ぶん)
        stats.stoneWaitHours += casual ? 4.8 : Double(tickMinutes) / 60
    }
}

func manageFusion() {
    // 同一種族・同一星が3体以上いたら合成してレア度を上げる
    for base in data.otomos where base.rarity < .star3 && base.species().canEvolve {
        let sameKind = data.otomos.filter {
            $0.id != base.id && $0.speciesID == base.speciesID && $0.rarity == base.rarity
        }
        guard sameKind.count >= 2 else { continue }
        let consumed = sameKind.sorted { $0.ivs.total < $1.ivs.total }.prefix(2).map(\.id)
        data.otomos.removeAll { consumed.contains($0.id) }
        data.partyOtomoIDs.removeAll { consumed.contains($0) }
        if let idx = data.otomos.firstIndex(where: { $0.id == base.id }) {
            data.otomos[idx].rarity = Rarity(rawValue: base.rarity.rawValue + 1) ?? .star3
            note("合成: \(base.displayName) → \(data.otomos[idx].rarity.stars)")
            stats.fusions += 1
        }
        break
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
    // テイマー加入後: 普通の卵はまとめて即時孵化
    if data.characters.contains(where: { $0.jobID == "monster_tamer" }) {
        while let idx = data.eggs.firstIndex(where: { $0.grade == .normal && !$0.isIncubating }) {
            let egg = data.eggs.remove(at: idx)
            data.otomos.append(ItemFactory.hatch(egg))
            stats.eggsHatched += 1
        }
    }
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

let arcs = MainArc.allCases
/// CASUAL=1: 1日4回(8/12/18/22時)だけアプリを開くプレイヤーを模擬。
/// 未設定: 発見した瞬間に戦う最適プレイ(理論上の最速)
let casual = ProcessInfo.processInfo.environment["CASUAL"] == "1"

func nextMainTarget() -> Dungeon? {
    DungeonCatalog.unlocked(mainProgress: data.mainProgress).first { $0.kind == .main }
}

/// 潜入先の選択: 進化が石不足で止まっているなら自属性の祠、そうでなければメイン
func nextTarget() -> Dungeon? {
    let chara = data.characters[mainCharIndex()]
    if chara.canEvolve {
        let cost = CharacterProgression.evolutionStoneCost(forStage: chara.stage)
        let element = chara.job().element
        if data.stoneCount(element) < cost,
           let shrine = DungeonCatalog.unlocked(mainProgress: data.mainProgress)
               .first(where: { $0.kind == .stone && $0.element == element }) {
            stats.shrineRuns += 1
            return shrine
        }
    }
    return nextMainTarget()
}

func manageScout() {
    guard !data.guild.scoutedToday, let visitor = data.guild.visitors.max(by: {
        (GachaCore.tier(ofJobID: $0.jobID)?.priority ?? 9) > (GachaCore.tier(ofJobID: $1.jobID)?.priority ?? 9)
    }) else { return }
    data.guild.scoutedToday = true
    let chance = data.guild.scoutChance(forJobID: visitor.jobID)
    if Double.random(in: 0..<1) < chance {
        data.guild.scoutFails.removeValue(forKey: visitor.jobID)
        let job = JobCatalog.job(id: visitor.jobID)
        var chara = PlayerCharacter(jobID: job.id)
        chara.placedSkills = Array(repeating: nil, count: job.slotCount)
        if job.category == .rare { chara.ultimate = JobCatalog.ultimate(for: job, stage: 1) }
        data.characters.append(chara)
        stats.scouted += 1
        if job.category == .rare { note("レアキャラ加入! \(job.name(atStage: 0))") }
    } else {
        data.guild.scoutFails[visitor.jobID, default: 0] += 1
    }
}

note("プレイ開始: \(data.characters[0].displayName) / モード=\(casual ? "カジュアル(1日4回)" : "最適プレイ")")

if casual {
    let checkHours: [Double] = [8, 12, 18, 22]
    while day() < maxDays {
        // 次のチェック時刻まで時間を送る
        let dayStart = floor(day())
        let hourNow = (day() - dayStart) * 24
        if let nextHour = checkHours.first(where: { $0 > hourNow + 0.01 }) {
            now = Date(timeIntervalSince1970: (dayStart * 24 + nextHour) * 3600)
        } else {
            now = Date(timeIntervalSince1970: ((dayStart + 1) * 24 + checkHours[0]) * 3600)
        }
        IdleEngine.process(&data, now: now)

        // チェック時の日課
        manageEggs()
        manageFusion()
        manageShop()
        manageScout()
        manageEvolution()
        manageEquipment()

        if let run = data.activeRun {
            if run.bossFound {
                if let foundAt = run.bossFoundAt {
                    stats.bossWaitHours.append(now.timeIntervalSince(foundAt) / 3600)
                }
                let dungeon = run.dungeon()
                let win = fightBoss(dungeon: dungeon)
                IdleEngine.settleRun(&data, bossDefeated: win)
                if win {
                    stats.mapClearDay[dungeon.id] = day()
                    stats.levelAtClear[dungeon.id] = data.characters[mainCharIndex()].level
                    if dungeon.mapIndex == MainArc.mapsPerArc {
                        note("★系統クリア: \(dungeon.name) Lv\(data.characters[mainCharIndex()].level)")
                    }
                }
                if let target = nextTarget() {
                    data.activeRun = DungeonRun(dungeonID: target.id, now: now)
                } else {
                    note("メイン全クリア!")
                    break
                }
            }
        } else if let target = nextTarget() {
            data.activeRun = DungeonRun(dungeonID: target.id, now: now)
        } else {
            note("メイン全クリア!")
            break
        }
    }
} else {
    outer: while day() < maxDays {
        guard let target = nextTarget() else {
            note("メイン全クリア!")
            break
        }
        data.activeRun = DungeonRun(dungeonID: target.id, now: now)

        var found = false
        while !found && day() < maxDays {
            now = now.addingTimeInterval(TimeInterval(tickMinutes * 60))
            IdleEngine.process(&data, now: now)
            manageEggs()
            manageFusion()
            manageShop()
            manageScout()
            manageEvolution()
            if data.activeRun?.bossFound == true { found = true }
        }
        guard found else { break }

        manageEquipment()

        let win = fightBoss(dungeon: target)
        IdleEngine.settleRun(&data, bossDefeated: win)
        if win {
            stats.mapClearDay[target.id] = day()
            stats.levelAtClear[target.id] = data.characters[mainCharIndex()].level
            if target.mapIndex == MainArc.mapsPerArc {
                note("★系統クリア: \(target.name) Lv\(data.characters[mainCharIndex()].level)")
            }
        }
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
if !stats.bossWaitHours.isEmpty {
    let avg = stats.bossWaitHours.reduce(0,+) / Double(stats.bossWaitHours.count)
    print("ボス発見→挑戦の平均待ち: \(String(format: "%.1f", avg))時間(自動探索は発見後5時間まで)")
}
print("スカウト成功: \(stats.scouted)人 / 祠に潜った回数: \(stats.shrineRuns)")
print("オトモ: \(data.otomos.count)体 合成\(stats.fusions)回 パーティ=\(data.partyOtomos.map { "\($0.displayName)\($0.rarity.stars)Lv\($0.level)" }.joined(separator: ","))")
let gradeCount = Dictionary(grouping: data.eggs, by: \.grade).mapValues(\.count)
print("卵在庫内訳: \(gradeCount.map { "\($0.key.label)×\($0.value)" }.sorted().joined(separator: " "))")
