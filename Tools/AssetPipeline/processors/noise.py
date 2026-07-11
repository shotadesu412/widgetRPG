"""ドット補正・ノイズ除去 Processor。

AI 生成画像特有の (1)半透明 (2)アンチエイリアス (3)孤立ピクセル を補正する。
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Noise(Processor):
    """アルファ二値化と孤立ピクセル除去。"""

    name = "noise"

    def process(self, ctx: AssetContext) -> AssetContext:
        img = ctx.image.convert("RGBA")
        arr = np.array(img)
        report: dict[str, int] = {}

        # 半透明・アンチエイリアスの補正: アルファを二値化する
        if self.config.remove_antialias:
            threshold = self.config.alpha_threshold
            alpha = arr[:, :, 3]
            before = int(((alpha > 0) & (alpha < 255)).sum())
            arr[:, :, 3] = np.where(alpha >= threshold, 255, 0).astype(np.uint8)
            report["binarized_px"] = before

        # 孤立ピクセル除去: 8近傍に不透明がほぼ無い点を消す
        if self.config.noise_remove:
            mask = arr[:, :, 3] > 0
            neighbors = np.zeros(mask.shape, dtype=np.uint8)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    shifted = np.zeros_like(mask)
                    ys = slice(max(dy, 0), mask.shape[0] + min(dy, 0))
                    yd = slice(max(-dy, 0), mask.shape[0] + min(-dy, 0))
                    xs = slice(max(dx, 0), mask.shape[1] + min(dx, 0))
                    xd = slice(max(-dx, 0), mask.shape[1] + min(-dx, 0))
                    shifted[yd, xd] = mask[ys, xs]
                    neighbors += shifted
            isolated = mask & (neighbors <= 1)
            arr[isolated, 3] = 0
            report["isolated_px"] = int(isolated.sum())

        ctx.note(self.name, **report)
        ctx.image = Image.fromarray(arr, "RGBA")
        return ctx
