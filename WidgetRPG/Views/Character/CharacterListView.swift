import SwiftUI

/// キャラタブ: 一覧(イラスト+名前のカードグリッド)。
/// タップで正式な詳細画面(進化・スキル詳細・装備)へ。
struct CharacterListView: View {
    @EnvironmentObject private var game: GameViewModel

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
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
        }
    }
}

/// 一覧カード(イラスト+名前)
struct CharacterCard: View {
    let character: PlayerCharacter

    var body: some View {
        VStack(spacing: 6) {
            CharacterSpriteView(spriteKey: character.jobID, pixelSize: 4, height: 72)
                .frame(height: 72)
            Text(character.displayName)
                .font(.caption.bold())
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
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
