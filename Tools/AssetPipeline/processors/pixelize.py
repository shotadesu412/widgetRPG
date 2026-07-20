"""Pixelize Processor。

AI 画像をドット絵へ変換する。pixel_size(1〜4)でドットの粗さを変える。
キャンバス座標(0,0)を基準にした p×p グリッドで各ブロックを1色に揃える。
サイズは変えないので、後段でリサイズが入らない限りドットの格子は保たれる
(=縁も内部も同じ粗さになる)。このため pixelize はパイプラインの
最後のサイズ変更(ground)より後に置くこと。
pixel_size=1 は無変換。
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Pixelize(Processor):
    """キャンバスのグリッドに沿って p×p ブロックを1色に量子化する。"""

    name = "pixelize"

    def process(self, ctx: AssetContext) -> AssetContext:
        p = self.config.pixel_size
        if p <= 1:
            ctx.note(self.name, skipped="pixel_size=1")
            return ctx

        img = ctx.image.convert("RGBA")
        arr = np.asarray(img).astype(np.float32)
        h, w = arr.shape[:2]

        out = arr.copy()
        for by in range(0, h, p):
            for bx in range(0, w, p):
                block = arr[by:by + p, bx:bx + p]
                a = block[:, :, 3]
                opaque = a > 128
                # ブロックの過半が不透明ならまとめて不透明1色、そうでなければ透明
                if opaque.mean() >= 0.5:
                    rgb = block[:, :, :3][opaque]
                    color = rgb.mean(axis=0) if len(rgb) else block[:, :, :3].mean(axis=(0, 1))
                    out[by:by + p, bx:bx + p, :3] = color
                    out[by:by + p, bx:bx + p, 3] = 255
                else:
                    out[by:by + p, bx:bx + p, 3] = 0

        ctx.image = Image.fromarray(out.astype(np.uint8), "RGBA")
        ctx.note(self.name, pixel_size=p, grid=f"{w // p}x{h // p}")
        return ctx
