import SwiftUI

/// 簡易ドット絵。文字列グリッドをピクセルとして描画するプレースホルダ。
/// TODO: 参考画像クオリティのピクセルアート画像アセットに差し替える。
enum PixelArt {

    /// 文字 → 色 のパレット
    static let colors: [Character: Color] = [
        "K": Color(red: 0.10, green: 0.10, blue: 0.12), // 輪郭
        "W": Color(red: 0.92, green: 0.92, blue: 0.90),
        "S": Color(red: 0.85, green: 0.70, blue: 0.55), // 肌
        "H": Color(red: 0.30, green: 0.55, blue: 0.30), // 緑(髪・体)
        "B": Color(red: 0.25, green: 0.35, blue: 0.65), // 青
        "R": Color(red: 0.75, green: 0.25, blue: 0.25), // 赤
        "G": Color(red: 0.55, green: 0.55, blue: 0.60), // 灰(金属)
        "Y": Color(red: 0.85, green: 0.75, blue: 0.35), // 金
        "P": Color(red: 0.55, green: 0.40, blue: 0.75), // 紫
        "D": Color(red: 0.35, green: 0.28, blue: 0.22), // 茶
        "L": Color(red: 0.55, green: 0.80, blue: 0.45), // 明るい緑
    ]

    /// spriteKey(職ID・種族ID・敵ID)に対応するドット絵。無いものは汎用シルエット
    static func sprite(for key: String) -> [String] {
        sprites[key] ?? fallback
    }

    static let sprites: [String: [String]] = [
        "swordsman": [
            "....KKK.....",
            "...KHHHK....",
            "...KSSSK....",
            "....KSK..G..",
            "...KBBBK.G..",
            "..KBBBBBKG..",
            "..S.BBB.KG..",
            "....BBB..Y..",
            "...KB.BK....",
            "...KD.DK....",
            "..KK...KK...",
        ],
        "slime": [
            "............",
            "....LLLL....",
            "...LLLLLL...",
            "..LLKLLKLL..",
            "..LLLLLLLL..",
            ".LLLLKKLLLL.",
            ".LLLLLLLLLL.",
            "..LLLLLLLL..",
            "............",
        ],
        "dragon": [
            "..R......R..",
            ".RRR....RRR.",
            ".RRRR..RRRR.",
            "..KRRRRRRK..",
            "...RRKRRR...",
            "..RRRRRRRR..",
            ".R.RRRRRR.R.",
            "...RR..RR...",
            "...K....K...",
        ],
        "cthulhu": [
            "...PPPPPP...",
            "..PPPPPPPP..",
            ".PPKPPPPKPP.",
            ".PPPPPPPPPP.",
            "..PPPPPPPP..",
            "..P.P.P.P...",
            "..P.P.P.P...",
            ".P..P..P..P.",
        ],
        "egg": [
            "....KKKK....",
            "...KWWWWK...",
            "..KWWWWWWK..",
            "..KWWWWWWK..",
            "..KWWWWWWK..",
            "...KWWWWK...",
            "....KKKK....",
        ],
    ]

    static let fallback: [String] = [
        "....KKKK....",
        "...KGGGGK...",
        "...KGGGGK...",
        "....KGGK....",
        "...KGGGGK...",
        "..KGGGGGGK..",
        "..KGGGGGGK..",
        "...KG..GK...",
        "...KK..KK...",
    ]
}

/// ドット絵を描画するビュー(アプリ・ウィジェット共用)
struct PixelSpriteView: View {
    let spriteKey: String
    var pixelSize: CGFloat = 4

    var body: some View {
        let grid = PixelArt.sprite(for: spriteKey)
        VStack(spacing: 0) {
            ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, char in
                        Rectangle()
                            .fill(PixelArt.colors[char] ?? .clear)
                            .frame(width: pixelSize, height: pixelSize)
                    }
                }
            }
        }
    }
}

/// ひび割れ段階つきの卵表示(ウィジェットの卵画面用)
struct EggCrackView: View {
    /// 0(無傷)〜3(孵化寸前)
    let crackStage: Int
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.93, green: 0.90, blue: 0.82),
                                 Color(red: 0.72, green: 0.68, blue: 0.58)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.8, height: size)

            // ひび割れを段階に応じて重ねる
            if crackStage >= 1 {
                CrackShape(seed: 1)
                    .stroke(Color(red: 0.25, green: 0.22, blue: 0.18), lineWidth: 1.5)
                    .frame(width: size * 0.8, height: size)
            }
            if crackStage >= 2 {
                CrackShape(seed: 2)
                    .stroke(Color(red: 0.25, green: 0.22, blue: 0.18), lineWidth: 1.5)
                    .frame(width: size * 0.8, height: size)
                    .rotationEffect(.degrees(120))
            }
            if crackStage >= 3 {
                CrackShape(seed: 3)
                    .stroke(Color(red: 0.15, green: 0.13, blue: 0.10), lineWidth: 2)
                    .frame(width: size * 0.8, height: size)
                    .rotationEffect(.degrees(-100))
            }
        }
    }
}

/// 稲妻状のひび割れ線
struct CrackShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let offsets: [CGFloat] = seed % 2 == 0
            ? [0.0, -0.08, 0.05, -0.04, 0.09]
            : [0.0, 0.07, -0.06, 0.08, -0.03]
        var x = rect.midX + CGFloat(seed - 2) * rect.width * 0.1
        var y = rect.minY + rect.height * 0.2
        path.move(to: CGPoint(x: x, y: y))
        for offset in offsets {
            x += offset * rect.width
            y += rect.height * 0.15
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

/// レア度の星表示
struct StarsView: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.stars)
            .font(.caption2)
            .foregroundStyle(Palette.rarityColor(rarity))
    }
}
