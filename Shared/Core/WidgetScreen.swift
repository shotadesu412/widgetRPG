import Foundation

/// ウィジェットに表示する画面。下部の「次へ」ボタンで順に切り替える
enum WidgetScreen: Int, CaseIterable, Codable {
    case base     // 拠点(村シーン。ホームと同じ絵)。ウィジェットの顔なので先頭
    case egg      // 卵の様子(時間は表示せず、ひび割れやログで知らせる)
    case dungeon  // 攻略の様子(ボス捜索中/発見、取得アイテム)
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
        WidgetScreen(rawValue: (rawValue + 1) % WidgetScreen.allCases.count) ?? .base
    }
}

/// 現在表示中のウィジェット画面を App Group の UserDefaults に保持する
enum WidgetScreenStore {
    private static let key = "widgetScreen"
    /// 画面の並び順を変えた回数。増やすと保存済みの選択を先頭(村)に戻す
    private static let orderVersion = 3
    private static let versionKey = "widgetScreenOrderVersion"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    static var current: WidgetScreen {
        get {
            // 並び順を変えた直後は、前の番号が別の画面を指してしまうので村に戻す
            if defaults.integer(forKey: versionKey) != orderVersion {
                defaults.set(orderVersion, forKey: versionKey)
                defaults.set(WidgetScreen.base.rawValue, forKey: key)
                return .base
            }
            return WidgetScreen(rawValue: defaults.integer(forKey: key)) ?? .base
        }
        set { defaults.set(newValue.rawValue, forKey: key) }
    }

    static func advance() {
        current = current.next
    }
}
