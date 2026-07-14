import SwiftUI

/// 開発用設定。ゲームを走って検証するためのモード切替と時間操作
struct DevSettingsView: View {
    @EnvironmentObject private var game: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var zeroWait = DevFlags.zeroWait

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 待ち時間ゼロ
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $zeroWait) {
                            Text("待ち時間ゼロモード")
                                .font(.headline)
                                .foregroundStyle(Palette.accent)
                        }
                        .tint(Palette.accent)
                        .onChange(of: zeroWait) { _, newValue in
                            DevFlags.zeroWait = newValue
                            game.processIdle()
                        }
                        Text("""
                        有効中は以下がすべて即時になる:
                        ・ダンジョンのボス発見(潜入した瞬間に発見)
                        ・卵の孵化(セットした瞬間に完了)
                        ・ショップの入荷(開くたびに更新)
                        ・ギルドの来訪(スカウトするたびに補充=回数無制限)
                        ・ゲリラクエストの出現(常に出現)
                        """)
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelStyle()

                    // 時間スキップ(経験値・コイン等の蓄積系はこちら)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("時間スキップ")
                            .font(.headline)
                            .foregroundStyle(Palette.accent)
                        Text("潜入中の収集(経験値・コイン・素材・ドロップ)を指定時間ぶん即時に進める。孵化・ショップ・ゲリラ期限にも作用する")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                        HStack(spacing: 10) {
                            skipButton(hours: 1)
                            skipButton(hours: 4)
                            skipButton(hours: 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelStyle()
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("デバッグ設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.tint(Palette.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func skipButton(hours: Double) -> some View {
        Button {
            game.debugSkip(hours: hours)
        } label: {
            Text("+\(Int(hours))時間")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.panel))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.accent, lineWidth: 1))
                .foregroundStyle(Palette.accent)
        }
    }
}
