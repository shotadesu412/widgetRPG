import SwiftUI

/// 村シーン(アプリのホームとウィジェットで共用)。
/// 背景の上に建物を独立レイヤーで重ね、ゲームの状態で見た目が変わる:
/// - ギルド: スカウトできる時だけ窓に人影が現れる(できない時は暗く沈む)
/// - ショップ: 珍しい(低確率)商品の入荷中は金の輝きが出る
///
/// 座標は元絵(1024×858)基準の割合で指定するので、どの大きさでも崩れない。
struct VillageSceneView: View {
    let data: SaveData
    /// 編成キャラを立たせるか(小さいウィジェットでは省く)
    var showsParty = true
    /// 状態バッジ(!・珍)を出すか
    var showsBadges = true
    /// 枠を埋めて余りをクリップする(false なら全体を収める)
    var fills = true
    /// クリップ時に画面中央へ持ってくるシーンの縦位置(0=空, 1=手前の地面)
    var focusY: CGFloat = 0.5
    /// 建物タップの処理(ウィジェットでは nil)
    var onTapTent: (() -> Void)?
    var onTapShop: (() -> Void)?
    var onTapGuild: (() -> Void)?

    static let sceneAspect: CGFloat = 1024.0 / 858.0

    /// ギルドでいまスカウトできるか(来訪者がいて、本日分が残っている or チケットあり)
    private var guildScoutable: Bool {
        !data.guild.visitors.isEmpty
            && (!data.guild.scoutedToday || data.guildTickets > 0)
    }

    /// ショップに珍しい枠(低確率)の商品が入荷しているか
    private var shopHasRare: Bool {
        data.shop.items.contains { $0.tier == .lowChance }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 元絵の比率を保ったまま拡縮(fills=枠を埋める / false=全体を収める)
            let scale = fills ? max(w / 1024, h / 858) : min(w / 1024, h / 858)
            let sw = 1024 * scale
            let sh = 858 * scale
            // focusY の位置が枠の中央に来るようにずらす(余白が出ない範囲に制限)
            let rawOffset = sh / 2 - sh * focusY
            let limit = max(0, (sh - h) / 2)
            let offsetY = min(max(rawOffset, -limit), limit)

            ZStack {
                Image("village_bg")
                    .resizable()
                    .interpolation(.none)
                    .frame(width: sw, height: sh)

                // 拠点テント(上・中央)
                building("village_tent", width: sw * 0.42)
                    .position(x: sw * 0.50, y: sh * 0.38)
                    .modifier(TapIfAvailable(action: onTapTent))

                // ショップ(左下)。珍しい入荷中は金の輝き
                building("village_shop", width: sw * 0.32, glow: shopHasRare)
                    .position(x: sw * 0.19, y: sh * 0.68)
                    .modifier(TapIfAvailable(action: onTapShop))

                // ギルド(右下)。スカウトできない時は暗く沈む
                ZStack {
                    building("village_guild", width: sw * 0.34, dimmed: !guildScoutable)
                    // 人影はスカウトできる時だけ重ねる(別レイヤー)
                    if guildScoutable {
                        Image("village_guild_people")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: sw * 0.34)
                    }
                }
                .position(x: sw * 0.81, y: sh * 0.66)
                .modifier(TapIfAvailable(action: onTapGuild))

                if showsBadges {
                    if shopHasRare {
                        badge("珍", color: Palette.accent)
                            .position(x: sw * 0.30, y: sh * 0.56)
                    }
                    if guildScoutable {
                        badge("!", color: Palette.danger)
                            .position(x: sw * 0.86, y: sh * 0.51)
                    }
                }

                // 編成中のメインキャラ+オトモ(道の合流点)
                if showsParty {
                    HStack(alignment: .bottom, spacing: sw * 0.012) {
                        ForEach(data.partyCharacters) { chara in
                            CharacterSpriteView(spriteKey: chara.jobID,
                                                pixelSize: 3, height: sh * 0.10, animated: false)
                        }
                        ForEach(data.partyOtomos) { otomo in
                            CharacterSpriteView(spriteKey: otomo.speciesID,
                                                pixelSize: 3, height: sh * 0.078, animated: false)
                        }
                    }
                    .position(x: sw * 0.50, y: sh * 0.81)
                }
            }
            .frame(width: sw, height: sh)
            .offset(y: offsetY)
            .frame(width: w, height: h)   // はみ出しは外枠でクリップ
            .clipped()
        }
    }

    private func building(_ name: String, width: CGFloat,
                          glow: Bool = false, dimmed: Bool = false) -> some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: width)
            .saturation(dimmed ? 0.45 : 1.0)
            .brightness(dimmed ? -0.13 : (glow ? 0.06 : 0))
            // 珍しい入荷は金色の光をまとわせて遠目でも気づけるようにする
            .shadow(color: glow ? Palette.accent.opacity(0.9) : .clear, radius: glow ? 14 : 0)
            .shadow(color: glow ? Palette.accent.opacity(0.5) : .clear, radius: glow ? 26 : 0)
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

/// タップ処理がある時だけ onTapGesture を付ける(ウィジェットでは付けない)
private struct TapIfAvailable: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}
