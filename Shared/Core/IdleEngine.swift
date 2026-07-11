import Foundation

/// 放置進行の計算。アプリ起動時・ウィジェット更新時に経過時間分をまとめて処理する
enum IdleEngine {

    static func process(_ data: inout SaveData, now: Date = Date()) {
        refreshShopIfNeeded(&data, now: now)
        refreshGuildIfNeeded(&data, now: now)
        processDungeonRun(&data, now: now)
        data.lastTick = now
    }

    // MARK: - ショップ(ランダムな時間に更新、6種類ランダムに並ぶ)

    private static func refreshShopIfNeeded(_ data: inout SaveData, now: Date) {
        guard now >= data.shop.nextRefresh else { return }
        data.shop.items = ItemFactory.randomShopItems(now: now)
        data.shop.nextRefresh = now.addingTimeInterval(TimeInterval(Int.random(in: 1800...7200)))
    }

    // MARK: - ギルド(毎日3人来訪)

    static func makeVisitors() -> [GuildVisitor] {
        let pool = JobCatalog.all.map(\.id)
        return (0..<3).compactMap { _ in pool.randomElement().map { GuildVisitor(jobID: $0) } }
    }

    private static func refreshGuildIfNeeded(_ data: inout SaveData, now: Date) {
        let today = Calendar.current.startOfDay(for: now)
        if data.guild.lastVisitDay != today {
            data.guild.visitors = makeVisitors()
            data.guild.lastVisitDay = today
            data.guild.scoutedToday = false
        }
    }

    // MARK: - ダンジョン進行(ボス捜索中も経験値・コイン・素材・装備・卵を自動収集)

    private static func processDungeonRun(_ data: inout SaveData, now: Date) {
        guard var run = data.activeRun else { return }
        let dungeon = run.dungeon()

        let elapsedMinutes = min(
            AppConstants.maxOfflineMinutes,
            Int(now.timeIntervalSince(run.lastProcessed) / 60)
        )
        guard elapsedMinutes > 0 else { return }

        let support = data.partySupportJobIDs
        let coinScale = support.contains("thief") ? 1.5 : 1.0
        let materialScale = support.contains("miner") ? 1.6 : 1.0
        let weaponScale = support.contains("explorer") ? 1.6 : 1.0
        let hatchScale = support.contains("monster_tamer") ? 0.7 : 1.0

        for minute in 1...elapsedMinutes {
            let tickDate = run.lastProcessed.addingTimeInterval(TimeInterval(minute * 60))

            // コインと経験値は毎分たまる
            run.collectedCoins += Int(Double(Int.random(in: 2...6) + dungeon.recommendedLevel / 2) * coinScale)
            run.collectedExp += Int.random(in: 4...10) + dungeon.recommendedLevel

            // 素材
            if Double.random(in: 0..<1) < 0.20 * materialScale {
                let amount = Int.random(in: 1...3)
                run.collectedMaterials += amount
                appendLog(&run, date: tickDate, message: "素材を\(amount)個拾った")
            }

            // 装備(装備ダンジョンは高確率)
            let equipChance = dungeon.kind == .equipment ? 0.15 : 0.03
            if Double.random(in: 0..<1) < equipChance * weaponScale {
                if Bool.random() {
                    let weapon = ItemFactory.randomWeapon()
                    data.weapons.append(weapon)
                    appendLog(&run, date: tickDate, message: "\(weapon.name)を発見した!")
                } else {
                    let armor = ItemFactory.randomArmor()
                    data.armors.append(armor)
                    appendLog(&run, date: tickDate, message: "\(armor.name)を発見した!")
                }
            }

            // 卵(卵ダンジョンは高確率。伝説の霊峰は伝説の卵も出る)
            let eggChance = dungeon.kind == .egg ? 0.08 : 0.01
            if Double.random(in: 0..<1) < eggChance {
                let egg = ItemFactory.randomEgg(
                    includeLegendary: dungeon.id == "egg_legendary",
                    hatchTimeScale: hatchScale,
                    now: tickDate
                )
                data.eggs.append(egg)
                appendLog(&run, date: tickDate, message: "卵を見つけた……何かが眠っている")
            }

            // ボス発見判定(確率、または一定時間経過で確実に発見)
            if !run.bossFound {
                let guaranteed: Bool
                if let limit = dungeon.guaranteedFindMinutes {
                    guaranteed = tickDate.timeIntervalSince(run.enteredAt) >= Double(limit) * 60
                } else {
                    guaranteed = false // カオスは青天井
                }
                if guaranteed || Double.random(in: 0..<1) < dungeon.bossFindChancePerMinute {
                    run.bossFound = true
                    run.bossFoundAt = tickDate
                    let boss = EnemyCatalog.enemy(id: dungeon.bossEnemyID)
                    appendLog(&run, date: tickDate, message: "\(boss.name)の気配を発見した!!")
                }
            }
            // 発見後も探索・収集は継続する
        }

        run.lastProcessed = run.lastProcessed.addingTimeInterval(TimeInterval(elapsedMinutes * 60))
        data.activeRun = run
    }

    private static func appendLog(_ run: inout DungeonRun, date: Date, message: String) {
        run.log.append(LootLogEntry(date: date, message: message))
        if run.log.count > 12 { run.log.removeFirst(run.log.count - 12) }
    }

    // MARK: - 帰還・攻略の精算

    /// 撤退またはボス討伐時に収集物を反映する
    static func settleRun(_ data: inout SaveData, bossDefeated: Bool) {
        guard let run = data.activeRun else { return }
        let dungeon = run.dungeon()

        data.coins += run.collectedCoins
        data.materials += run.collectedMaterials

        // 経験値をパーティに分配(トレーナー編成でアップ)
        let expScale = data.partySupportJobIDs.contains("trainer") ? 1.5 : 1.0
        let exp = Int(Double(run.collectedExp) * expScale)
        gainExp(&data, amount: exp)

        if bossDefeated {
            if dungeon.kind == .main, let arc = dungeon.arc, let map = dungeon.mapIndex {
                data.mainProgress[arc.rawValue] = max(data.mainProgress[arc.rawValue] ?? 0, map)
                // 最終ボス討伐で神話キャラの卵が確率ドロップ
                if map == MainArc.mapsPerArc, Double.random(in: 0..<1) < 0.3 {
                    let speciesID = mythicSpeciesID(for: arc)
                    if let speciesID {
                        data.eggs.append(Egg(speciesID: speciesID, rarity: .star3,
                                             obtainedAt: Date(), hatchSeconds: 86400))
                    }
                }
            }
        }
        data.activeRun = nil
    }

    private static func mythicSpeciesID(for arc: MainArc) -> String? {
        switch arc {
        case .cthulhu: "cthulhu"
        case .nyarlathotep: "nyarlathotep"
        case .azathoth: "azathoth"
        case .necronomicon: nil // ネクロノミコンは武器ドロップ(TODO)
        }
    }

    private static func gainExp(_ data: inout SaveData, amount: Int) {
        guard !data.partyCharacterIDs.isEmpty else { return }
        let each = amount / max(1, data.partyCharacterIDs.count)
        for id in data.partyCharacterIDs {
            guard let index = data.characters.firstIndex(where: { $0.id == id }) else { continue }
            data.characters[index].exp += each
            while data.characters[index].exp >= data.characters[index].expToNext {
                data.characters[index].exp -= data.characters[index].expToNext
                data.characters[index].level += 1
            }
        }
        // オトモにも分配(モンスターテイマー編成でアップ)
        let otomoScale = data.partySupportJobIDs.contains("monster_tamer") ? 1.5 : 1.0
        for id in data.partyOtomoIDs {
            guard let index = data.otomos.firstIndex(where: { $0.id == id }) else { continue }
            data.otomos[index].exp += Int(Double(each) * otomoScale)
            while data.otomos[index].exp >= data.otomos[index].expToNext {
                data.otomos[index].exp -= data.otomos[index].expToNext
                data.otomos[index].level += 1
            }
        }
    }
}
