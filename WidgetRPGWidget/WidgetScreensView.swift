import SwiftUI
import WidgetKit

/// ウィジェットの共通レイアウト。
/// 上部: 時間帯・天候アイコン / 中央: 各画面 / 下部: 大きめの「更新」「次へ」ボタン
struct WidgetRootView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GameEntry

    var body: some View {
        VStack(spacing: 6) {
            header

            Group {
                switch entry.screen {
                case .egg: EggScreenView(entry: entry)
                case .dungeon: DungeonScreenView(entry: entry)
                case .base: BaseScreenView(entry: entry)
                case .shop: ShopScreenView(entry: entry)
                case .status: StatusScreenView(entry: entry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footerButtons
        }
    }

    private var header: some View {
        HStack {
            Text(entry.screen.label)
                .font(.caption.bold())
                .foregroundStyle(Palette.accent)
            Spacer()
            // 朝昼夜と天候(TODO: WeatherKitで実際の天気を反映)
            Image(systemName: TimeOfDay.current(entry.date).symbolName)
            Image(systemName: Weather.current(entry.date).symbolName)
        }
        .font(.caption2)
        .foregroundStyle(Palette.textSecondary)
    }

    private var footerButtons: some View {
        HStack(spacing: 8) {
            Button(intent: RefreshIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: family == .systemLarge ? 30 : 24)
            }
            .buttonStyle(.bordered)
            .tint(Palette.textSecondary)

            Button(intent: NextScreenIntent()) {
                Image(systemName: "arrow.right")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: family == .systemLarge ? 30 : 24)
            }
            .buttonStyle(.bordered)
            .tint(Palette.accent)
        }
    }
}

// MARK: - 卵の様子(時間は表示せず、ひび割れとログで知らせる)

struct EggScreenView: View {
    let entry: GameEntry

    var body: some View {
        if let egg = entry.data.eggs.first {
            HStack(spacing: 12) {
                EggCrackView(crackStage: egg.crackStage(now: entry.date), size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(egg.statusText(now: entry.date))
                        .font(.caption)
                        .foregroundStyle(Palette.textPrimary)
                    if entry.data.eggs.count > 1 {
                        Text("ほかに\(entry.data.eggs.count - 1)個の卵が眠っている")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
            }
        } else {
            Text("卵は持っていない")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - 攻略の様子(ボス捜索中/発見、取得アイテム)

struct DungeonScreenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GameEntry

    var body: some View {
        if let run = entry.data.activeRun {
            let dungeon = run.dungeon()
            VStack(alignment: .leading, spacing: 4) {
                Text(dungeon.name)
                    .font(.caption.bold())
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: 6) {
                    // キャラとオトモの攻略の様子
                    ForEach(entry.data.partyCharacters.prefix(3)) { chara in
                        CharacterSpriteView(spriteKey: chara.jobID, pixelSize: 2, animated: false)
                    }
                    ForEach(entry.data.partyOtomos.prefix(2)) { otomo in
                        CharacterSpriteView(spriteKey: otomo.speciesID, pixelSize: 2, animated: false)
                    }
                    Spacer()
                    Text(run.bossFound ? "ボス発見!!" : "ボス捜索中…")
                        .font(.caption2.bold())
                        .foregroundStyle(run.bossFound ? Palette.danger : Palette.textSecondary)
                }

                if family == .systemLarge {
                    ForEach(run.log.suffix(4).reversed()) { logEntry in
                        Text(logEntry.message)
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 10) {
                    Label("\(run.collectedCoins)", systemImage: "circle.circle.fill")
                    Label("\(run.collectedMaterials)", systemImage: "cube.fill")
                }
                .font(.caption2)
                .foregroundStyle(Palette.accent)
            }
        } else {
            Text("ダンジョンに潜入していない")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - 拠点の様子(時間限定ボスの通知)

struct BaseScreenView: View {
    let entry: GameEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(entry.data.partyCharacters.prefix(3)) { chara in
                    CharacterSpriteView(spriteKey: chara.jobID, pixelSize: 3, animated: false)
                }
                Spacer()
            }
            // TODO: 時間限定ボス・ゲリライベントの通知をここに出す
            Text("拠点は静かだ……時間限定ボスの気配はない")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - ショップ(見た目しか見えない。詳細はアプリを開く)

struct ShopScreenView: View {
    let entry: GameEntry

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(entry.data.shop.items) { item in
                Image(systemName: item.kind.symbolName)
                    .font(.callout)
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Palette.panel))
            }
        }
    }
}

// MARK: - ステータス一覧(ギルドカード風)

struct StatusScreenView: View {
    let entry: GameEntry

    var body: some View {
        let cleared = entry.data.mainProgress.values.reduce(0, +)
        let strongest = entry.data.characters.max { $0.level < $1.level }

        VStack(alignment: .leading, spacing: 4) {
            row("コイン", "\(entry.data.coins)")
            row("メイン攻略", "\(cleared) / \(MainArc.allCases.count * MainArc.mapsPerArc) 層")
            if let strongest {
                row("最強キャラ", "\(strongest.displayName) Lv\(strongest.level)")
            }
            row("オトモ", "\(entry.data.otomos.count)体 / 卵\(entry.data.eggs.count)個")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Palette.textPrimary)
        }
        .font(.caption2)
    }
}
