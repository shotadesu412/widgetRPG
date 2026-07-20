"""ドット抜け修復 Processor(モルフォロジ・クロージング)。

大きな原画を小さくドット化すると、剣の刃・杖・尻尾などの細い形状が
1px 未満に潰れて途切れ、透明の隙間(ドット抜け)ができる。

alpha チャンネルにクロージング(膨張→収縮)をかけて、
`repair_close` px 以下の細い隙間だけを塞ぐ。形の外周はほぼ変えない。
埋めた隙間の色は近傍の不透明画素で補完する。

pixelize の直後(palette の前)に置くことを想定。
config の repair_close で強さを調整(0 で無効)。
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Repair(Processor):
    name = "repair"

    def process(self, ctx: AssetContext) -> AssetContext:
        radius = int(getattr(self.config, "repair_close", 0))
        if radius <= 0:
            ctx.note(self.name, skipped="repair_close=0")
            return ctx

        img = ctx.image.convert("RGBA")
        arr = np.asarray(img).copy()
        alpha = arr[:, :, 3]
        solid = alpha > 128

        # クロージング = 膨張してから同じ回数だけ収縮。
        # これで radius px 以下の隙間だけが埋まり、外周の形は戻る。
        dilated = solid.copy()
        for _ in range(radius):
            dilated = self._dilate(dilated)
        closed = dilated.copy()
        for _ in range(radius):
            closed = self._erode(closed)

        filled = closed & ~solid  # 新たに埋まった画素
        if not filled.any():
            ctx.note(self.name, filled_px=0)
            return ctx

        # 埋めた画素の色を近傍の不透明画素から補完(反復的に外側から染み込ませる)
        rgb = arr[:, :, :3].astype(np.float32)
        known = solid.copy()
        todo = filled.copy()
        for _ in range(radius + 2):
            if not todo.any():
                break
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                shifted_rgb = np.roll(rgb, (dy, dx), axis=(0, 1))
                shifted_known = np.roll(known, (dy, dx), axis=(0, 1))
                take = todo & shifted_known
                rgb[take] = shifted_rgb[take]
                arr[take, 3] = 255
                known |= take
                todo &= ~take

        arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        ctx.image = Image.fromarray(arr, "RGBA")
        ctx.note(self.name, radius=radius, filled_px=int(filled.sum()))
        return ctx

    @staticmethod
    def _dilate(mask: np.ndarray) -> np.ndarray:
        out = mask.copy()
        out[1:, :] |= mask[:-1, :]
        out[:-1, :] |= mask[1:, :]
        out[:, 1:] |= mask[:, :-1]
        out[:, :-1] |= mask[:, 1:]
        return out

    @staticmethod
    def _erode(mask: np.ndarray) -> np.ndarray:
        out = mask.copy()
        out[1:, :] &= mask[:-1, :]
        out[:-1, :] &= mask[1:, :]
        out[:, 1:] &= mask[:, :-1]
        out[:, :-1] &= mask[:, 1:]
        return out
