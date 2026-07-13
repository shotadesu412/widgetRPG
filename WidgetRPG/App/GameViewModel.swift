import Foundation
import WidgetKit

/// アプリ全体の状態管理。SaveData を保持し、操作をまとめる
@MainActor
final class GameViewModel: ObservableObject {
    @Published var data: SaveData

    init() {
        var loaded = GameStore.load()
        IdleEngine.process(&loaded)
        // 編成上限の変更(キャラ1人+オトモ2匹)に合わせて過剰分を外す
        loaded.partyCharacterIDs = Array(loaded.partyCharacterIDs.prefix(AppConstants.maxPartyCharacters))
        loaded.partyOtomoIDs = Array(loaded.partyOtomoIDs.prefix(AppConstants.maxPartyOtomos))
        data = loaded
    }

    func save() {
        GameStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 放置分の進行を反映(フォアグラウンド復帰時などに呼ぶ)
    func processIdle() {
        IdleEngine.process(&data)
        save()
    }

    // MARK: - ダンジョン

    func enterDungeon(_ dungeon: Dungeon) {
        guard data.activeRun == nil else { return }
        data.activeRun = DungeonRun(dungeonID: dungeon.id)
        save()
    }

    /// 撤退(収集物は持ち帰る)
    func retreat() {
        IdleEngine.settleRun(&data, bossDefeated: false)
        save()
    }

    /// ボス討伐でダンジョン攻略
    func completeRun(victory: Bool) {
        IdleEngine.settleRun(&data, bossDefeated: victory)
        save()
    }

    // MARK: - ショップ

    func buy(_ item: ShopItem) {
        guard data.coins >= item.price,
              let index = data.shop.items.firstIndex(where: { $0.id == item.id }) else { return }
        data.coins -= item.price
        data.shop.items.remove(at: index)

        switch item.kind {
        case .elementStone:
            if let element = item.element {
                data.elementStones[element.rawValue, default: 0] += item.amount
            }
        case .material:
            data.materials += item.amount
        case .coinPack:
            data.coins += Int.random(in: 50...300)
        case .egg:
            data.eggs.append(ItemFactory.makeEgg(grade: item.eggGrade ?? .normal))
        case .weapon:
            data.weapons.append(ItemFactory.randomWeapon(rarity: item.equipRarity))
        case .armor:
            data.armors.append(ItemFactory.randomArmor(rarity: item.equipRarity))
        case .guildTicket:
            data.guildTickets += 1
        }
        save()
    }

    // MARK: - 装備強化(防具はパッシブ解放、武器はステータス強化)

    func upgradeWeapon(_ weapon: Weapon) {
        guard let index = data.weapons.firstIndex(where: { $0.id == weapon.id }),
              weapon.canUpgrade else { return }
        let cost = EquipmentUpgrade.materialCost(toLevel: weapon.upgradeLevel + 1)
        guard data.materials >= cost else { return }
        data.materials -= cost
        data.weapons[index].upgradeLevel += 1
        save()
    }

    func upgradeArmor(_ armor: Armor) {
        guard let index = data.armors.firstIndex(where: { $0.id == armor.id }),
              armor.canUpgrade else { return }
        let cost = EquipmentUpgrade.materialCost(toLevel: armor.upgradeLevel + 1)
        guard data.materials >= cost else { return }
        data.materials -= cost
        data.armors[index].upgradeLevel += 1
        save()
    }

    // MARK: - ギルド(スカウト)

    /// 本日のスカウトが可能か(未実施、またはギルドチケット所持)
    var canScout: Bool { !data.guild.scoutedToday || data.guildTickets > 0 }

    /// 来訪者をスカウト。成功時は仲間に加わる。2回目以降はギルドチケットを消費。
    /// 成功率はキャラごと独立(ティア別初期値+失敗で上昇、成功でリセット)
    @discardableResult
    func scout(_ visitor: GuildVisitor) -> Bool {
        if data.guild.scoutedToday {
            guard data.guildTickets > 0 else { return false }
            data.guildTickets -= 1
        }
        data.guild.scoutedToday = true

        let success = Double.random(in: 0..<1) < data.guild.scoutChance(forJobID: visitor.jobID)
        if success {
            data.guild.scoutFails.removeValue(forKey: visitor.jobID)
            let job = JobCatalog.job(id: visitor.jobID)
            var chara = PlayerCharacter(jobID: job.id)
            chara.learnedSkills = JobCatalog.starterSkills(for: job)
            chara.placedSkills = Array(repeating: nil, count: job.slotCount)
            chara.placedSkills[0] = chara.learnedSkills.first
            // レア職は進化がないため、加入時から第一必殺技を持つ
            if job.category == .rare {
                chara.ultimate = JobCatalog.ultimate(for: job, stage: 1)
            }
            data.characters.append(chara)
        } else {
            data.guild.scoutFails[visitor.jobID, default: 0] += 1
        }
        save()
        return success
    }

    // MARK: - 卵・オトモ(孵化は自動ではなく手動でセット)

    /// 卵を孵化器にセットする(1個ずつ)。テイマー編成で孵化時間短縮
    func startIncubation(_ egg: Egg) {
        guard data.incubatingEggID == nil,
              let index = data.eggs.firstIndex(where: { $0.id == egg.id }) else { return }
        let hatchScale = data.partySupportJobIDs.contains("monster_tamer") ? 0.7 : 1.0
        data.eggs[index].incubationStartedAt = Date()
        data.eggs[index].hatchSeconds = egg.grade.hatchSeconds * hatchScale
        data.incubatingEggID = egg.id
        save()
    }

    /// 孵化が完了した卵からオトモを迎える
    func hatch(_ egg: Egg) {
        guard egg.isReady(),
              let index = data.eggs.firstIndex(where: { $0.id == egg.id }) else { return }
        data.eggs.remove(at: index)
        if data.incubatingEggID == egg.id { data.incubatingEggID = nil }
        data.otomos.append(ItemFactory.hatch(egg))
        save()
    }

    // MARK: - キャラ編集

    /// 進化(Lv25/45+属性石1個消費)。第一進化で第一必殺技、第二進化で第二必殺技を習得
    func evolve(_ character: PlayerCharacter) {
        guard CharacterProgression.evolve(&data, characterID: character.id) else { return }
        save()
    }

    /// オトモ合成: 同一種族・同一星のオトモを2体消費してレア度を1上げる。
    /// スキルやパッシブは増えず、ステータス基準(メインキャラ比%)だけが上がる
    func fuseOtomo(_ otomo: Otomo) {
        guard otomo.rarity < .star3, otomo.species().canEvolve,
              let index = data.otomos.firstIndex(where: { $0.id == otomo.id }) else { return }
        // 素材: 同一種族・同一星(自分以外)。編成外・個体値の低い順に消費
        let materials = data.otomos
            .filter { $0.id != otomo.id && $0.speciesID == otomo.speciesID && $0.rarity == otomo.rarity }
            .sorted {
                let aParty = data.partyOtomoIDs.contains($0.id) ? 1 : 0
                let bParty = data.partyOtomoIDs.contains($1.id) ? 1 : 0
                if aParty != bParty { return aParty < bParty }
                return $0.ivs.total < $1.ivs.total
            }
        guard materials.count >= 2 else { return }
        let consumed = materials.prefix(2).map(\.id)
        data.otomos.removeAll { consumed.contains($0.id) }
        data.partyOtomoIDs.removeAll { consumed.contains($0) }
        if let newIndex = data.otomos.firstIndex(where: { $0.id == otomo.id }) {
            data.otomos[newIndex].rarity = Rarity(rawValue: otomo.rarity.rawValue + 1) ?? .star3
        }
        save()
    }

    func setPlacedSkill(_ skill: Skill?, at slot: Int, for character: PlayerCharacter) {
        guard let index = data.characters.firstIndex(where: { $0.id == character.id }) else { return }
        var placed = data.characters[index].placedSkills
        let slotCount = character.job().slotCount
        if placed.count < slotCount {
            placed += Array(repeating: nil, count: slotCount - placed.count)
        }
        guard slot < placed.count else { return }
        placed[slot] = skill
        data.characters[index].placedSkills = placed
        save()
    }

    func equipWeapon(_ weapon: Weapon?, to character: PlayerCharacter) {
        guard let index = data.characters.firstIndex(where: { $0.id == character.id }) else { return }
        data.characters[index].weaponID = weapon?.id
        save()
    }

    /// 防具は1個のみ装備できる(nil で外す)
    func equipArmor(_ armor: Armor?, to character: PlayerCharacter) {
        guard let index = data.characters.firstIndex(where: { $0.id == character.id }) else { return }
        data.characters[index].armorID = armor?.id
        save()
    }

    /// オトモの進化(レベル条件のみ。進化で空きスロットにスキル習得)
    func evolveOtomo(_ otomo: Otomo) {
        guard otomo.canEvolve,
              let index = data.otomos.firstIndex(where: { $0.id == otomo.id }) else { return }
        data.otomos[index].stage += 1
        let species = otomo.species()
        // 空きスロットがあればプールから1つ抽選して習得
        if let slot = (0..<otomo.slotCount).first(where: { data.otomos[index].skillPositions[$0] == nil }),
           let entry = SkillCatalog.draw(from: SkillCatalog.otomoPool(for: species)) {
            data.otomos[index].skillPositions[slot] = entry.make(element: species.element)
        }
        save()
    }

    // MARK: - パーティ編成

    func togglePartyCharacter(_ character: PlayerCharacter) {
        if let index = data.partyCharacterIDs.firstIndex(of: character.id) {
            data.partyCharacterIDs.remove(at: index)
        } else if data.partyCharacterIDs.count < AppConstants.maxPartyCharacters {
            data.partyCharacterIDs.append(character.id)
        }
        save()
    }

    func togglePartyOtomo(_ otomo: Otomo) {
        if let index = data.partyOtomoIDs.firstIndex(of: otomo.id) {
            data.partyOtomoIDs.remove(at: index)
        } else if data.partyOtomoIDs.count < AppConstants.maxPartyOtomos {
            data.partyOtomoIDs.append(otomo.id)
        }
        save()
    }
}
