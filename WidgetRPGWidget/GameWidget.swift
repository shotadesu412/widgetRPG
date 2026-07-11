import SwiftUI
import WidgetKit

struct GameEntry: TimelineEntry {
    let date: Date
    let data: SaveData
    let screen: WidgetScreen
}

/// 時間経過で自動更新(15分刻みでタイムラインを供給)+ ボタンでの手動更新
struct GameProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameEntry {
        GameEntry(date: Date(), data: SaveData.newGame(), screen: .egg)
    }

    func getSnapshot(in context: Context, completion: @escaping (GameEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameEntry>) -> Void) {
        // 表示前に放置分を進めて保存しておく
        var data = GameStore.load()
        IdleEngine.process(&data)
        GameStore.save(data)

        let now = Date()
        let screen = WidgetScreenStore.current
        let entries = (0..<4).map { offset in
            GameEntry(
                date: now.addingTimeInterval(TimeInterval(offset * 15 * 60)),
                data: data,
                screen: screen
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(for date: Date) -> GameEntry {
        GameEntry(date: date, data: GameStore.load(), screen: WidgetScreenStore.current)
    }
}

struct GameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GameWidget", provider: GameProvider()) { entry in
            WidgetRootView(entry: entry)
                .containerBackground(for: .widget) {
                    Palette.background
                }
        }
        .configurationDisplayName("ウィジェットRPG")
        .description("ホーム画面で冒険を見守る。卵・攻略・拠点・ショップ・ステータスを切り替え表示。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
