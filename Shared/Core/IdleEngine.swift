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

    /// 来訪者3人を抽選する。出現率は 基本70% / 特殊25% / レア5%。
    /// 所持済みキャラは出現せず、その分の出現率は残りのキャラに再分配される(GachaCore)
    static func makeVisitors(ownedJobIDs: Set<String>) -> [GuildVisitor] {
        // 未所持がいなければ来訪なし
        guard GachaCore.roster.contains(where: { !ownedJobIDs.contains($0.id) }) else { return [] }
        var rng = SystemRandomNumberGenerator()
        return (0..<3).map { _ in
            GuildVisitor(jobID: GachaCore.drawVisitor(owned: ownedJobIDs, config: GachaConfig(), using: &rng).id)
        }
    }

    private static func refreshGuildIfNeeded(_ data: inout SaveData, now: Date) {
        let today = Calendar.current.startOfDay(for: now)
        if data.guild.lastVisitDay != today {
            data.guild.visitors = makeVisitors(ownedJobIDs: Set(data.characters.map(\.jobID)))
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
        let equipScale = support.contains("explorer") ? 1.6 : 1.0

        // 潜入からの通算分数(10分周期の判定に使う)
        let baseMinutes = Int(run.lastProcessed.timeIntervalSince(run.enteredAt) / 60)

        for minute in 1...elapsedMinutes {
            let tickDate = run.lastProcessed.addingTimeInterval(TimeInterval(minute * 60))

            // ボス発見後の自動探索は最大5時間まで。以降は収集が完全に止まる
            // (プレイヤーがボス戦を放置したまま経験値を稼ぎ続けられないようにする)
            if run.bossFound, let foundAt = run.bossFoundAt,
               tickDate.timeIntervalSince(foundAt) > 5 * 3600 {
                continue
            }

            // 経験値は毎分たまる(推奨レベル依存)。
            // ボス発見後は放置されないよう本来の30%に減少
            let baseExp = Int.random(in: 4...8) + dungeon.recommendedLevel * 2
            run.collectedExp += run.bossFound ? Int(Double(baseExp) * 0.3) : baseExp

            // アイテムは10分ごとに1回獲得
            if (baseMinutes + minute) % 10 == 0, dungeon.kind == .stone, let element = dungeon.element {
                // 属性石の祠: 石50% / コイン25% / 素材15% / 装備10%(卵は出ない)
                let roll = Double.random(in: 0..<100)
                if roll < 50 {
                    let amount = Int.random(in: 1...2)
                    data.elementStones[element.rawValue, default: 0] += amount
                    appendLog(&run, date: tickDate, message: "\(element.label)の石を\(amount)個見つけた!")
                } else if roll < 75 {
                    let amount = Int(Double(Int.random(in: 10...20) + dungeon.recommendedLevel * 3) * coinScale)
                    run.collectedCoins += amount
                    appendLog(&run, date: tickDate, message: "コインを\(amount)枚拾った")
                } else if roll < 90 {
                    let amount = Int(Double(Int.random(in: 1...3) + dungeon.recommendedLevel / 4) * materialScale)
                    run.collectedMaterials += amount
                    appendLog(&run, date: tickDate, message: "素材を\(amount)個拾った")
                } else {
                    let weapon = ItemFactory.randomWeapon()
                    data.weapons.append(weapon)
                    appendLog(&run, date: tickDate, message: "\(weapon.name)\(weapon.rarity.stars)を発見した!")
                }
            } else if (baseMinutes + minute) % 10 == 0 {
                // 通常の獲得率: 素材40% / コイン43% / 装備10% / 卵7%
                let roll = Double.random(in: 0..<100)
                if roll < 40 {
                    // 素材(潜っているダンジョンが後半ほど量が増える)
                    let amount = Int(Double(Int.random(in: 1...3) + dungeon.recommendedLevel / 4) * materialScale)
                    run.collectedMaterials += amount
                    appendLog(&run, date: tickDate, message: "素材を\(amount)個拾った")
                } else if roll < 83 {
                    // コイン(潜っているダンジョンが後半ほど量が増える)
                    let amount = Int(Double(Int.random(in: 10...20) + dungeon.recommendedLevel * 3) * coinScale)
                    run.collectedCoins += amount
                    appendLog(&run, date: tickDate, message: "コインを\(amount)枚拾った")
                } else if roll < 83 + 10 * equipScale {
                    // 装備(星1 80% / 星2 17% / 星3 3%)
                    if Bool.random() {
                        let weapon = ItemFactory.randomWeapon()
                        data.weapons.append(weapon)
                        appendLog(&run, date: tickDate, message: "\(weapon.name)\(weapon.rarity.stars)を発見した!")
                    } else {
                        let armor = ItemFactory.randomArmor()
                        data.armors.append(armor)
                        appendLog(&run, date: tickDate, message: "\(armor.name)\(armor.rarity.stars)を発見した!")
                    }
                } else {
                    // 卵(普通80% / 珍しい17% / 伝説3%)
                    let egg = ItemFactory.makeEgg(grade: ItemFactory.rollEggGrade(), now: tickDate)
                    data.eggs.append(egg)
                    appendLog(&run, date: tickDate, message: "\(egg.grade.label)を見つけた……何かが眠っている")
                }
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

        // モンスターテイマーを編成して潜入中は、珍しい/伝説の卵の孵化が2倍速で進む
        // (潜入1分ごとに残り孵化時間を追加で1分減らす)
        if data.partySupportJobIDs.contains("monster_tamer"),
           let eggID = data.incubatingEggID,
           let index = data.eggs.firstIndex(where: { $0.id == eggID }),
           data.eggs[index].grade != .normal {
            data.eggs[index].hatchSeconds = max(0, data.eggs[index].hatchSeconds - Double(elapsedMinutes * 60))
        }
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
                // 最終ボス討伐で神話キャラの卵が確率ドロップ(中身確定の伝説の卵)
                if map == MainArc.mapsPerArc, Double.random(in: 0..<1) < 0.3,
                   let speciesID = mythicSpeciesID(for: arc) {
                    data.eggs.append(ItemFactory.makeEgg(grade: .legendary, fixedSpeciesID: speciesID))
                }
                // ルルイエ海淵クリア報酬: モンスターテイマーが確定加入
                if arc == .cthulhu, map == MainArc.mapsPerArc,
                   !data.characters.contains(where: { $0.jobID == "monster_tamer" }) {
                    let job = JobCatalog.job(id: "monster_tamer")
                    var tamer = PlayerCharacter(jobID: job.id)
                    tamer.learnedSkills = JobCatalog.starterSkills(for: job)
                    tamer.placedSkills = Array(repeating: nil, count: job.slotCount)
                    tamer.placedSkills[0] = tamer.learnedSkills.first
                    data.characters.append(tamer)
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
                // 習得テーブル(Lv10/70スキル、Lv30/60/80パッシブ)
                CharacterProgression.grantLevelRewards(
                    &data.characters[index], reachedLevel: data.characters[index].level)
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
