import SwiftUI

/// 村シーンの並べ方。画面の縦横比で建物の配置を変える
enum VillageLayout {
    /// アプリのホーム(縦長・全画面)
    case portrait
    /// ウィジェット(横長)
    case wide

    /// 背景はホームもウィジェットも同じ絵を使う
    var backgroundName: String { "village_bg_portrait" }

    /// 枠に対して背景のどこを見せるか。
    /// 横長で潰れた枠(中サイズのウィジェット)は地面側だけを見せ、
    /// ある程度の高さがあれば空も入れる
    func backgroundAlignment(width: CGFloat, height: CGFloat) -> Alignment {
        switch self {
        case .portrait: .center
        case .wide: height / max(1, width) < 0.7 ? .bottom : .center
        }
    }

    /// 建物の位置(枠に対する割合)と大きさ(枠の幅に対する割合)
    var tent: (x: CGFloat, y: CGFloat, w: CGFloat) {
        switch self {
        case .portrait: (0.50, 0.40, 0.46)
        case .wide: (0.50, 0.30, 0.30)
        }
    }
    var shop: (x: CGFloat, y: CGFloat, w: CGFloat) {
        switch self {
        case .portrait: (0.24, 0.63, 0.40)
        case .wide: (0.20, 0.62, 0.24)
        }
    }
    var guild: (x: CGFloat, y: CGFloat, w: CGFloat) {
        switch self {
        case .portrait: (0.77, 0.63, 0.42)
        case .wide: (0.80, 0.62, 0.26)
        }
    }
    /// 編成キャラの立ち位置
    var party: (x: CGFloat, y: CGFloat) {
        switch self {
        case .portrait: (0.50, 0.855)
        case .wide: (0.50, 0.86)
        }
    }
}

/// 村シーン(アプリのホームとウィジェットで共用)。
/// 背景の上に建物を独立レイヤーで重ね、ゲームの状態で見た目が変わる:
/// - ギルド: スカウトできる時だけ窓に人影が現れる(できない時は暗く沈む)
/// - ショップ: 珍しい(低確率)商品の入荷中は金の輝きが出る
///
/// 位置は「枠に対する割合」で決めるので、どんな大きさ・比率でも破綻しない。
struct VillageSceneView: View {
    let data: SaveData
    var layout: VillageLayout = .portrait
    /// 編成キャラを立たせるか
    var showsParty = true
    /// 状態バッジ(!・珍)を出すか
    var showsBadges = true
    /// キャラの高さ(枠の高さに対する割合)
    var partyHeightRatio: CGFloat = 0.15
    /// 建物タップの処理(ウィジェットでは nil)
    var onTapTent: (() -> Void)?
    var onTapShop: (() -> Void)?
    var onTapGuild: (() -> Void)?

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
            let charH = max(28, h * partyHeightRatio)

            ZStack {
                // 背景は枠いっぱいに敷き、はみ出しはクリップ
                Image(layout.backgroundName)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w, height: h,
                           alignment: layout.backgroundAlignment(width: w, height: h))
                    .clipped()

                // 拠点テント
                building("village_tent", width: w * layout.tent.w)
                    .position(x: w * layout.tent.x, y: h * layout.tent.y)
                    .modifier(TapIfAvailable(action: onTapTent))

                // ショップ。珍しい入荷中は金の輝き
                building("village_shop", width: w * layout.shop.w, glow: shopHasRare)
                    .position(x: w * layout.shop.x, y: h * layout.shop.y)
                    .modifier(TapIfAvailable(action: onTapShop))

                // ギルド。スカウトできない時は暗く沈み、人影も消える
                ZStack {
                    building("village_guild", width: w * layout.guild.w, dimmed: !guildScoutable)
                    if guildScoutable {
                        // 人影は建物と同じ丸め方なので必ず重なる
                        PixelArtImage(name: "village_guild_people", targetWidth: w * layout.guild.w)
                    }
                }
                .position(x: w * layout.guild.x, y: h * layout.guild.y)
                .modifier(TapIfAvailable(action: onTapGuild))

                // 建物の右上角にバッジを添える(建物の実寸から位置を出す)
                if showsBadges {
                    if shopHasRare {
                        let bw = w * layout.shop.w
                        badge("珍", color: Palette.accent)
                            .position(x: w * layout.shop.x + bw * 0.34,
                                      y: h * layout.shop.y - bw * 0.875 * 0.42)
                    }
                    if guildScoutable {
                        let bw = w * layout.guild.w
                        badge("!", color: Palette.danger)
                            .position(x: w * layout.guild.x + bw * 0.34,
                                      y: h * layout.guild.y - bw * 0.88 * 0.42)
                    }
                }

                // 編成中のメインキャラ+オトモ(手前に大きく立たせる)
                if showsParty {
                    HStack(alignment: .bottom, spacing: charH * 0.12) {
                        ForEach(data.partyCharacters) { chara in
                            CharacterSpriteView(spriteKey: chara.jobID,
                                                pixelSize: 4, height: charH, animated: false)
                        }
                        ForEach(data.partyOtomos) { otomo in
                            CharacterSpriteView(spriteKey: otomo.speciesID,
                                                pixelSize: 3, height: charH * 0.78, animated: false)
                        }
                    }
                    .position(x: w * layout.party.x, y: h * layout.party.y)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    private func building(_ name: String, width: CGFloat,
                          glow: Bool = false, dimmed: Bool = false) -> some View {
        // ドットが均一になる整数倍へ丸めて表示する
        PixelArtImage(name: name, targetWidth: width)
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
