import Foundation

/// ウィジェットに表示する画面。下部の「次へ」ボタンで順に切り替える
enum WidgetScreen: Int, CaseIterable, Codable {
    case egg      // 卵の様子(時間は表示せず、ひび割れやログで知らせる)
    case dungeon  // 攻略の様子(ボス捜索中/発見、取得アイテム)
    case base     // 拠点の様子(時間限定ボスの通知)
    case shop     // ショップ(見た目のみ。詳細はアプリで)
    case status   // ステータス一覧(ギルドカード風)

    var label: String {
        switch self {
        case .egg: "卵"
        case .dungeon: "攻略"
        case .base: "拠点"
        case .shop: "ショップ"
        case .status: "ステータス"
        }
    }

    var next: WidgetScreen {
        WidgetScreen(rawValue: (rawValue + 1) % WidgetScreen.allCases.count) ?? .egg
    }
}

/// 現在表示中のウィジェット画面を App Group の UserDefaults に保持する
enum WidgetScreenStore {
    private static let key = "widgetScreen"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    static var current: WidgetScreen {
        get { WidgetScreen(rawValue: defaults.integer(forKey: key)) ?? .egg }
        set { defaults.set(newValue.rawValue, forKey: key) }
    }

    static func advance() {
        current = current.next
    }
}
