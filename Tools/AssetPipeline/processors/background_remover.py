"""背景透過 Processor。

背景色を四隅から自動判定し、外周から連結した近似色領域を透明化する。
フラッドフィル方式なので、キャラ内部の背景色に近いピクセルは保持される。
"""

from __future__ import annotations

from collections import deque

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register
from utils.color import color_distance, rgb_to_hex


@register
class BackgroundRemover(Processor):
    """四隅の色から背景色を推定して透明化する。"""

    name = "background_remover"

    def process(self, ctx: AssetContext) -> AssetContext:
        if not self.config.transparent_background:
            return ctx

        img = ctx.image.convert("RGBA")
        arr = np.array(img)
        h, w = arr.shape[:2]

        # すでに外周が透過済みなら何もしない(再処理・透過素材対応)
        border_alpha = np.concatenate(
            [arr[0, :, 3], arr[-1, :, 3], arr[:, 0, 3], arr[:, -1, 3]]
        )
        if (border_alpha < 16).mean() > 0.5:
            ctx.note(self.name, skipped="already transparent")
            ctx.image = img
            return ctx

        bg = self._estimate_background(arr)
        tolerance = float(self.config.bg_tolerance)

        # 外周からのフラッドフィルで背景領域を求める
        rgb = arr[:, :, :3].astype(np.float32)
        near = color_distance(rgb, np.array(bg, dtype=np.float32)) <= tolerance
        visited = np.zeros((h, w), dtype=bool)
        queue: deque[tuple[int, int]] = deque()
        for x in range(w):
            for y in (0, h - 1):
                if near[y, x] and not visited[y, x]:
                    visited[y, x] = True
                    queue.append((y, x))
        for y in range(h):
            for x in (0, w - 1):
                if near[y, x] and not visited[y, x]:
                    visited[y, x] = True
                    queue.append((y, x))
        while queue:
            y, x = queue.popleft()
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not visited[ny, nx]:
                    visited[ny, nx] = True
                    queue.append((ny, nx))

        arr[visited, 3] = 0

        # 近似色の残り(縁のフリンジ)も透明化: 背景色にごく近い半端な画素
        fringe = (arr[:, :, 3] > 0) & (
            color_distance(rgb, np.array(bg, dtype=np.float32)) <= tolerance * 0.6
        )
        arr[fringe, 3] = 0

        removed = int(visited.sum() + fringe.sum())
        ctx.note(self.name, background=rgb_to_hex(bg), removed_px=removed)
        ctx.image = Image.fromarray(arr, "RGBA")
        return ctx

    @staticmethod
    def _estimate_background(arr: np.ndarray) -> tuple[int, int, int]:
        """四隅の小パッチの中央値から背景色を推定する。"""
        h, w = arr.shape[:2]
        p = max(2, min(h, w) // 50)
        patches = [
            arr[:p, :p, :3],
            arr[:p, -p:, :3],
            arr[-p:, :p, :3],
            arr[-p:, -p:, :3],
        ]
        samples = np.concatenate([pt.reshape(-1, 3) for pt in patches])
        median = np.median(samples, axis=0).astype(int)
        return int(median[0]), int(median[1]), int(median[2])
