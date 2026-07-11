"""キャラ抽出(トリミング)Processor。

不透明ピクセルの BoundingBox を取り、余白を削除する。
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Trim(Processor):
    """アルファの BoundingBox で切り出す。"""

    name = "trim"

    def process(self, ctx: AssetContext) -> AssetContext:
        if not self.config.trim:
            return ctx

        img = ctx.image.convert("RGBA")
        alpha = np.array(img)[:, :, 3]
        mask = alpha > 8
        if not mask.any():
            raise ValueError(f"{ctx.source.name}: 不透明ピクセルがありません(背景判定を確認)")

        ys, xs = np.where(mask)
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        ctx.image = img.crop(box)
        ctx.note(self.name, bbox=box, size=ctx.image.size)
        return ctx
