import AppIntents
import WidgetKit

/// 「次へ」: ウィジェットの表示画面を順に切り替える
struct NextScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "次の画面へ"
    static let description = IntentDescription("ウィジェットの表示画面を切り替える")

    func perform() async throws -> some IntentResult {
        WidgetScreenStore.advance()
        return .result()
    }
}

/// 「更新」: 放置分の進行を反映して表示を更新する
struct RefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "画面を更新"
    static let description = IntentDescription("最新の状態に更新する")

    func perform() async throws -> some IntentResult {
        var data = GameStore.load()
        IdleEngine.process(&data)
        GameStore.save(data)
        return .result()
    }
}
