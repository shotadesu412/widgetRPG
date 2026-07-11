# AI Asset Pipeline

AI で生成した画像を、ゲーム(WidgetRPG / Swift)でそのまま使える品質へ自動加工する
Python 製の開発支援ツール。ゲーム本体とは独立して動く。

## セットアップ

```sh
cd Tools/AssetPipeline
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## 使い方

```sh
# input/characters/ に AI 生成 PNG を置いて実行
.venv/bin/python main.py run --category characters

# ファイル指定
.venv/bin/python main.py run --category characters --files ~/Downloads/dragon.png

# 共通パレット生成(以後 config.json の palette_file に指定して全素材で共有)
.venv/bin/python main.py palette --input ../../Shared/Sprites.xcassets --size 32

# スタイルプロファイル解析(既存アセットのアートスタイルを数値化)
.venv/bin/python main.py analyze --input ../../Shared/Sprites.xcassets --name dark_fantasy

# スプライトシート+JSON 生成
.venv/bin/python main.py sheet --pattern "akuma_*" --out output/sheets/akuma.png

# テスト
.venv/bin/python tests/run_tests.py
```

出力は `output/<category>/` に 128×128 の RGBA PNG。`output/previews/` に
目視確認用の拡大版も出る。`config.json` の `export_xcassets` に
`../../Shared/Sprites.xcassets` を指定すると、Xcode の imageset として
直接書き出される(Swift 側の命名規則 `<key>_<state>_<frame>` のまま使える)。

## Ground System(全キャラ共通ルール)

| 項目 | 値 |
|------|----|
| Canvas | 128×128 |
| Ground | Y = 112(足元をここに固定) |
| Pivot | Bottom Center |
| Safe Area | 96×96 |

## 設計

- 調整値はすべて `config.json`。カテゴリ別の差分は `presets/*.json` の `overrides`
- 機能は `processors/` の Processor 単位で分離。追加は「1ファイル書いて
  `@register` を付け、プリセットに名前を足す」だけ
- Processor は `AssetContext`(画像+メタ情報)を受け取り返す純粋変換

```
main.py                 CLI(run / palette / analyze / sheet)
config.json             全設定
presets/                カテゴリ別のパイプライン定義
processors/
  base.py               Processor 基底+レジストリ
  background_remover.py 背景透過(四隅推定+フラッドフィル+近似色)
  trim.py               BoundingBox 切り出し
  noise.py              半透明/AA 二値化・孤立ピクセル除去
  resize.py             Safe Area へ Nearest 縮小
  pixelize.py           ドット化(pixel_size 1〜4)
  palette.py            減色(Median Cut)/共通パレット適用
  outline.py            輪郭線(色・太さ設定可)
  ground.py             キャンバス配置(Ground/Pivot 固定)
  spritesheet.py        シート+JSON 生成(CLI から使用)
  background.py         背景専用(段階4で実装)
  animation.py          Idle 生成(段階6で実装)
models/
  config.py / context.py / style_profile.py
utils/                  色計算・ログ
palette/                共通パレット・スタイルプロファイルの置き場
input/ output/          入出力(内容は git 管理外)
```

## スタイルプロファイル

`analyze` で既存アセット群から共通パレット・明暗・彩度・コントラスト・
ドット密度・輪郭傾向を解析し `palette/style_<name>.json` に保存する。
将来的に「新規生成画像をプロファイルへ自動で寄せる」補正 Processor の
基準データとして使う(パレットは今すぐ `palette_file` で共有可能)。

## ロードマップ

1. ✅ 基盤(構成・設定・Processor 基盤)
2. ✅ MVP(背景透過・トリム・Ground 固定・リサイズ・パレット・PNG 出力)
3. ✅ Pixelize / Outline / Noise 除去
4. ⬜ 背景 Processor(色味/コントラスト統一・タイル分割・昼夜変換)
5. ✅ SpriteSheet 生成(最小実装)
6. ⬜ Animation Generator(パーツ推定・±1〜3px の微動・ドット補完)
7. ⬜ GUI・フォルダ監視・比較プレビュー・Undo
