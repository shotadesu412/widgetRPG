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
                    if let next = CharacterProgression.nextLevelReward(after: character.level) {
                        Text("次の習得: Lv\(next.level) \(next.label)")
                            .font(.caption2)
                            .foregroundStyle(Palette.accent)
                    }

                    if character.canEvolve {
                        // 進化コスト: 第一15個 / 第二30個。
                        // 通常キャラは自属性の石、特殊キャラはどの石でも合計で支払える
                        let cost = CharacterProgression.evolutionStoneCost(forStage: character.stage)
                        let stones = job.usesElementStone ? game.data.stoneCount(job.element) : game.data.totalStones
                        let stoneLabel = job.usesElementStone ? "\(job.element.label)の石" : "属性石(種類問わず)"
                        let affordable = stones >= cost
                        Button {
                            game.evolve(character)
                        } label: {
                            Text("進化する(\(stoneLabel)×\(cost) / 所持\(stones))")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(affordable ? Palette.accent : Palette.panelBorder))
                                .foregroundStyle(affordable ? Palette.background : Palette.textSecondary)
                        }
                        .disabled(!affordable)
                    } else if character.stage < job.maxStage,
                              let required = CharacterProgression.requiredEvolutionLevel(forStage: character.stage) {
                        Text("Lv\(required)で進化できる(必殺技を習得)")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .panelStyle()

                // キャラ自身のパッシブ(Lv30/60/80で習得)
                passivesSection(character)

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
                    HStack(alignment: .top) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Palette.panelBorder))

                        // スキル名の下に効果を記載する
                        VStack(alignment: .leading, spacing: 2) {
                            if let weaponSkill {
                                Label("\(weaponSkill.name)(武器)", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(Palette.accent)
                                Text(weaponSkill.effectText)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.textSecondary)
                            } else if let placed {
                                Text(placed.name)
                                    .font(.caption)
                                    .foregroundStyle(Palette.textPrimary)
                                Text(placed.effectText)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.textSecondary)
                            } else {
                                Text("空きスロット(通常攻撃)")
                                    .font(.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                Text(NormalAttackInfo.effectText)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.textSecondary)
                            }
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
                Text("必殺技: \(ultimate.name)(\(ultimate.kind.label)・威力\(ultimate.power)%・\(ultimate.requiredLoops)周)")
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
            } else if character.job().id == "slot_machine" {
                Text("必殺技なし(スロット一巡ごとにランダム効果)")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                Text("必殺技なし(Lv25の進化で習得)")
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

    // MARK: - パッシブ(Lv30/60/80で習得)

    private func passivesSection(_ character: PlayerCharacter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("パッシブ(Lv30/60/80で習得)")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            if character.passives.isEmpty {
                Text("なし")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(Array(character.passives.enumerated()), id: \.offset) { _, passive in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("\(passive.kind.label) +\(passive.value)%")
                                .font(.caption)
                                .foregroundStyle(Palette.textPrimary)
                            if let tier = passive.tier {
                                TierBadge(tier: tier)
                            }
                        }
                        Text(passive.kind.effectDescription)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    // MARK: - 装備(横4グリッド。タップで装備、長押しで詳細)

    private func equipmentSection(_ character: PlayerCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("装備")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            EquipmentGridView(targetCharacterID: character.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}
