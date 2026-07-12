import SwiftUI

/// 持ち物一覧(武器・防具・属性石・素材)。装備の強化もここで行う
struct InventoryView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("素材・アイテム") {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundStyle(Palette.textSecondary)
                        Text("強化素材")
                        Spacer()
                        Text("×\(game.data.materials)")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .listRowBackground(Palette.panel)
                    HStack {
                        Image(systemName: "ticket.fill")
                            .foregroundStyle(Palette.accent)
                        Text("ギルドチケット")
                        Spacer()
                        Text("×\(game.data.guildTickets)")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .listRowBackground(Palette.panel)
                }

                Section("属性石(キャラの進化に使用)") {
                    ForEach(Element.allCases) { element in
                        HStack {
                            Image(systemName: element.symbolName)
                                .foregroundStyle(Palette.elementColor(element))
                                .frame(width: 24)
                            Text("\(element.label)の石")
                            Spacer()
                            Text("×\(game.data.stoneCount(element))")
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .listRowBackground(Palette.panel)
                    }
                }

                Section("武器(強化でステータス上昇)") {
                    ForEach(game.data.weapons) { weapon in
                        WeaponRow(weapon: weapon)
                    }
                }
                Section("防具(強化でパッシブ解放)") {
                    ForEach(game.data.armors) { armor in
                        ArmorRow(armor: armor)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("持ち物")
        }
        .preferredColorScheme(.dark)
    }
}

struct WeaponRow: View {
    @EnvironmentObject private var game: GameViewModel
    let weapon: Weapon

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: weapon.type.symbolName)
                    .foregroundStyle(weapon.element.map(Palette.elementColor) ?? Palette.textSecondary)
                Text(weapon.name)
                    .font(.subheadline)
                Spacer()
                StarsView(rarity: weapon.rarity)
            }
            HStack(spacing: 8) {
                Text("\(weapon.type.label)(\(weapon.type.flavor))")
                Text("攻撃+\(weapon.upgradedBonus.attack)")
                if weapon.upgradedBonus.magic > 0 { Text("魔力+\(weapon.upgradedBonus.magic)") }
                if let element = weapon.element { Text(element.label) }
            }
            .font(.caption2)
            .foregroundStyle(Palette.textSecondary)
            // 武器スキル(スロット位置と効果の中身)
            ForEach(weapon.skillPositions.sorted(by: { $0.key < $1.key }), id: \.key) { pos, skill in
                VStack(alignment: .leading, spacing: 1) {
                    Text("スロット\(pos + 1): \(skill.name)(\(skill.kind.label))")
                        .font(.caption2)
                        .foregroundStyle(Palette.accent)
                    Text(skill.effectText)
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            UpgradeButton(
                level: weapon.upgradeLevel,
                canUpgrade: weapon.canUpgrade,
                materials: game.data.materials
            ) {
                game.upgradeWeapon(weapon)
            }
        }
        .listRowBackground(Palette.panel)
    }
}

struct ArmorRow: View {
    @EnvironmentObject private var game: GameViewModel
    let armor: Armor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundStyle(Palette.textSecondary)
                Text(armor.name)
                    .font(.subheadline)
                Spacer()
                StarsView(rarity: armor.rarity)
            }
            Text("防御+\(armor.bonus.defense) HP+\(armor.bonus.hp) 重量\(armor.weight)(素早さ-\(armor.speedPenalty))")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            // パッシブは星と同数付与され、強化で順に解放される(効果の説明つき)
            ForEach(Array(armor.passives.enumerated()), id: \.offset) { index, passive in
                let unlocked = index < armor.upgradeLevel
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 9))
                        Text("\(passive.kind.label) +\(passive.value)%")
                    }
                    .font(.caption2)
                    .foregroundStyle(unlocked ? Palette.accent : Palette.textSecondary.opacity(0.6))
                    Text(passive.kind.effectDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.leading, 14)
                }
            }
            UpgradeButton(
                level: armor.upgradeLevel,
                canUpgrade: armor.canUpgrade,
                materials: game.data.materials
            ) {
                game.upgradeArmor(armor)
            }
        }
        .listRowBackground(Palette.panel)
    }
}

/// 装備強化ボタン(素材消費・最大3段階)
struct UpgradeButton: View {
    let level: Int
    let canUpgrade: Bool
    let materials: Int
    let action: () -> Void

    var body: some View {
        let cost = EquipmentUpgrade.materialCost(toLevel: level + 1)
        let affordable = materials >= cost
        return HStack {
            Text("強化 \(level)/\(EquipmentUpgrade.maxLevel)")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            if canUpgrade {
                Button(action: action) {
                    Text("強化する(素材×\(cost))")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(affordable ? Palette.accent : Palette.panelBorder))
                        .foregroundStyle(affordable ? Palette.background : Palette.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!affordable)
            } else {
                Text("強化済み")
                    .font(.caption2)
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}
