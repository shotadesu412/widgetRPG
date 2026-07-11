import SwiftUI

/// キャラタブ: キャラクターや装備の編集・強化・詳細確認
struct CharacterListView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(JobCategory.allCases, id: \.self) { category in
                    let charas = game.data.characters.filter { $0.job().category == category }
                    if !charas.isEmpty {
                        Section(category.label) {
                            ForEach(charas) { chara in
                                NavigationLink(value: chara.id) {
                                    CharacterRow(character: chara)
                                }
                                .listRowBackground(Palette.panel)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("キャラ")
            .navigationDestination(for: UUID.self) { id in
                if let chara = game.data.character(id: id) {
                    CharacterDetailView(characterID: chara.id)
                }
            }
        }
    }
}

struct CharacterRow: View {
    @EnvironmentObject private var game: GameViewModel
    let character: PlayerCharacter

    var body: some View {
        let job = character.job()
        HStack(spacing: 12) {
            CharacterSpriteView(spriteKey: job.id, pixelSize: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(character.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
                Text("Lv\(character.level) / \(job.element.label)属性 / スロット\(job.slotCount)")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            if character.canEvolve {
                Text("進化可")
                    .font(.system(size: 9).bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.accent))
                    .foregroundStyle(Palette.background)
            }
        }
    }
}
