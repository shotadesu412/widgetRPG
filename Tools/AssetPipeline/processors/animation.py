"""Idle アニメ生成 Processor(段階6で実装予定)。

立ち絵1枚から「少し動かす」待機アニメ(Idle1/Idle2)を変形ベースで生成する。
AI による描き直しは行わない。実装予定の内容:
    - パーツ推定(頭/胴体/腕/脚/羽/尻尾/マント/武器/髪)
    - 微動(胸±1px、羽±1px、マント裾、尻尾左右、浮遊全体±1px)
    - 変形量 ±1〜3px
    - 変形で欠けたドットの補完(輪郭を崩さない)
"""

from __future__ import annotations

from models.context import AssetContext
from processors.base import Processor, register


@register
class Animation(Processor):
    """待機アニメの補助生成(未実装)。"""

    name = "animation"

    def process(self, ctx: AssetContext) -> AssetContext:
        raise NotImplementedError("animation Processor は段階6で実装予定です。")
