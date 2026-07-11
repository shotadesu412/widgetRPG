import SwiftUI

/// キャラ絵のアニメーション状態。1状態につき画像を複数枚差し込める。
///
/// 画像アセットの命名規則: `<spriteKey>_<state>_<frame>`
///   例) 剣士の待機2枚 → `swordsman_idle_0`, `swordsman_idle_1`
///       通常攻撃      → `swordsman_attackNormal_0`
///       スキル攻撃    → `swordsman_attackSkill_0`
///       被弾          → `swordsman_hurt_0`
///       戦闘不能      → `swordsman_down_0`
///       必殺(2枚)   → `swordsman_ultimate_0`, `swordsman_ultimate_1`
///
/// spriteKey は 職ID(swordsman 等)/ オトモ種族ID / 敵ID。
/// 画像が無い状態はコード描画のプレースホルダに自動フォールバックする。
enum SpriteState: String, CaseIterable {
    case idle          // 待機(2枚ループ)
    case attackNormal  // 通常攻撃(1枚)
    case attackSkill   // スキル攻撃(1枚)
    case hurt          // 被弾(1枚)
    case down          // 戦闘不能(1枚)
    case ultimate      // 必殺(1〜2枚)

    /// この状態で探しにいく最大枚数
    var frameCount: Int {
        switch self {
        case .idle, .ultimate: 2
        default: 1
        }
    }

    /// 待機のようにループ再生するか
    var loops: Bool { self == .idle }

    /// 1コマの表示時間(秒)
    var frameDuration: Double {
        switch self {
        case .idle: 0.5
        case .ultimate: 0.18
        default: 0.2
        }
    }

    /// 一時状態が自動で待機へ戻るまでの保持時間。idle / down は戻らない(nil)
    var holdDuration: Double? {
        switch self {
        case .idle, .down: nil
        case .ultimate: 0.6
        default: 0.35
        }
    }

    var label: String {
        switch self {
        case .idle: "待機"
        case .attackNormal: "通常攻撃"
        case .attackSkill: "スキル"
        case .hurt: "被弾"
        case .down: "戦闘不能"
        case .ultimate: "必殺"
        }
    }
}

/// 画像アセットの存在確認と解決。存在チェックは結果をキャッシュする。
enum SpriteAssets {
    private static var existenceCache: [String: Bool] = [:]

    static func imageName(_ key: String, _ state: SpriteState, frame: Int) -> String {
        "\(key)_\(state.rawValue)_\(frame)"
    }

    private static func exists(_ name: String) -> Bool {
        if let hit = existenceCache[name] { return hit }
        #if canImport(UIKit)
        let found = UIImage(named: name) != nil
        #else
        let found = false
        #endif
        existenceCache[name] = found
        return found
    }

    /// 指定状態で実在するフレーム画像名の配列。無ければ待機へ、それも無ければ空(=プレースホルダ)。
    static func frames(for key: String, state: SpriteState) -> [String] {
        let names = (0..<state.frameCount)
            .map { imageName(key, state, frame: $0) }
            .filter { exists($0) }
        if !names.isEmpty { return names }

        if state != .idle {
            let idle = (0..<SpriteState.idle.frameCount)
                .map { imageName(key, .idle, frame: $0) }
                .filter { exists($0) }
            if !idle.isEmpty { return idle }
        }
        return []
    }
}

/// キャラ絵の表示ビュー(アプリ・ウィジェット共用)。
/// 画像アセットがあれば状態に応じた絵を、無ければコード描画のドット絵を表示する。
struct CharacterSpriteView: View {
    let spriteKey: String
    var state: SpriteState = .idle
    /// プレースホルダのドット寸法。画像アセット時の高さの基準にもなる
    var pixelSize: CGFloat = 4
    /// 画像アセット表示時の高さ(nilなら pixelSize から概算)
    var height: CGFloat?
    /// 敵など左右反転して表示する
    var flipped = false
    /// ウィジェットなど、コマ送りアニメを止めたい場合は false
    var animated = true

    private var resolvedHeight: CGFloat { height ?? pixelSize * 12 }

    var body: some View {
        let frames = SpriteAssets.frames(for: spriteKey, state: state)
        content(frames: frames)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
    }

    @ViewBuilder
    private func content(frames: [String]) -> some View {
        if frames.isEmpty {
            PlaceholderSpriteView(spriteKey: spriteKey, state: state, pixelSize: pixelSize)
        } else if animated, frames.count > 1 {
            TimelineView(.periodic(from: .now, by: state.frameDuration)) { ctx in
                imageView(frames[frameIndex(at: ctx.date, count: frames.count)])
            }
        } else {
            imageView(frames[0])
        }
    }

    private func imageView(_ name: String) -> some View {
        Image(name)
            .interpolation(.none) // ドット絵をぼかさない
            .resizable()
            .scaledToFit()
            .frame(height: resolvedHeight)
    }

    private func frameIndex(at date: Date, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let step = Int(date.timeIntervalSinceReferenceDate / state.frameDuration)
        return ((step % count) + count) % count
    }
}

/// 画像アセットが無いときのコード描画。状態ごとに簡易な演出(移動・傾き・色・発光)を付ける。
struct PlaceholderSpriteView: View {
    let spriteKey: String
    var state: SpriteState = .idle
    var pixelSize: CGFloat = 4

    var body: some View {
        PixelSpriteView(spriteKey: spriteKey, pixelSize: pixelSize)
            .rotationEffect(.degrees(state == .down ? 90 : 0))
            .offset(x: offsetX, y: state == .down ? pixelSize * 2 : 0)
            .scaleEffect(state == .ultimate ? 1.15 : 1.0)
            .opacity(state == .down ? 0.4 : 1.0)
            .overlay {
                if state == .hurt {
                    Palette.danger.opacity(0.45).blendMode(.plusLighter)
                } else if state == .ultimate {
                    Palette.accent.opacity(0.35).blendMode(.plusLighter)
                }
            }
    }

    private var offsetX: CGFloat {
        switch state {
        case .attackNormal: pixelSize * 2
        case .attackSkill: pixelSize * 3
        case .hurt: -pixelSize * 1.5
        default: 0
        }
    }
}
