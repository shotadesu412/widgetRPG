#!/bin/zsh
# ヘッドレス・プレイテストの実行(Sharedのゲームロジックをそのままコンパイル)
set -e
cd "$(dirname "$0")/../.."
mkdir -p /tmp/widgetrpg_playtest
xcrun swiftc -O -o /tmp/widgetrpg_playtest/playtest \
  Shared/Models/*.swift Shared/Core/*.swift Shared/GameData/*.swift Shared/UI/*.swift \
  Tools/Playtest/main.swift 2>&1 | grep -v "^$" | head -20
/tmp/widgetrpg_playtest/playtest
