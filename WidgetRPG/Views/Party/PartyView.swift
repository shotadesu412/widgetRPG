import SwiftUI

/// パーティ編成(メインキャラ1 + オトモ2)。
/// キャラ/オトモ一覧と同じ4列カードグリッド。
/// タップ=編成の出し入れ、長押し=詳細画面。
struct PartyView: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var detail: PartyDetail?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

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
            .sheet(item: $detail) { d in
                switch d {
                case .character(let id): CharacterDetailView(characterID: id)
                case .otomo(let id): OtomoDetailView(otomoID: id)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 現在の編成(大きめ表示)

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
                HStack(alignment: .top, spacing: 12) {
                    ForEach(game.data.partyCharacters) { chara in
                        currentMember(spriteKey: chara.jobID, name: chara.displayName,
                                      sub: "Lv\(chara.level)", isMain: true)
                    }
                    ForEach(game.data.partyOtomos) { otomo in
                        currentMember(spriteKey: otomo.speciesID, name: otomo.displayName,
                                      sub: "Lv\(otomo.level) \(otomo.rarity.stars)", isMain: false)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // 特殊支援キャラの編成効果
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

    private func currentMember(spriteKey: String, name: String, sub: String, isMain: Bool) -> some View {
        VStack(spacing: 4) {
            CharacterSpriteView(spriteKey: spriteKey, pixelSize: 6, height: 96)
                .frame(height: 96)
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - キャラ選択(4列グリッド)

    private var characterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("キャラ(最大\(AppConstants.maxPartyCharacters)人)")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            Text("タップで編成 / 長押しで詳細")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(game.data.characters) { chara in
                    PartyCard(
                        spriteKey: chara.jobID,
                        name: chara.displayName,
                        selected: game.data.partyCharacterIDs.contains(chara.id)
                    )
                    .onTapGesture { game.togglePartyCharacter(chara) }
                    .onLongPressGesture { detail = .character(chara.id) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    // MARK: - オトモ選択(4列グリッド)

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
                Text("タップで編成 / 長押しで詳細")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(game.data.otomos) { otomo in
                        PartyCard(
                            spriteKey: otomo.speciesID,
                            name: otomo.displayName,
                            rarity: otomo.rarity,
                            selected: game.data.partyOtomoIDs.contains(otomo.id)
                        )
                        .onTapGesture { game.togglePartyOtomo(otomo) }
                        .onLongPressGesture { detail = .otomo(otomo.id) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}

/// 編成カード(一覧のカードと同じ見た目+編成中バッジ)
private struct PartyCard: View {
    let spriteKey: String
    let name: String
    var rarity: Rarity? = nil
    let selected: Bool

    var body: some View {
        VStack(spacing: 5) {
            if let rarity { StarsView(rarity: rarity) }
            CharacterSpriteView(spriteKey: spriteKey, pixelSize: 4, height: 56)
                .frame(height: 56)
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Palette.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Palette.accent : Palette.panelBorder,
                                lineWidth: selected ? 2 : 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(4)
                    .background(Circle().fill(Palette.accent))
                    .foregroundStyle(Palette.background)
                    .offset(x: 3, y: -3)
            }
        }
        .contentShape(Rectangle())
    }
}

/// 詳細シートの対象
private enum PartyDetail: Identifiable {
    case character(UUID)
    case otomo(UUID)
    var id: UUID {
        switch self {
        case .character(let id), .otomo(let id): id
        }
    }
}
