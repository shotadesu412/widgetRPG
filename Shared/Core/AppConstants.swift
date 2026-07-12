import Foundation

enum AppConstants {
    /// App Group ID。実機で動かす際は Apple Developer 側で同名の App Group を登録すること。
    static let appGroupID = "group.com.shota.widgetrpg"
    static let saveFileName = "save.json"
    /// パーティ編成の上限(メインキャラ1人+オトモ2匹)
    static let maxPartyCharacters = 1
    static let maxPartyOtomos = 2
    /// 放置計算を遡る上限(分)
    static let maxOfflineMinutes = 720
}
