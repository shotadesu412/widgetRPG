import Foundation
import WidgetKit

/// アプリ全体の状態管理。SaveData を保持し、操作をまとめる
@MainActor
final class GameViewModel: ObservableObject {
    @Published var data: SaveData

    init() {
        var loaded = GameStore.load()
        IdleEngine.process(&loaded)
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

    /// 来訪者をスカウト。成功時は仲間に加わる。2回目以降はギルドチケットを消費
    @discardableResult
    func scout(_ visitor: GuildVisitor) -> Bool {
        if data.guild.scoutedToday {
            guard data.guildTickets > 0 else { return false }
            data.guildTickets -= 1
        }
        data.guild.scoutedToday = true

        let success = Double.random(in: 0..<1) < data.guild.scoutChance
        if success {
            data.guild.scoutFailCount = 0
            let job = JobCatalog.job(id: visitor.jobID)
            var chara = PlayerCharacter(jobID: job.id)
            chara.learnedSkills = JobCatalog.starterSkills(for: job)
            chara.placedSkills = Array(repeating: nil, count: job.slotCount)
            chara.placedSkills[0] = chara.learnedSkills.first
            chara.ultimate = JobCatalog.starterUltimate(for: job)
            data.characters.append(chara)
        } else {
            data.guild.scoutFailCount += 1
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

    /// 進化にはキャラの属性に対応した属性石を1つ消費する
    func evolve(_ character: PlayerCharacter) {
        let element = character.job().element
        guard character.canEvolve,
              data.stoneCount(element) > 0,
              let index = data.characters.firstIndex(where: { $0.id == character.id }) else { return }
        data.elementStones[element.rawValue, default: 1] -= 1
        data.characters[index].stage += 1
        // 進化でスキル・必殺技を習得
        let job = character.job()
        let newStage = data.characters[index].stage
        data.characters[index].learnedSkills.append(
            Skill(name: "\(job.name(atStage: newStage))の奥義", kind: .specialAttack,
                  power: 140 + newStage * 40, element: job.element)
        )
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

    func toggleArmor(_ armor: Armor, for character: PlayerCharacter) {
        guard let index = data.characters.firstIndex(where: { $0.id == character.id }) else { return }
        if let pos = data.characters[index].armorIDs.firstIndex(of: armor.id) {
            data.characters[index].armorIDs.remove(at: pos)
        } else {
            data.characters[index].armorIDs.append(armor.id)
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
