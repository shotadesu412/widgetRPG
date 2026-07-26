import SwiftUI

/// 開発用: ウィジェットの実寸で村シーンを確認する。
/// ギルドの人影(スカウト可否)とショップの輝き(珍しい入荷)を切り替えて見比べられる。
struct DevWidgetPreviewView: View {
    @EnvironmentObject private var game: GameViewModel
    @Environment(\.dismiss) private var dismiss

    // 初期状態は環境変数でも指定できる(スクショ比較用)
    @State private var scoutable = ProcessInfo.processInfo.environment["DEV_WIDGET_OFF"] != "1"
    @State private var rareStock = ProcessInfo.processInfo.environment["DEV_WIDGET_OFF"] != "1"

    /// iPhone のウィジェット実寸(中: 360×170 / 大: 360×380 くらい)
    private let mediumSize = CGSize(width: 360, height: 170)
    private let largeSize = CGSize(width: 360, height: 380)

    /// 表示検証用に状態を差し替えたセーブデータ
    private var mockData: SaveData {
        var d = game.data
        // ギルド: スカウト可否
        if scoutable {
            if d.guild.visitors.isEmpty {
                d.guild.visitors = IdleEngine.makeVisitors(ownedJobIDs: [])
            }
            d.guild.scoutedToday = false
        } else {
            d.guild.scoutedToday = true
            d.guildTickets = 0
        }
        // ショップ: 珍しい入荷の有無
        d.shop.items.removeAll { $0.tier == .lowChance }
        if rareStock {
            d.shop.items.append(
                ShopItem(tier: .lowChance, kind: .guildTicket,
                         name: "ギルドチケット", price: 500,
                         detail: "検証用")
            )
        }
        return d
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("ギルド: スカウトできる(人影が出る)", isOn: $scoutable)
                        Toggle("ショップ: 珍しい入荷がある(輝く)", isOn: $rareStock)
                    }
                    .tint(Palette.accent)
                    .font(.caption)
                    .panelStyle()

                    preview("中サイズ(systemMedium)", size: mediumSize, focusY: 0.30)
                    preview("大サイズ(systemLarge)", size: largeSize, focusY: 0.20)
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("ウィジェット確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.tint(Palette.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func preview(_ title: String, size: CGSize, focusY: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) \(Int(size.width))×\(Int(size.height))")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            VillageSceneView(data: mockData, layout: .wide, showsParty: true,
                             showsBadges: true, partyHeightRatio: focusY)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Palette.panelBorder, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
