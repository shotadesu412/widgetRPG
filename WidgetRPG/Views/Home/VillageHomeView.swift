import SwiftUI

/// ホームの村シーン(スケッチ準拠: 上=拠点テント、左下=ショップ、右下=ギルド、中央=編成キャラ)。
/// 建物は独立レイヤーで、状態によって見た目が変わる:
/// - ギルド: スカウトできる時だけ窓に人影が灯る(不可の時は暗く沈む)
/// - ショップ: 低確率(珍しい)商品の入荷中は金の輝きが出る
struct VillageHomeView: View {
    @EnvironmentObject private var game: GameViewModel
    let onTapTent: () -> Void
    let onTapShop: () -> Void
    let onTapGuild: () -> Void

    /// ギルドでいまスカウトできるか(来訪者がいて、本日分が残っている or チケットあり)
    private var guildScoutable: Bool {
        !game.data.guild.visitors.isEmpty
            && (!game.data.guild.scoutedToday || game.data.guildTickets > 0)
    }

    /// ショップに珍しい枠(低確率)の商品が入荷しているか
    private var shopHasRare: Bool {
        game.data.shop.items.contains { $0.tier == .lowChance }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w * 858 / 1024
            ZStack {
                Image("village_bg")
                    .resizable()
                    .interpolation(.none)
                    .frame(width: w, height: h)

                // 拠点テント(上・中央)
                building("village_tent", width: w * 0.42, glow: false, dimmed: false)
                    .position(x: w * 0.50, y: h * 0.38)
                    .onTapGesture(perform: onTapTent)

                // ショップ(左下)。珍しい入荷中は金の輝き
                building("village_shop", width: w * 0.32, glow: shopHasRare, dimmed: false)
                    .position(x: w * 0.19, y: h * 0.68)
                    .onTapGesture(perform: onTapShop)
                    .overlay(alignment: .topLeading) {
                        if shopHasRare {
                            badge("珍", color: Palette.accent)
                                .position(x: w * 0.19 + w * 0.10, y: h * 0.68 - w * 0.14)
                        }
                    }

                // ギルド(右下)。スカウト可能な時だけ窓の人影が灯る
                building("village_guild", width: w * 0.34, glow: false, dimmed: !guildScoutable)
                    .position(x: w * 0.81, y: h * 0.66)
                    .onTapGesture(perform: onTapGuild)
                    .overlay(alignment: .topTrailing) {
                        if guildScoutable {
                            badge("!", color: Palette.danger)
                                .position(x: w * 0.81 + w * 0.11, y: h * 0.66 - w * 0.13)
                        }
                    }

                // 編成中のメインキャラ+オトモ(道の合流点)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(game.data.partyCharacters) { chara in
                        CharacterSpriteView(spriteKey: chara.jobID, pixelSize: 3, height: 52)
                    }
                    ForEach(game.data.partyOtomos) { otomo in
                        CharacterSpriteView(spriteKey: otomo.speciesID, pixelSize: 3, height: 40)
                    }
                }
                .position(x: w * 0.50, y: h * 0.80)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(1024 / 858, contentMode: .fit)
    }

    /// 建物レイヤー(dimmed=閉店表現、glow=入荷の輝き)
    private func building(_ name: String, width: CGFloat, glow: Bool, dimmed: Bool) -> some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: width)
            .saturation(dimmed ? 0.45 : 1.0)
            .brightness(dimmed ? -0.13 : 0)
            .shadow(color: glow ? Palette.accent.opacity(0.75) : .clear, radius: glow ? 10 : 0)
            .contentShape(Rectangle())
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Circle().fill(color))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 2)
    }
}
