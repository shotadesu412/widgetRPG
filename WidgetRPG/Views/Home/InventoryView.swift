import SwiftUI

/// 持ち物一覧(武器・防具・素材)
struct InventoryView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("武器") {
                    ForEach(game.data.weapons) { weapon in
                        WeaponRow(weapon: weapon)
                    }
                }
                Section("防具") {
                    ForEach(game.data.armors) { armor in
                        ArmorRow(armor: armor)
                    }
                }
                Section("素材") {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundStyle(Palette.textSecondary)
                        Text("強化素材")
                        Spacer()
                        Text("×\(game.data.materials)")
                            .foregroundStyle(Palette.textSecondary)
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
                Text("攻撃+\(weapon.bonus.attack)")
                if weapon.bonus.magic > 0 { Text("魔力+\(weapon.bonus.magic)") }
                if let element = weapon.element { Text(element.label) }
            }
            .font(.caption2)
            .foregroundStyle(Palette.textSecondary)
            // 武器スキル(スロット位置つき)
            ForEach(weapon.skillPositions.sorted(by: { $0.key < $1.key }), id: \.key) { pos, skill in
                Text("スロット\(pos + 1): \(skill.name)(\(skill.kind.label))")
                    .font(.caption2)
                    .foregroundStyle(Palette.accent)
            }
        }
        .listRowBackground(Palette.panel)
    }
}

struct ArmorRow: View {
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
            ForEach(armor.passives, id: \.self) { passive in
                Text("パッシブ: \(passive.kind.label) +\(passive.value)%")
                    .font(.caption2)
                    .foregroundStyle(Palette.accent)
            }
        }
        .listRowBackground(Palette.panel)
    }
}
