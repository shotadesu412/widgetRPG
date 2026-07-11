"""Outline Processor。

アルファ輪郭を検出し、統一色のアウトラインを付ける。太さは設定可能。
アウトライン分だけキャンバスを広げるので、端のキャラでも欠けない。
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register
from utils.color import hex_to_rgb


@register
class Outline(Processor):
    """輪郭に outline_color を1〜Npx で描く。"""

    name = "outline"

    def process(self, ctx: AssetContext) -> AssetContext:
        if not self.config.outline:
            return ctx

        t = max(1, self.config.outline_thickness)
        img = ctx.image.convert("RGBA")
        # 余白を確保してから輪郭を打つ
        padded = Image.new("RGBA", (img.width + t * 2, img.height + t * 2), (0, 0, 0, 0))
        padded.paste(img, (t, t))
        arr = np.array(padded)
        mask = arr[:, :, 3] > 0

        dilated = mask.copy()
        for _ in range(t):
            grown = dilated.copy()
            grown[1:, :] |= dilated[:-1, :]
            grown[:-1, :] |= dilated[1:, :]
            grown[:, 1:] |= dilated[:, :-1]
            grown[:, :-1] |= dilated[:, 1:]
            dilated = grown

        outline_px = dilated & ~mask
        r, g, b = hex_to_rgb(self.config.outline_color)
        arr[outline_px] = (r, g, b, 255)

        ctx.note(self.name, thickness=t, outline_px=int(outline_px.sum()))
        ctx.image = Image.fromarray(arr, "RGBA")
        return ctx
