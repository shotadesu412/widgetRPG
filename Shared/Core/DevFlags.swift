import Foundation

/// 開発用フラグ。ゲームを走って検証するためのモード
enum DevFlags {
    /// 待ち時間ゼロ: ボス即発見・孵化即完了・ショップ常時更新・
    /// ギルド来訪即補充(スカウトし放題)・ゲリラ常時出現
    static var zeroWait: Bool {
        get { UserDefaults.standard.bool(forKey: "dev_zero_wait") }
        set { UserDefaults.standard.set(newValue, forKey: "dev_zero_wait") }
    }
}
