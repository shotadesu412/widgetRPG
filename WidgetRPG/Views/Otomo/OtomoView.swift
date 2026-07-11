import SwiftUI

/// オトモタブ: 卵とオトモの管理・詳細確認
struct OtomoView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    incubatorSection
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

    // MARK: - 孵化器(孵化は自動ではなく手動でセット)

    private var incubatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("孵化器")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            if let egg = game.data.incubatingEgg {
                HStack(spacing: 14) {
                    EggCrackView(crackStage: egg.crackStage(), size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(egg.grade.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(Palette.textPrimary)
                        Text(egg.statusText())
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                        // 孵化の具体的な残り時間は見せない(ひび割れで察する)
                        ProgressView(value: egg.progress())
                            .tint(Palette.accent)
                    }
                    Spacer()
                    if egg.isReady() {
                        Button {
                            game.hatch(egg)
                        } label: {
                            Text("迎える")
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Palette.accent))
                                .foregroundStyle(Palette.background)
                        }
                    }
                }
            } else {
                Text("卵をセットすると孵化が始まる")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    // MARK: - 持っている卵

    private var eggSection: some View {
        let waiting = game.data.eggs.filter { !$0.isIncubating }
        return VStack(alignment: .leading, spacing: 10) {
            Text("卵(\(waiting.count))")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            if waiting.isEmpty {
                Text("卵は持っていない。ダンジョンやショップで手に入る")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(waiting) { egg in
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
            EggCrackView(crackStage: 0, size: 56)
            Text(egg.grade.label)
                .font(.caption2.bold())
                .foregroundStyle(egg.grade == .legendary ? Palette.accent : Palette.textPrimary)
            Text(hatchHint)
                .font(.system(size: 9))
                .foregroundStyle(Palette.textSecondary)

            Button {
                game.startIncubation(egg)
            } label: {
                Text("セットする")
                    .font(.caption2.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(
                        game.data.incubatingEggID == nil ? Palette.accent : Palette.panelBorder))
                    .foregroundStyle(game.data.incubatingEggID == nil ? Palette.background : Palette.textSecondary)
            }
            .disabled(game.data.incubatingEggID != nil)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.background))
    }

    private var hatchHint: String {
        let hours = Int(egg.grade.hatchSeconds / 3600)
        return "孵化まで約\(hours)時間"
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
                // 個体値(±10%のブレ)。平均がプラスなら緑
                Text(ivText)
                    .font(.system(size: 9).monospaced())
                    .foregroundStyle(otomo.ivs.total >= 0 ? Palette.hpGreen : Palette.textSecondary)
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

    private var ivText: String {
        let iv = otomo.ivs
        func f(_ v: Int) -> String { v >= 0 ? "+\(v)" : "\(v)" }
        return "個体値 HP\(f(iv.hp)) 攻\(f(iv.attack)) 防\(f(iv.defense)) 速\(f(iv.speed)) 魔\(f(iv.magic))"
    }
}
