import SwiftUI

/// オトモタブ: 卵とオトモの管理・詳細確認
struct OtomoView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    eggSection
                    otomoSection
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("オトモ")
            .refreshable {
                game.processIdle()
            }
        }
    }

    // MARK: - 卵(孵化時間の数字は見せず、ひび割れと文章で伝える)

    private var eggSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("卵")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            if game.data.eggs.isEmpty {
                Text("卵は持っていない。卵ダンジョンやショップで手に入る")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(game.data.eggs) { egg in
                            EggCard(egg: egg)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var otomoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("オトモ一覧")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            if game.data.otomos.isEmpty {
                Text("まだオトモがいない。卵を孵化させよう")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(game.data.otomos) { otomo in
                    OtomoRow(otomo: otomo)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}

struct EggCard: View {
    @EnvironmentObject private var game: GameViewModel
    let egg: Egg

    var body: some View {
        VStack(spacing: 8) {
            EggCrackView(crackStage: egg.crackStage(), size: 56)
            Text(egg.statusText())
                .font(.system(size: 9))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(width: 100)
            StarsView(rarity: egg.rarity)

            if egg.isReady() {
                Button {
                    game.hatch(egg)
                } label: {
                    Text("孵化させる")
                        .font(.caption2.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accent))
                        .foregroundStyle(Palette.background)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.background))
    }
}

struct OtomoRow: View {
    let otomo: Otomo

    var body: some View {
        let species = otomo.species()
        HStack(spacing: 12) {
            CharacterSpriteView(spriteKey: species.id, pixelSize: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(otomo.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textPrimary)
                    StarsView(rarity: otomo.rarity)
                }
                Text("\(species.category.label) / Lv\(otomo.level) / \(species.element.label)属性")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
                if !species.canEvolve {
                    Text("この種は進化しない")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.accent)
                }
            }
            Spacer()
            Image(systemName: species.element.symbolName)
                .foregroundStyle(Palette.elementColor(species.element))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
    }
}
