import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// ドット絵を「1ドット=整数個の画面ピクセル」で表示するビュー。
///
/// 半端な倍率で拡大すると、あるドットは4px・隣は5px…とバラつき、
/// 屋根や柱の直線がガタついて見える(ドット化の処理順とは無関係の表示側の問題)。
/// ここでは指定サイズに最も近い整数倍にスナップして、全ドットを同じ大きさに保つ。
struct PixelArtImage: View {
    let name: String
    /// 目安の幅(実際はこれに最も近い整数倍へ丸める)
    let targetWidth: CGFloat

    @Environment(\.displayScale) private var displayScale

    /// アセットの元の幅(px)
    private var sourceWidth: CGFloat {
        #if canImport(UIKit)
        UIImage(named: name)?.size.width ?? targetWidth
        #else
        targetWidth
        #endif
    }

    /// 1ドットあたりの画面ピクセル数を整数に丸めた表示幅
    var snappedWidth: CGFloat {
        let src = max(1, sourceWidth)
        let pixelsPerDot = max(1, (targetWidth * displayScale / src).rounded())
        return src * pixelsPerDot / displayScale
    }

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: snappedWidth)
    }
}

/// 指定サイズに最も近い「整数倍」の寸法を返す(スプライトの高さ合わせ用)
enum PixelSnap {
    static func size(source: CGFloat, target: CGFloat, displayScale: CGFloat) -> CGFloat {
        let src = max(1, source)
        let pixelsPerDot = max(1, (target * displayScale / src).rounded())
        return src * pixelsPerDot / displayScale
    }
}
