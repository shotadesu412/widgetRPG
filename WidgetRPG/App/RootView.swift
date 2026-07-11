import SwiftUI

/// 下部メニュー: ホーム / ダンジョン / オトモ / キャラ / パーティ
struct RootView: View {
    // 開発用: 環境変数 START_TAB で初期タブを指定できる(0=ホーム 〜 4=パーティ)
    @State private var selection = Int(ProcessInfo.processInfo.environment["START_TAB"] ?? "") ?? 0
    // 開発用: DEV_BATTLE=1 / DEV_GACHA=1 / DEV_EGG=1 で起動時に各ツールを開く
    @State private var showDevBattle = ProcessInfo.processInfo.environment["DEV_BATTLE"] == "1"
    @State private var showDevGacha = ProcessInfo.processInfo.environment["DEV_GACHA"] == "1"
    @State private var showDevEgg = ProcessInfo.processInfo.environment["DEV_EGG"] == "1"

    var body: some View {
        content
            .fullScreenCover(isPresented: $showDevBattle) {
                DevBattleView()
                    .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: $showDevGacha) {
                DevGachaView()
            }
            .fullScreenCover(isPresented: $showDevEgg) {
                DevEggView()
            }
    }

    private var content: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(0)
            DungeonView()
                .tabItem { Label("ダンジョン", systemImage: "map.fill") }
                .tag(1)
            OtomoView()
                .tabItem { Label("オトモ", systemImage: "pawprint.fill") }
                .tag(2)
            CharacterListView()
                .tabItem { Label("キャラ", systemImage: "person.3.fill") }
                .tag(3)
            PartyView()
                .tabItem { Label("パーティ", systemImage: "flag.fill") }
                .tag(4)
        }
        .background(Palette.background)
    }
}

#Preview {
    RootView()
        .environmentObject(GameViewModel())
        .preferredColorScheme(.dark)
}
