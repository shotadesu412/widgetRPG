import SwiftUI

/// キャラタブ: 一覧(イラスト+名前のカードグリッド)。
/// タップで正式な詳細画面(進化・スキル詳細・装備)へ。
struct CharacterListView: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var path: [UUID] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(JobCategory.allCases, id: \.self) { category in
                        let charas = game.data.characters.filter { $0.job().category == category }
                        if !charas.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.label)
                                    .font(.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(charas) { chara in
                                        NavigationLink(value: chara.id) {
                                            CharacterCard(character: chara)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("キャラ一覧")
            .navigationDestination(for: UUID.self) { id in
                if let chara = game.data.character(id: id) {
                    CharacterDetailView(characterID: chara.id)
                }
            }
            .onAppear {
                // 開発用: DEV_CHAR_DETAIL=1 で先頭キャラの詳細を自動表示(スクショ確認用)
                if ProcessInfo.processInfo.environment["DEV_CHAR_DETAIL"] == "1",
                   path.isEmpty, let first = game.data.characters.first {
                    path.append(first.id)
                }
            }
        }
    }
}

/// 一覧カード(イラスト+名前)
struct CharacterCard: View {
    let character: PlayerCharacter

    var body: some View {
        VStack(spacing: 5) {
            CharacterSpriteView(spriteKey: character.jobID, pixelSize: 4, height: 56)
                .frame(height: 56)
            Text(character.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Palette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.panelBorder, lineWidth: 1)
                )
        )
    }
}
