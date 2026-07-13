import SwiftUI

/// 装備一覧の種別切替
enum EquipCategory: String, CaseIterable, Identifiable {
    case weapon, armor
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weapon: "武器"
        case .armor: "防具"
        }
    }
}

/// 長押し詳細の表示対象(常に最新状態を参照できるようIDで持つ)
enum EquipmentSelection: Identifiable {
    case weapon(UUID)
    case armor(UUID)

    var id: UUID {
        switch self {
        case .weapon(let id), .armor(let id): id
        }
    }
}

/// 装備一覧グリッド(横4)。上部に武器/防具の切替ボタン。
/// タップで装備(装備中をタップで外す)、長押しで詳細シート。
struct EquipmentGridView: View {
    @EnvironmentObject private var game: GameViewModel
    /// 装備先(nil なら編成中のメインキャラ)
    var targetCharacterID: UUID?

    @State private var category: EquipCategory = .weapon
    @State private var detail: EquipmentSelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var target: PlayerCharacter? {
        if let targetCharacterID { return game.data.character(id: targetCharacterID) }
        return game.data.partyCharacters.first ?? game.data.characters.first
    }

    var body: some View {
        VStack(spacing: 10) {
            Picker("種別", selection: $category) {
                ForEach(EquipCategory.allCases) { c in
                    Text(c.label).tag(c)
                }
            }
            .pickerStyle(.segmented)

            if let target {
                Text("タップで\(target.displayName)に装備(装備中をタップで外す)/ 長押しで詳細")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            switch category {
            case .weapon:
                if game.data.weapons.isEmpty {
                    emptyText("武器")
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(game.data.weapons) { weapon in
                            EquipCard(
                                rarity: weapon.rarity,
                                icon: weapon.type.symbolName,
                                iconColor: weapon.element.map(Palette.elementColor) ?? Palette.textSecondary,
                                name: weapon.name,
                                equipped: target?.weaponID == weapon.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard let target else { return }
                                game.equipWeapon(target.weaponID == weapon.id ? nil : weapon, to: target)
                            }
                            .onLongPressGesture { detail = .weapon(weapon.id) }
                        }
                    }
                }
            case .armor:
                if game.data.armors.isEmpty {
                    emptyText("防具")
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(game.data.armors) { armor in
                            EquipCard(
                                rarity: armor.rarity,
                                icon: "shield.fill",
                                iconColor: Palette.textSecondary,
                                name: armor.name,
                                equipped: target?.armorID == armor.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard let target else { return }
                                game.equipArmor(target.armorID == armor.id ? nil : armor, to: target)
                            }
                            .onLongPressGesture { detail = .armor(armor.id) }
                        }
                    }
                }
            }
        }
        .sheet(item: $detail) { selection in
            EquipmentDetailSheet(selection: selection)
        }
    }

    private func emptyText(_ label: String) -> some View {
        Text("\(label)は持っていない")
            .font(.caption)
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
}

/// 抽選レアリティのバッジ(普通/やや珍しい/珍しい)
struct TierBadge: View {
    let tier: DrawTier

    private var color: Color {
        switch tier {
        case .common: Color(white: 0.45)
        case .uncommon: Color(red: 0.45, green: 0.65, blue: 0.90)
        case .rare: Palette.accent
        }
    }

    var body: some View {
        Text(tier.label)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color))
            .foregroundStyle(tier == .common ? Color.white : Palette.background)
    }
}

/// 装備カード(星の数をアイコンの上に表示)
struct EquipCard: View {
    let rarity: Rarity
    let icon: String
    let iconColor: Color
    let name: String
    var equipped = false

    var body: some View {
        VStack(spacing: 4) {
            StarsView(rarity: rarity)
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(height: 26)
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Palette.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(equipped ? Palette.accent : Palette.panelBorder,
                                lineWidth: equipped ? 1.5 : 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if equipped {
                Text("E")
                    .font(.system(size: 8, weight: .heavy))
                    .padding(3)
                    .background(Circle().fill(Palette.accent))
                    .foregroundStyle(Palette.background)
                    .offset(x: 3, y: -3)
            }
        }
    }
}

/// 長押しで出る装備の詳細シート(上昇値・強化・スキル/パッシブの中身)
struct EquipmentDetailSheet: View {
    @EnvironmentObject private var game: GameViewModel
    let selection: EquipmentSelection

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                switch selection {
                case .weapon(let id):
                    if let weapon = game.data.weapon(id: id) { weaponContent(weapon) }
                case .armor(let id):
                    if let armor = game.data.armor(id: id) { armorContent(armor) }
                }
            }
            .padding()
        }
        .background(Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - 武器

    private func weaponContent(_ weapon: Weapon) -> some View {
        VStack(spacing: 14) {
            header(icon: weapon.type.symbolName,
                   iconColor: weapon.element.map(Palette.elementColor) ?? Palette.textSecondary,
                   name: weapon.name, rarity: weapon.rarity,
                   sub: "\(weapon.type.label)(\(weapon.type.flavor))\(weapon.element.map { " / \($0.label)属性" } ?? "")")

            // 上昇ステータス
            section("上昇ステータス") {
                Text(weaponBonusText(weapon))
                    .font(.caption)
                    .foregroundStyle(Palette.hpGreen)
            }

            // 強化(武器はステータス上昇)
            section("強化") {
                UpgradeButton(
                    level: weapon.upgradeLevel,
                    canUpgrade: weapon.canUpgrade,
                    materials: game.data.materials
                ) {
                    game.upgradeWeapon(weapon)
                }
            }

            // スロットスキルの中身
            section("スロットスキル") {
                if weapon.skillPositions.isEmpty {
                    noneText
                } else {
                    ForEach(weapon.skillPositions.sorted(by: { $0.key < $1.key }), id: \.key) { pos, skill in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text("スロット\(pos + 1): \(skill.name)(\(skill.kind.label))")
                                    .font(.caption)
                                    .foregroundStyle(Palette.accent)
                                if let tier = skill.tier {
                                    TierBadge(tier: tier)
                                }
                            }
                            Text(skill.effectText)
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func weaponBonusText(_ weapon: Weapon) -> String {
        let b = weapon.upgradedBonus
        var parts: [String] = []
        if b.attack > 0 { parts.append("攻撃+\(b.attack)") }
        if b.magic > 0 { parts.append("魔力+\(b.magic)") }
        if b.speed > 0 { parts.append("素早さ+\(b.speed)") }
        if b.hp > 0 { parts.append("HP+\(b.hp)") }
        return parts.isEmpty ? "なし" : parts.joined(separator: " / ")
    }

    // MARK: - 防具

    private func armorContent(_ armor: Armor) -> some View {
        VStack(spacing: 14) {
            header(icon: "shield.fill", iconColor: Palette.textSecondary,
                   name: armor.name, rarity: armor.rarity,
                   sub: "\(armor.type.label) / 重量\(armor.weight)(素早さ-\(armor.speedPenalty))")

            section("上昇ステータス") {
                Text("防御+\(armor.bonus.defense) / HP+\(armor.bonus.hp)\(armor.bonus.magic > 0 ? " / 魔力+\(armor.bonus.magic)" : "")")
                    .font(.caption)
                    .foregroundStyle(Palette.hpGreen)
            }

            // 強化(防具はパッシブ解放)
            section("強化") {
                UpgradeButton(
                    level: armor.upgradeLevel,
                    canUpgrade: armor.canUpgrade,
                    materials: game.data.materials
                ) {
                    game.upgradeArmor(armor)
                }
            }

            section("パッシブスキル") {
                if armor.passives.isEmpty {
                    noneText
                } else {
                    ForEach(Array(armor.passives.enumerated()), id: \.offset) { index, passive in
                        let unlocked = index < armor.upgradeLevel
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                                    .font(.system(size: 9))
                                Text("\(passive.kind.label) +\(passive.value)%\(unlocked ? "" : "(強化\(index + 1)で解放)")")
                                if let tier = passive.tier {
                                    TierBadge(tier: tier)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(unlocked ? Palette.accent : Palette.textSecondary.opacity(0.7))
                            Text(passive.kind.effectDescription)
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.leading, 14)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - 部品

    private var noneText: some View {
        Text("なし")
            .font(.caption)
            .foregroundStyle(Palette.textSecondary)
    }

    private func header(icon: String, iconColor: Color, name: String, rarity: Rarity, sub: String) -> some View {
        VStack(spacing: 6) {
            StarsView(rarity: rarity)
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(iconColor)
            Text(name)
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text(sub)
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .panelStyle()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(Palette.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}
