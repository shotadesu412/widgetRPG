import SwiftUI

/// ホーム: ショップ・ギルド・持ち物など他タブに属さないもの
struct HomeView: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var showInventory = false
    @State private var showDevBattle = false
    @State private var showDevGacha = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    resourceHeader
                    ShopSection()
                    GuildSection()
                    inventorySummary
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("拠点")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // 開発用ツール
                    Menu {
                        Button {
                            showDevBattle = true
                        } label: {
                            Label("戦闘バランス調整", systemImage: "bolt.fill")
                        }
                        Button {
                            showDevGacha = true
                        } label: {
                            Label("ガチャ検証", systemImage: "dice.fill")
                        }
                    } label: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                    }
                    .tint(Palette.accent)
                }
            }
            .sheet(isPresented: $showInventory) {
                InventoryView()
            }
            .fullScreenCover(isPresented: $showDevBattle) {
                DevBattleView()
                    .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: $showDevGacha) {
                DevGachaView()
            }
        }
    }

    private var resourceHeader: some View {
        HStack(spacing: 20) {
            Label("\(game.data.coins)", systemImage: "circle.circle.fill")
                .foregroundStyle(Palette.accent)
            Label("\(game.data.materials)", systemImage: "cube.fill")
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: TimeOfDay.current().symbolName)
                Image(systemName: Weather.current().symbolName)
            }
            .foregroundStyle(Palette.textSecondary)
        }
        .font(.subheadline.bold())
        .panelStyle()
    }

    private var inventorySummary: some View {
        Button {
            showInventory = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("持ち物")
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                    Text("武器 \(game.data.weapons.count) / 防具 \(game.data.armors.count) / 素材 \(game.data.materials)")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textSecondary)
            }
            .panelStyle()
        }
        .buttonStyle(.plain)
    }
}

/// ショップ: ランダムな時間に更新され、6種類の商品が並ぶ
struct ShopSection: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var selectedItem: ShopItem?

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ショップ")
                    .font(.headline)
                    .foregroundStyle(Palette.accent)
                Spacer()
                Text("次回入荷 \(game.data.shop.nextRefresh.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }

            if game.data.shop.items.isEmpty {
                Text("商品は売り切れた。次の入荷を待とう")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(game.data.shop.items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.kind.symbolName)
                                    .font(.title3)
                                    .foregroundStyle(tierColor(item.tier))
                                Text(item.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Text("\(item.price)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Palette.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(tierColor(item.tier),
                                                    lineWidth: item.tier == .basic ? 0 : 1)
                                    )
                            )
                            .overlay(alignment: .topTrailing) {
                                if item.tier != .basic {
                                    Text(item.tier.label)
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(tierColor(item.tier)))
                                        .foregroundStyle(Palette.background)
                                        .offset(x: -3, y: 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .panelStyle()
        .confirmationDialog(
            selectedItem.map { "\($0.name)(\($0.price)コイン)\n\($0.detail)" } ?? "",
            isPresented: Binding(get: { selectedItem != nil }, set: { if !$0 { selectedItem = nil } }),
            titleVisibility: .visible
        ) {
            if let item = selectedItem {
                Button("購入する") {
                    game.buy(item)
                    selectedItem = nil
                }
                .disabled(game.data.coins < item.price)
            }
            Button("やめる", role: .cancel) { selectedItem = nil }
        }
    }

    /// 陳列レア度の色(基本/やや珍しい/低確率)
    private func tierColor(_ tier: ShopTier) -> Color {
        switch tier {
        case .basic: Palette.accent
        case .uncommon: Color(red: 0.55, green: 0.75, blue: 0.95)
        case .lowChance: Color(red: 0.82, green: 0.55, blue: 0.84)
        }
    }
}

/// ギルド: 毎日3人来訪し、1人を選んで確率でスカウト
struct GuildSection: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var scoutResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ギルド")
                    .font(.headline)
                    .foregroundStyle(Palette.accent)
                Spacer()
                Text("成功率 \(Int(game.data.guild.scoutChance * 100))%")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }

            if game.data.guild.scoutedToday && game.data.guildTickets == 0 {
                Text("本日のスカウトは終了した。また明日、新たな来訪者が現れる")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                Text(game.data.guild.scoutedToday
                     ? "ギルドチケット(×\(game.data.guildTickets))でもう一度スカウトできる"
                     : "今日の来訪者から1人を選んでスカウトできる")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 10) {
                    ForEach(game.data.guild.visitors) { visitor in
                        let job = JobCatalog.job(id: visitor.jobID)
                        Button {
                            let success = game.scout(visitor)
                            scoutResult = success
                                ? "\(job.name(atStage: 0))が仲間に加わった!"
                                : "\(job.name(atStage: 0))は去っていった……(次回の成功率が上がった)"
                        } label: {
                            VStack(spacing: 6) {
                                CharacterSpriteView(spriteKey: job.id, pixelSize: 3)
                                Text(job.name(atStage: 0))
                                    .font(.caption2)
                                    .lineLimit(1)
                                Text(job.category.label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .panelStyle()
        .alert(scoutResult ?? "", isPresented: Binding(
            get: { scoutResult != nil }, set: { if !$0 { scoutResult = nil } }
        )) {
            Button("閉じる", role: .cancel) {}
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(GameViewModel())
        .preferredColorScheme(.dark)
}
