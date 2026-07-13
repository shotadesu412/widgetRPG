import SwiftUI

/// オトモの正式な詳細画面(一覧タップで表示)。
/// 戦闘中の簡易詳細とは別で、進化ボタン・個体値・スキル詳細を確認できる。
struct OtomoDetailView: View {
    @EnvironmentObject private var game: GameViewModel
    let otomoID: UUID

    private var otomo: Otomo? { game.data.otomo(id: otomoID) }

    var body: some View {
        if let otomo {
            content(otomo)
        } else {
            Text("オトモが見つからない")
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func content(_ otomo: Otomo) -> some View {
        let species = otomo.species()
        let stats = otomo.grownStats

        return ScrollView {
            VStack(spacing: 16) {
                // 概要
                VStack(spacing: 8) {
                    CharacterSpriteView(spriteKey: species.id, pixelSize: 6)
                    HStack(spacing: 6) {
                        Text(otomo.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(Palette.accent)
                        StarsView(rarity: otomo.rarity)
                    }
                    Text("\(species.category.label) / \(species.element.label)属性 / スロット\(otomo.slotCount)")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text("Lv\(otomo.level)(次まで \(otomo.expToNext - otomo.exp))・進化 \(otomo.stage)/\(otomo.maxStage)")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)

                    Text("ステータス基準: 標準メインキャラの\(Int((otomo.statPercentOfMainCharacter * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)

                    if !species.canEvolve {
                        Text("この種は進化しない")
                            .font(.caption2)
                            .foregroundStyle(Palette.accent)
                    } else if otomo.canEvolve {
                        Button {
                            game.evolveOtomo(otomo)
                        } label: {
                            Text("進化する")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Palette.accent))
                                .foregroundStyle(Palette.background)
                        }
                    } else if otomo.stage < otomo.maxStage {
                        Text("Lv\((otomo.stage + 1) * 10)で進化できる")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .panelStyle()

                // 合成(同一種族・同一星を2体消費してレア度+1)
                if otomo.rarity < .star3 && species.canEvolve {
                    fusionSection(otomo)
                }

                // ステータス(個体値込み)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ステータス(個体値込み)")
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                    statRow("HP", stats.hp, iv: otomo.ivs.hp)
                    statRow("攻撃", stats.attack, iv: otomo.ivs.attack)
                    statRow("防御", stats.defense, iv: otomo.ivs.defense)
                    statRow("素早さ", stats.speed, iv: otomo.ivs.speed)
                    statRow("魔力", stats.magic, iv: otomo.ivs.magic)
                    HStack {
                        Text("個体値合計")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text(otomo.ivs.total >= 0 ? "+\(otomo.ivs.total)%" : "\(otomo.ivs.total)%")
                            .font(.caption.bold().monospaced())
                            .foregroundStyle(otomo.ivs.total >= 10 ? Palette.hpGreen : Palette.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panelStyle()

                // スキル詳細(スロット位置つき。空き位置は通常攻撃)
                VStack(alignment: .leading, spacing: 8) {
                    Text("スキルスロット")
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                    ForEach(0..<otomo.slotCount, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Palette.panelBorder))
                            if let skill = otomo.skillPositions[index] {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 5) {
                                        Text("\(skill.name)(\(skill.kind.label))")
                                            .font(.caption.bold())
                                            .foregroundStyle(Palette.textPrimary)
                                        if let tier = skill.tier {
                                            TierBadge(tier: tier)
                                        }
                                    }
                                    Text(skill.effectText)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Palette.textSecondary)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("空きスロット(通常攻撃)")
                                        .font(.caption)
                                        .foregroundStyle(Palette.textSecondary)
                                    Text(NormalAttackInfo.effectText)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Palette.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
                    }

                    if let ultimate = otomo.ultimate {
                        Text("必殺技: \(ultimate.name)(\(ultimate.kind.label)・威力\(ultimate.power)%・\(ultimate.requiredLoops)周)")
                            .font(.caption)
                            .foregroundStyle(Palette.danger)
                    } else {
                        Text("必殺技なし")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panelStyle()
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle(otomo.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 合成: 同一種族・同一星のオトモを2体消費してレア度を1上げる。
    /// スキルやパッシブは増えず、ステータス基準(メインキャラ比%)だけが上がる
    private func fusionSection(_ otomo: Otomo) -> some View {
        let materials = game.data.otomos.filter {
            $0.id != otomo.id && $0.speciesID == otomo.speciesID && $0.rarity == otomo.rarity
        }
        let ready = materials.count >= 2
        return VStack(alignment: .leading, spacing: 6) {
            Text("合成")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            Text("同じ種族・同じ星のオトモを2体消費してレア度を1上げる(スキルは変化しない)")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            HStack {
                Text("素材にできる同族: \(materials.count)体")
                    .font(.caption)
                    .foregroundStyle(ready ? Palette.textPrimary : Palette.textSecondary)
                Spacer()
                Button {
                    game.fuseOtomo(otomo)
                } label: {
                    Text("\(otomo.rarity.stars) → \(Rarity(rawValue: otomo.rarity.rawValue + 1)?.stars ?? "")に合成")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(ready ? Palette.accent : Palette.panelBorder))
                        .foregroundStyle(ready ? Palette.background : Palette.textSecondary)
                }
                .disabled(!ready)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func statRow(_ label: String, _ value: Int, iv: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.subheadline.monospaced())
                .foregroundStyle(Palette.textPrimary)
            Text(iv >= 0 ? "+\(iv)%" : "\(iv)%")
                .font(.system(size: 10).monospaced())
                .foregroundStyle(iv > 0 ? Palette.hpGreen : iv < 0 ? Palette.danger : Palette.textSecondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
