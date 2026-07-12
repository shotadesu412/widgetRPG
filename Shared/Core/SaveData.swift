import Foundation

/// セーブデータ全体。App Group 経由で本体アプリとウィジェットが共有する
struct SaveData: Codable {
    var coins = 0
    var materials = 0
    /// 属性石(属性rawValue → 個数)。キャラの進化に使用
    var elementStones: [String: Int] = [:]
    /// ギルドチケット(その日のスカウトをもう一度)
    var guildTickets = 0
    var characters: [PlayerCharacter] = []
    var otomos: [Otomo] = []
    var eggs: [Egg] = []
    /// 孵化器にセット中の卵(孵化は自動ではなく手動でセット)
    var incubatingEggID: UUID?
    var weapons: [Weapon] = []
    var armors: [Armor] = []
    /// パーティ編成(キャラ最大3 + オトモ最大2)
    var partyCharacterIDs: [UUID] = []
    var partyOtomoIDs: [UUID] = []
    /// メインダンジョン進行度: 系統rawValue → 攻略済みマップ数
    var mainProgress: [String: Int] = [:]
    var activeRun: DungeonRun?
    var shop = ShopState()
    var guild = GuildState()
    var lastTick = Date()

    // MARK: - 参照ヘルパ

    func character(id: UUID?) -> PlayerCharacter? {
        guard let id else { return nil }
        return characters.first { $0.id == id }
    }

    func otomo(id: UUID?) -> Otomo? {
        guard let id else { return nil }
        return otomos.first { $0.id == id }
    }

    func weapon(id: UUID?) -> Weapon? {
        guard let id else { return nil }
        return weapons.first { $0.id == id }
    }

    func armor(id: UUID?) -> Armor? {
        guard let id else { return nil }
        return armors.first { $0.id == id }
    }

    var partyCharacters: [PlayerCharacter] { partyCharacterIDs.compactMap { character(id: $0) } }
    var partyOtomos: [Otomo] { partyOtomoIDs.compactMap { otomo(id: $0) } }

    var incubatingEgg: Egg? { eggs.first { $0.id == incubatingEggID } }

    func stoneCount(_ element: Element) -> Int { elementStones[element.rawValue] ?? 0 }

    /// 編成中の特殊支援キャラの職ID一覧(ダンジョン潜入時の特殊効果判定に使う)
    var partySupportJobIDs: Set<String> {
        Set(partyCharacters.filter { $0.job().category == .specialSupport }.map(\.jobID))
    }

    /// 装備込みの実効ステータス(武器は強化込み、防具は1個)
    func effectiveStats(of character: PlayerCharacter) -> BaseStats {
        var stats = character.grownStats
        if let w = weapon(id: character.weaponID) { stats = stats + w.upgradedBonus }
        if let a = armor(id: character.armorID) {
            stats = stats + a.bonus
            stats.speed = max(1, stats.speed - a.speedPenalty)
        }
        return stats
    }

    // MARK: - 新規ゲーム

    static func newGame(now: Date = Date()) -> SaveData {
        var data = SaveData()
        data.coins = 500
        data.lastTick = now

        // 初期キャラ: けんし
        let job = JobCatalog.job(id: "swordsman")
        var hero = PlayerCharacter(jobID: job.id)
        hero.learnedSkills = JobCatalog.starterSkills(for: job)
        hero.placedSkills = Array(repeating: nil, count: job.slotCount)
        hero.placedSkills[0] = hero.learnedSkills.first
        hero.ultimate = JobCatalog.starterUltimate(for: job)

        // 初期武器は剣種で生成する(スキルも剣のものになる)
        var weapon = ItemFactory.randomWeapon(rarity: .star1, type: .sword)
        weapon.name = "錆びた剣"
        hero.weaponID = weapon.id

        data.characters = [hero]
        data.weapons = [weapon]
        data.partyCharacterIDs = [hero.id]

        // 初期の卵と少量の素材・属性石
        data.eggs = [Egg(grade: .normal, obtainedAt: now)]
        data.materials = 20
        for element in Element.allCases { data.elementStones[element.rawValue] = 1 }

        data.shop.items = ItemFactory.randomShopItems(now: now)
        data.shop.nextRefresh = now.addingTimeInterval(TimeInterval(Int.random(in: 1800...7200)))
        data.guild.visitors = IdleEngine.makeVisitors()
        data.guild.lastVisitDay = Calendar.current.startOfDay(for: now)

        for arc in MainArc.allCases { data.mainProgress[arc.rawValue] = 0 }
        return data
    }
}
