"""Pixelize Processor。

AI 画像をドット絵へ変換する。pixel_size(1〜4)でドットの粗さを変える。
Nearest Neighbor のみを使い、縮小→再拡大でドットの格子を作る。
pixel_size=1 は無変換(すでにドット密度が合っている素材用)。
"""

from __future__ import annotations

from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Pixelize(Processor):
    """縮小→Nearest再拡大でドット化する。"""

    name = "pixelize"

    def process(self, ctx: AssetContext) -> AssetContext:
        p = self.config.pixel_size
        if p <= 1:
            ctx.note(self.name, skipped="pixel_size=1")
            return ctx

        img = ctx.image.convert("RGBA")
        w, h = img.size
        small = img.resize(
            (max(1, w // p), max(1, h // p)), Image.Resampling.NEAREST
        )
        ctx.image = small.resize(
            (small.width * p, small.height * p), Image.Resampling.NEAREST
        )
        ctx.note(self.name, pixel_size=p, dot_grid=small.size)
        return ctx
