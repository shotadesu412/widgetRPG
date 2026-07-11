import SwiftUI

/// パーティ編成(キャラ最大3 + オトモ最大2)
struct PartyView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentParty
                    characterPicker
                    otomoPicker
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("パーティ")
        }
    }

    private var currentParty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("現在の編成")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            if game.data.partyCharacters.isEmpty && game.data.partyOtomos.isEmpty {
                Text("誰も編成されていない")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                HStack(spacing: 16) {
                    ForEach(game.data.partyCharacters) { chara in
                        VStack(spacing: 4) {
                            CharacterSpriteView(spriteKey: chara.jobID, pixelSize: 4)
                            Text(chara.displayName)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                    }
                    ForEach(game.data.partyOtomos) { otomo in
                        VStack(spacing: 4) {
                            CharacterSpriteView(spriteKey: otomo.speciesID, pixelSize: 4)
                            Text(otomo.displayName)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // 特殊支援キャラの効果表示
            let supports = game.data.partyCharacters.filter { $0.job().category == .specialSupport }
            if !supports.isEmpty {
                Divider().background(Palette.panelBorder)
                ForEach(supports) { chara in
                    Text("編成効果: \(chara.job().speciality)")
                        .font(.caption2)
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var characterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("キャラ(最大\(AppConstants.maxPartyCharacters)人)")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            ForEach(game.data.characters) { chara in
                let inParty = game.data.partyCharacterIDs.contains(chara.id)
                Button {
                    game.togglePartyCharacter(chara)
                } label: {
                    memberRow(
                        name: chara.displayName,
                        detail: "Lv\(chara.level) / \(chara.job().category.label)",
                        selected: inParty
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var otomoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("オトモ(最大\(AppConstants.maxPartyOtomos)体)")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            if game.data.otomos.isEmpty {
                Text("オトモがいない。卵を孵化させよう")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(game.data.otomos) { otomo in
                    let inParty = game.data.partyOtomoIDs.contains(otomo.id)
                    Button {
                        game.togglePartyOtomo(otomo)
                    } label: {
                        memberRow(
                            name: otomo.displayName,
                            detail: "Lv\(otomo.level) / \(otomo.species().category.label)",
                            selected: inParty
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func memberRow(name: String, detail: String, selected: Bool) -> some View {
        HStack {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
    }
}
