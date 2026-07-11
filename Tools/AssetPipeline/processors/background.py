"""背景画像専用 Processor(段階4で実装予定)。

キャラとは別処理。実装予定の内容:
    - 色味統一 / コントラスト統一(スタイルプロファイル参照)
    - ドット密度統一
    - ノイズ除去
    - タイル分割 / シームレス補助
    - 昼→夜変換 / 色違い背景生成
"""

from __future__ import annotations

from models.context import AssetContext
from processors.base import Processor, register


@register
class Background(Processor):
    """背景画像の統一処理(未実装)。"""

    name = "background"

    def process(self, ctx: AssetContext) -> AssetContext:
        raise NotImplementedError(
            "background Processor は段階4で実装予定です。"
            "現状の backgrounds プリセットは noise/pixelize/palette のみ使用してください。"
        )
