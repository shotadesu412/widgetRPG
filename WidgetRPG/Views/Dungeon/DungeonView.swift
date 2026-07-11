import SwiftUI

/// ダンジョンタブ。潜入中は攻略の様子、それ以外は一覧を表示
struct DungeonView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            Group {
                if game.data.activeRun != nil {
                    ActiveRunView()
                } else {
                    DungeonListView()
                }
            }
            .background(Palette.background)
            .navigationTitle("ダンジョン")
        }
    }
}

/// 挑戦可能なダンジョン一覧(メイン進行度で解禁が増える)
struct DungeonListView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        let unlocked = DungeonCatalog.unlocked(mainProgress: game.data.mainProgress)
        List {
            ForEach(DungeonKind.allCases) { kind in
                let dungeons = unlocked.filter { $0.kind == kind }
                if !dungeons.isEmpty {
                    Section(kind.label) {
                        ForEach(dungeons) { dungeon in
                            DungeonRow(dungeon: dungeon)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct DungeonRow: View {
    @EnvironmentObject private var game: GameViewModel
    let dungeon: Dungeon

    var body: some View {
        Button {
            game.enterDungeon(dungeon)
        } label: {
            HStack {
                Image(systemName: dungeon.kind.symbolName)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dungeon.name)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Text("潜入")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.accent)
            }
        }
        .listRowBackground(Palette.panel)
    }

    private var subtitle: String {
        var parts = ["推奨Lv\(dungeon.recommendedLevel)"]
        if let minutes = dungeon.guaranteedFindMinutes {
            parts.append("\(minutes)分以内にボス発見")
        } else {
            parts.append("エンドレス(発見時間は青天井)")
        }
        return parts.joined(separator: " / ")
    }
}

/// 潜入中の攻略の様子。基本は放置してウィジェットで見守る
struct ActiveRunView: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var showBattle = false

    var body: some View {
        guard let run = game.data.activeRun else {
            return AnyView(EmptyView())
        }
        let dungeon = run.dungeon()

        return AnyView(
            ScrollView {
                VStack(spacing: 16) {
                    // 状況ヘッダ
                    VStack(spacing: 8) {
                        Text(dungeon.name)
                            .font(.title3.bold())
                            .foregroundStyle(Palette.accent)
                        Text(run.bossFound ? "ボス発見!!" : "ボス捜索中……")
                            .font(.headline)
                            .foregroundStyle(run.bossFound ? Palette.danger : Palette.textPrimary)

                        if !run.bossFound, let progress = run.searchProgress() {
                            ProgressView(value: progress)
                                .tint(Palette.accent)
                            Text("確実発見まで着実に近づいている")
                                .font(.caption2)
                                .foregroundStyle(Palette.textSecondary)
                        }

                        // パーティのドット絵
                        HStack(spacing: 12) {
                            ForEach(game.data.partyCharacters) { chara in
                                CharacterSpriteView(spriteKey: chara.jobID, pixelSize: 3)
                            }
                            ForEach(game.data.partyOtomos) { otomo in
                                CharacterSpriteView(spriteKey: otomo.speciesID, pixelSize: 3)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .panelStyle()

                    // 収集状況(ボス捜索中も自動収集)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("収集品")
                            .font(.headline)
                            .foregroundStyle(Palette.accent)
                        HStack(spacing: 16) {
                            Label("\(run.collectedCoins)", systemImage: "circle.circle.fill")
                            Label("\(run.collectedExp)", systemImage: "arrow.up.circle.fill")
                            Label("\(run.collectedMaterials)", systemImage: "cube.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelStyle()

                    // 探索ログ
                    VStack(alignment: .leading, spacing: 4) {
                        Text("探索ログ")
                            .font(.headline)
                            .foregroundStyle(Palette.accent)
                        if run.log.isEmpty {
                            Text("まだ報告はない……")
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        } else {
                            ForEach(run.log.reversed()) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(Palette.textSecondary)
                                    Text(entry.message)
                                        .font(.caption)
                                        .foregroundStyle(Palette.textPrimary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelStyle()

                    // 操作
                    VStack(spacing: 10) {
                        if run.bossFound {
                            Button {
                                showBattle = true
                            } label: {
                                Text("ボスに挑む")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.danger))
                                    .foregroundStyle(.white)
                            }
                        }
                        Button {
                            game.retreat()
                        } label: {
                            Text("撤退する(収集品は持ち帰る)")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Palette.panelBorder))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                game.processIdle()
            }
            .fullScreenCover(isPresented: $showBattle) {
                BossBattleView(dungeon: dungeon)
            }
        )
    }
}
