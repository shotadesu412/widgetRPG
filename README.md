# ウィジェットRPG

ホーム画面で育つ放置RPG。ウィジェットにゲーム内の様子を表示して、アプリを閉じてもキャラを見守れる。
Swift + SwiftUI + WidgetKit。

## プロジェクト生成・ビルド

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成する。

```sh
xcodegen generate
open WidgetRPG.xcodeproj
```

署名は `Signing.xcconfig` の `DEVELOPMENT_TEAM` で設定する(現在の開発証明書の
Team ID `7Z2ZRB6V2J` を既定値済み)。自動署名なので Xcode が App ID / App Group を登録する。

## 実機テスト

署名込みの実機ビルド(App Group エンタイトルメント含む)まで動作確認済み。

```sh
# 一覧から自分のiPhoneのUDIDを確認
xcrun xctrace list devices

# ビルドしてインストール(iPhoneをMacに接続・信頼しておく)
xcodebuild -project WidgetRPG.xcodeproj -scheme WidgetRPG \
  -destination 'id=<iPhoneのUDID>' -allowProvisioningUpdates \
  build

# もしくは Xcode で開いて実機を選び ⌘R
open WidgetRPG.xcodeproj
```

- App Group `group.com.shota.widgetrpg` はこのチームで登録済み(本体↔ウィジェットでセーブ共有)。
- 無料(個人)アカウントに切り替える場合は App Group が使えないため、両ターゲットの
  `.entitlements` から App Group を外す(ウィジェットはセーブ共有できなくなる)。
- 開発用に環境変数 `START_TAB`(0=ホーム〜4=パーティ)で起動タブを指定できる。

## キャラ絵(スプライト)の差し込み

キャラ絵は状態ごとに画像を差し込める構造。`Shared/Sprites.xcassets` に、以下の命名で
画像セット(imageset)を追加すると、コード描画のプレースホルダに代わって自動表示される。
画像が無いキャラ・状態は従来どおりプレースホルダにフォールバックする。

命名規則: `<spriteKey>_<状態>_<コマ番号>`

| 状態 | 命名 | 枚数 |
|------|------|------|
| 待機 | `<key>_idle_0`, `_idle_1` | 2枚(ループ) |
| 通常攻撃 | `<key>_attackNormal_0` | 1枚 |
| スキル攻撃 | `<key>_attackSkill_0` | 1枚 |
| 被弾 | `<key>_hurt_0` | 1枚 |
| 戦闘不能 | `<key>_down_0` | 1枚 |
| 必殺 | `<key>_ultimate_0`, `_ultimate_1` | 1〜2枚 |

`<spriteKey>` は 職ID(例: `swordsman` `mage` `ninja` …)、オトモ種族ID(`slime` `dog` …)、
敵ID(`dragon` `cthulhu` …)。IDの一覧は `Shared/GameData/` の各カタログを参照。
ドット絵をぼかさず表示する(`interpolation(.none)`)。状態と枚数の定義は
`Shared/UI/SpriteAnimation.swift` の `SpriteState`。戦闘中は攻撃・被弾・必殺・戦闘不能に
自動で切り替わる(`BattleEngine.Unit.visualState`)。

## 構成

```
Shared/            本体・ウィジェット共有コード
  Models/          キャラ・装備・オトモ・卵・ダンジョン・ショップ等のモデル
  GameData/        職・オトモ種族・ダンジョン・アイテム生成のカタログ
  Core/            セーブデータ / 永続化(App Group) / 放置進行 / ATB戦闘エンジン
  UI/              配色(暗め基調) / ドット絵プレースホルダ描画
WidgetRPG/         本体アプリ(5タブ: ホーム / ダンジョン / オトモ / キャラ / パーティ)
WidgetRPGWidget/   ウィジェット拡張(5画面切替 + 下部2ボタン + 15分自動更新)
```

## 実装済みの骨組み

- **ダンジョン**: 潜入 → 放置で毎分コイン・経験値・素材・装備・卵を自動収集。
  確率でボス発見、一定時間経過で確実発見(カオスは青天井)。メインは4系統×15層。
- **ボス戦**: 手動のアクティブタイムバトル。ゲージはメモリ無しの緑→赤グラデーション。
  左に味方・右に敵。スロット(3〜4)が周回し、3周で必殺技。空きスロットは通常攻撃。
  武器スキルはランダム位置に固定、キャラスキルは好きな位置に配置。
- **キャラ**: ギルドに毎日3人来訪、1人選んで確率スカウト(失敗で確率上昇)。
  3段階進化(ひらがな→カタカナ→漢字)。通常10職 + 特殊戦闘4職 + 特殊支援6職。
- **オトモ**: 卵から孵化(強いほど時間が長い)。星1〜3、伝説・神話は進化しない。
- **装備**: 武器8種(個体差あり)・防具5種(重量で素早さ低下 / パッシブ付与)。
- **ウィジェット**: 卵(ひび割れ表現・時間非表示) / 攻略 / 拠点 / ショップ(見た目のみ) /
  ステータスの5画面。下部の「更新」「次へ」ボタン(AppIntent)と15分間隔の自動更新。
  朝昼夜アイコン表示つき。

## TODO(骨組みに含まれないもの)

- キャラ絵の作画そのもの(差し込みの仕組みは実装済み。`Shared/Sprites.xcassets` に
  上記命名で追加するだけ。未作画のキャラはコード描画のプレースホルダで動く)
- WeatherKit による実際の天気のウィジェット反映(現状は擬似天候)
- イベント(ゲリラレイド)・カオスの装飾アイテムドロップ・自室の飾り
- タイムキーパーのスロット干渉、スロットマシンのランダム効果などの固有ギミック本実装
- 武器種・属性ごとの装備ダンジョン解禁の細分化、ネクロノミコン(魔導書武器)ドロップ
- 素材による武器・拠点強化、バランス調整全般
