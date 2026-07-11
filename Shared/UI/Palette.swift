import SwiftUI

/// 暗めのダークファンタジー基調の配色(参考画像の紺+金)
enum Palette {
    static let background = Color(red: 0.08, green: 0.09, blue: 0.13)
    static let panel = Color(red: 0.13, green: 0.14, blue: 0.20)
    static let panelBorder = Color(red: 0.25, green: 0.26, blue: 0.34)
    static let accent = Color(red: 0.79, green: 0.66, blue: 0.42) // 見出しの金
    static let textPrimary = Color(red: 0.92, green: 0.91, blue: 0.88)
    static let textSecondary = Color(red: 0.62, green: 0.63, blue: 0.68)
    static let danger = Color(red: 0.85, green: 0.30, blue: 0.30)
    static let hpGreen = Color(red: 0.35, green: 0.75, blue: 0.40)

    static func elementColor(_ element: Element) -> Color {
        switch element {
        case .fire: Color(red: 0.90, green: 0.45, blue: 0.25)
        case .water: Color(red: 0.35, green: 0.60, blue: 0.90)
        case .electric: Color(red: 0.95, green: 0.85, blue: 0.35)
        case .dark: Color(red: 0.60, green: 0.45, blue: 0.85)
        case .wind: Color(red: 0.45, green: 0.80, blue: 0.60)
        }
    }

    /// 毒状態の表示色(紫)
    static let poison = Color(red: 0.66, green: 0.35, blue: 0.80)

    /// ATBゲージ: 行動に近づくほど緑→赤へ
    static func atbColor(progress: Double) -> Color {
        let p = min(max(progress, 0), 1)
        return Color(hue: 0.33 * (1.0 - p), saturation: 0.8, brightness: 0.85)
    }

    static func rarityColor(_ rarity: Rarity) -> Color {
        switch rarity {
        case .star1: Color(red: 0.65, green: 0.65, blue: 0.65)
        case .star2: Color(red: 0.55, green: 0.75, blue: 0.95)
        case .star3: accent
        }
    }
}

/// 枠付きのパネル(共通の見た目)
struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Palette.panelBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(PanelBackground())
    }
}
