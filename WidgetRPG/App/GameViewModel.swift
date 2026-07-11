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
        case .egg:
            data.eggs.append(ItemFactory.randomEgg())
        case .weapon:
            data.weapons.append(ItemFactory.randomWeapon(rarityBias: 10))
        case .armor:
            data.armors.append(ItemFactory.randomArmor(rarityBias: 10))
        case .material:
            data.materials += Int.random(in: 3...8)
        case .coinPack:
            data.coins += Int.random(in: 50...300)
        }
        save()
    }

    // MARK: - ギルド(スカウト)

    /// 来訪者をスカウト。成功時は仲間に加わる
    @discardableResult
    func scout(_ visitor: GuildVisitor) -> Bool {
        guard !data.guild.scoutedToday else { return false }
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

    // MARK: - 卵・オトモ

    func hatch(_ egg: Egg) {
        guard egg.isReady(),
              let index = data.eggs.firstIndex(where: { $0.id == egg.id }) else { return }
        data.eggs.remove(at: index)
        data.otomos.append(ItemFactory.hatch(egg))
        save()
    }

    // MARK: - キャラ編集

    func evolve(_ character: PlayerCharacter) {
        guard character.canEvolve,
              let index = data.characters.firstIndex(where: { $0.id == character.id }) else { return }
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
