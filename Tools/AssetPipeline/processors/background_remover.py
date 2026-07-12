"""背景透過 Processor。

背景色を四隅から自動判定して透明化する。bg_mode で方式を選べる。

    global    画面全体から背景色に近いピクセルを除去(既定)。
              雲などに囲われて外周と繋がらない背景ポケットも消える。
              残った浮遊物は isolate Processor が除去する。
    floodfill 外周から連結した近似色領域のみ透明化。
              キャラ内部に背景色と似た色がある素材向け。
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
        rgb = arr[:, :, :3].astype(np.float32)
        near = color_distance(rgb, np.array(bg, dtype=np.float32)) <= tolerance

        if self.config.bg_mode == "global":
            # 画面全体キーイング: 位置に関係なく背景色近似を除去。
            # 背景に彩度があれば色相ベース(明暗ムラ・雲の陰のシェード違いに強い)、
            # 無彩色背景なら RGB 距離で除去する。
            key = near | self._hue_key(arr, bg)
            arr[key, 3] = 0
            ctx.note(self.name, mode="global", background=rgb_to_hex(bg), removed_px=int(key.sum()))
            ctx.image = Image.fromarray(arr, "RGBA")
            return ctx

        # floodfill: 外周からのフラッドフィルで背景領域を求める
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
        ctx.note(self.name, mode="floodfill", background=rgb_to_hex(bg), removed_px=removed)
        ctx.image = Image.fromarray(arr, "RGBA")
        return ctx

    def _hue_key(self, arr: np.ndarray, bg: tuple[int, int, int]) -> np.ndarray:
        """背景色と同系色相のピクセルを検出する(グローバルキーイング用)。

        背景が無彩色(彩度が低い)の場合は色相が不定なので何も返さない。
        キャラの黒アウトラインを守るため、暗すぎるピクセルは対象外にする。
        """
        h, w = arr.shape[:2]
        r, g, b = (float(c) / 255 for c in bg)
        mx, mn = max(r, g, b), min(r, g, b)
        bg_sat = 0.0 if mx == 0 else (mx - mn) / mx
        if bg_sat < 0.2:
            return np.zeros((h, w), dtype=bool)
        bg_hue = self._hue(np.array([[bg]], dtype=np.float32) / 255)[0, 0]

        rgb = arr[:, :, :3].astype(np.float32) / 255
        maxc = rgb.max(axis=2)
        minc = rgb.min(axis=2)
        sat = np.where(maxc > 0, (maxc - minc) / np.maximum(maxc, 1e-6), 0)
        hue = self._hue(rgb)
        hue_diff = np.abs(hue - bg_hue)
        hue_diff = np.minimum(hue_diff, 360 - hue_diff)

        # 同系色相・十分な彩度・暗すぎない(=アウトラインでない)ピクセル
        return (hue_diff <= 18) & (sat >= 0.22) & (maxc >= 0.16)

    @staticmethod
    def _hue(rgb: np.ndarray) -> np.ndarray:
        """RGB(0-1, (...,3)) から色相(度)を計算する。無彩色は 0。"""
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        maxc = np.maximum(np.maximum(r, g), b)
        minc = np.minimum(np.minimum(r, g), b)
        delta = maxc - minc
        hue = np.zeros_like(maxc)
        safe = delta > 1e-6
        rmax = safe & (maxc == r)
        gmax = safe & (maxc == g) & ~rmax
        bmax = safe & ~rmax & ~gmax
        d = np.where(safe, delta, 1)
        hue[rmax] = (60 * ((g - b) / d) % 360)[rmax]
        hue[gmax] = (60 * ((b - r) / d) + 120)[gmax]
        hue[bmax] = (60 * ((r - g) / d) + 240)[bmax]
        return hue

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
