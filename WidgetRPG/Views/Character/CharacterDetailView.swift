import SwiftUI

/// キャラ詳細: ステータス・進化・スロット編集・装備
struct CharacterDetailView: View {
    @EnvironmentObject private var game: GameViewModel
    let characterID: UUID

    @State private var editingSlot: Int?

    private var character: PlayerCharacter? {
        game.data.character(id: characterID)
    }

    var body: some View {
        if let character {
            content(character)
        } else {
            Text("キャラクターが見つからない")
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func content(_ character: PlayerCharacter) -> some View {
        let job = character.job()
        let stats = game.data.effectiveStats(of: character)

        return ScrollView {
            VStack(spacing: 16) {
                // 概要と進化の系譜
                VStack(spacing: 8) {
                    CharacterSpriteView(spriteKey: job.id, pixelSize: 6)
                    Text(character.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Palette.accent)
                    Text(job.stageNames.joined(separator: " → "))
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    Text(job.speciality)
                        .font(.caption)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Lv\(character.level)(次まで \(character.expToNext - character.exp))")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)

                    if character.canEvolve {
                        Button {
                            game.evolve(character)
                        } label: {
                            Text("進化する")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Palette.accent))
                                .foregroundStyle(Palette.background)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .panelStyle()

                // ステータス
                VStack(alignment: .leading, spacing: 6) {
                    Text("ステータス(装備込み)")
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                    statRow("HP", stats.hp)
                    statRow("攻撃", stats.attack)
                    statRow("防御", stats.defense)
                    statRow("素早さ", stats.speed)
                    statRow("魔力", stats.magic)
                    HStack {
                        Text("属性")
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Label(job.element.label, systemImage: job.element.symbolName)
                            .foregroundStyle(Palette.elementColor(job.element))
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panelStyle()

                // スロット編集(武器スキル位置は固定、キャラスキルは好きな位置へ)
                slotEditor(character, job: job)

                // 装備
                equipmentSection(character)
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle(character.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text("\(value)")
                .foregroundStyle(Palette.textPrimary)
        }
        .font(.subheadline)
    }

    // MARK: - スロット

    private func slotEditor(_ character: PlayerCharacter, job: Job) -> some View {
        let weapon = game.data.weapon(id: character.weaponID)

        return VStack(alignment: .leading, spacing: 10) {
            Text("技スロット(3周で必殺技)")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            ForEach(0..<job.slotCount, id: \.self) { index in
                let weaponSkill = weapon?.skillPositions[index]
                let placed = character.placedSkills.indices.contains(index) ? character.placedSkills[index] : nil

                Button {
                    if weaponSkill == nil { editingSlot = index }
                } label: {
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Palette.panelBorder))

                        if let weaponSkill {
                            Label("\(weaponSkill.name)(武器)", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Palette.accent)
                        } else if let placed {
                            Text(placed.name)
                                .font(.caption)
                                .foregroundStyle(Palette.textPrimary)
                        } else {
                            Text("空きスロット(通常攻撃)")
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        if weaponSkill == nil {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
                }
                .buttonStyle(.plain)
            }

            if let ultimate = character.ultimate {
                Text("必殺技: \(ultimate.name)(\(ultimate.kind.label)・\(ultimate.requiredLoops)周)")
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
            } else {
                Text("必殺技なし(スロット一巡ごとにランダム効果)")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
        .confirmationDialog("スロットに配置するスキル", isPresented: Binding(
            get: { editingSlot != nil }, set: { if !$0 { editingSlot = nil } }
        ), titleVisibility: .visible) {
            if let slot = editingSlot {
                ForEach(character.learnedSkills) { skill in
                    Button("\(skill.name)(\(skill.kind.label))") {
                        game.setPlacedSkill(skill, at: slot, for: character)
                        editingSlot = nil
                    }
                }
                Button("空にする(通常攻撃)", role: .destructive) {
                    game.setPlacedSkill(nil, at: slot, for: character)
                    editingSlot = nil
                }
                Button("やめる", role: .cancel) { editingSlot = nil }
            }
        }
    }

    // MARK: - 装備

    private func equipmentSection(_ character: PlayerCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("装備")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            // 武器
            Menu {
                Button("外す") { game.equipWeapon(nil, to: character) }
                ForEach(game.data.weapons) { weapon in
                    Button("\(weapon.name) \(weapon.rarity.stars)") {
                        game.equipWeapon(weapon, to: character)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "sword.fill")
                        .foregroundStyle(Palette.accent)
                    Text(game.data.weapon(id: character.weaponID)?.name ?? "武器なし")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
            }

            // 防具(タップで着脱)
            Text("防具(重量が高いほど守りは固いが、素早さが下がる)")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            ForEach(game.data.armors) { armor in
                Button {
                    game.toggleArmor(armor, for: character)
                } label: {
                    HStack {
                        Image(systemName: character.armorIDs.contains(armor.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(character.armorIDs.contains(armor.id)
                                             ? Palette.accent : Palette.textSecondary)
                        Text("\(armor.name) \(armor.rarity.stars)")
                            .font(.caption)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text("重量\(armor.weight)")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}
