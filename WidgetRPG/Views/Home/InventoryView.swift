import SwiftUI

/// 持ち物一覧(素材・属性石・装備)。
/// 装備は横4のカードグリッド(武器/防具切替、タップで装備、長押しで詳細)。
struct InventoryView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    itemsSection
                    stonesSection
                    equipmentSection
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("持ち物")
        }
        .preferredColorScheme(.dark)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("素材・アイテム")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            HStack {
                Image(systemName: "cube.fill")
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 24)
                Text("強化素材")
                    .font(.subheadline)
                Spacer()
                Text("×\(game.data.materials)")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Palette.accent)
                    .frame(width: 24)
                Text("ギルドチケット")
                    .font(.subheadline)
                Spacer()
                Text("×\(game.data.guildTickets)")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var stonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("属性石(キャラの進化に使用)")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            ForEach(Element.allCases) { element in
                HStack {
                    Image(systemName: element.symbolName)
                        .foregroundStyle(Palette.elementColor(element))
                        .frame(width: 24)
                    Text("\(element.label)の石")
                        .font(.subheadline)
                    Spacer()
                    Text("×\(game.data.stoneCount(element))")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("装備")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            EquipmentGridView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}

/// 装備強化ボタン(素材消費・最大3段階)。詳細シートから使用する
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
