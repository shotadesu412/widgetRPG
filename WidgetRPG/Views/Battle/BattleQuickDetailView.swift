import SwiftUI

/// 戦闘中に見られる簡易詳細。
/// 上部タブで メインキャラ / オトモ を切り替え、
/// ステータス(バフ=緑・デバフ=赤)、スロット一覧(NEXT=次回スロット)、
/// 必殺技の周回進捗、装備(オトモは非表示)、パッシブ効果一覧を表示する。
struct BattleQuickDetailView: View {
    @ObservedObject var engine: BattleEngine
    @State var selectedID: UUID

    private var allies: [BattleEngine.Unit] { engine.allies }
    private var selected: BattleEngine.Unit? { allies.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 14) {
            // メインキャラ/オトモ切り替え(味方をタブで選択)
            Picker("対象", selection: $selectedID) {
                ForEach(allies) { unit in
                    Text(unit.isMainCharacter ? "メイン: \(unit.name)" : unit.name)
                        .tag(unit.id)
                }
            }
            .pickerStyle(.segmented)

            if let unit = selected {
                ScrollView {
                    content(unit)
                }
            } else {
                Spacer()
            }
        }
        .padding()
        .background(Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - 本体

    private func content(_ unit: BattleEngine.Unit) -> some View {
        VStack(spacing: 14) {
            // 名前+イラスト
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(unit.name)
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    ForEach(unit.ailmentList, id: \.self) { ailment in
                        Text(ailment.label)
                            .font(.system(size: 9).bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.poison))
                            .foregroundStyle(.white)
                    }
                }
                CharacterSpriteView(spriteKey: unit.spriteKey, state: unit.visualState, pixelSize: 5)
            }
            .frame(maxWidth: .infinity)
            .panelStyle()

            // ステータス(UPは緑、DOWNは赤で表示)
            statsSection(unit)

            // スロット一覧(NEXT=次回スロット)+必殺技
            slotsSection(unit)

            // 装備(オトモの場合は装備まわりの情報を表示しない)
            if unit.isMainCharacter {
                equipmentSection(unit)
            }

            // パッシブ効果一覧
            passiveSection(unit)
        }
    }

    // MARK: - ステータス

    private func statsSection(_ unit: BattleEngine.Unit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ステータス")
                .font(.caption.bold())
                .foregroundStyle(Palette.accent)
            statRow("HP", current: unit.hp, base: unit.maxHP, neutralJoin: " / ")
            statRow("攻撃", current: unit.effectiveAttackDisplay, base: unit.attack)
            statRow("防御", current: unit.effectiveDefense, base: unit.defense)
            statRow("素早さ", current: unit.effectiveSpeed, base: unit.speed)
            statRow("魔力", current: unit.magic, base: unit.magic)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    /// 実効値が基準より高ければ緑、低ければ赤で表示する
    private func statRow(_ label: String, current: Int, base: Int, neutralJoin: String? = nil) -> some View {
        let color: Color = neutralJoin != nil ? Palette.textPrimary
            : current > base ? Palette.hpGreen
            : current < base ? Palette.danger
            : Palette.textPrimary
        return HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            if let join = neutralJoin {
                Text("\(current)\(join)\(base)")
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(color)
            } else {
                Text("\(current)")
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(color)
                if current != base {
                    Text("(基準\(base))")
                        .font(.system(size: 9).monospaced())
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    // MARK: - スロット

    private func slotsSection(_ unit: BattleEngine.Unit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("スロット")
                .font(.caption.bold())
                .foregroundStyle(Palette.accent)
            ForEach(unit.slots.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text("S\(index + 1)")
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(index == unit.slotIndex ? Palette.accent : Palette.textSecondary)
                        .frame(width: 24, alignment: .leading)
                    Text(unit.slots[index].name)
                        .font(.caption)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    if index == unit.slotIndex {
                        // NEXT = 次回発動するスロット
                        Text("NEXT")
                            .font(.system(size: 9).bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.accent))
                            .foregroundStyle(Palette.background)
                    }
                }
            }
            if let ultimate = unit.ultimate {
                Divider().background(Palette.panelBorder)
                HStack {
                    Text("必殺技")
                        .font(.caption)
                        .foregroundStyle(Palette.danger)
                    Text(ultimate.name)
                        .font(.caption.bold())
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(min(unit.loops, unit.ultimateLoops))/\(unit.ultimateLoops)")
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(unit.ultimateReady ? Palette.danger : Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    // MARK: - 装備

    private func equipmentSection(_ unit: BattleEngine.Unit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("装備")
                .font(.caption.bold())
                .foregroundStyle(Palette.accent)
            equipmentRow(icon: unit.weaponInfo?.icon ?? "figure.fencing",
                         name: unit.weaponInfo?.name ?? "武器なし",
                         empty: unit.weaponInfo == nil)
            equipmentRow(icon: unit.armorInfo?.icon ?? "shield.fill",
                         name: unit.armorInfo?.name ?? "防具なし",
                         empty: unit.armorInfo == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func equipmentRow(icon: String, name: String, empty: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(empty ? Palette.textSecondary : Palette.accent)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(Palette.background))
            Text(name)
                .font(.caption)
                .foregroundStyle(empty ? Palette.textSecondary : Palette.textPrimary)
            Spacer()
        }
    }

    // MARK: - パッシブ

    private func passiveSection(_ unit: BattleEngine.Unit) -> some View {
        let labels = unit.passives.map(\.label) + unit.extraPassiveLabels
        return VStack(alignment: .leading, spacing: 6) {
            Text("パッシブ効果一覧")
                .font(.caption.bold())
                .foregroundStyle(Palette.accent)
            if labels.isEmpty {
                Text("なし")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(labels, id: \.self) { label in
                    HStack(spacing: 6) {
                        Circle().fill(Palette.accent).frame(width: 4, height: 4)
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}
