"""主要成分抽出 Processor。

背景除去後に残る「キャラ本体から離れた浮遊物」(羽根・雲片・エフェクト飛沫など、
AI 生成画像の典型的な残骸)を除去する。

不透明ピクセルを連結成分(8近傍)に分解し、最大成分に対して
min_component_ratio 未満の小さな成分を捨てる。キャラ本体・翼など
つながっているパーツは1成分として必ず残る。
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class Isolate(Processor):
    """最大連結成分を基準に、離れた小成分を除去する。"""

    name = "isolate"

    def process(self, ctx: AssetContext) -> AssetContext:
        if not self.config.keep_main_component:
            return ctx

        img = ctx.image.convert("RGBA")
        arr = np.array(img)
        mask = arr[:, :, 3] > 0
        if not mask.any():
            return ctx

        # ブリッジ切断: 侵食して細い接続(キャラと雲の接触など)を断ってから
        # 成分判定し、残した成分だけを侵食分だけ膨張して元の形へ復元する
        erosion = max(0, self.config.bridge_erosion)
        work = self._erode(mask, erosion) if erosion else mask

        labels, count = self._label(work)
        if count <= 1 and erosion == 0:
            ctx.note(self.name, components=count, removed=0)
            ctx.image = img
            return ctx

        sizes = np.bincount(labels.ravel())
        sizes[0] = 0  # ラベル0は透明領域
        largest = int(sizes.max()) if count else 0
        threshold = max(1, int(largest * self.config.min_component_ratio))
        keep = sizes >= threshold
        kept_mask = keep[labels] & work

        # 復元: 元マスク内に限定して侵食回数+1だけ膨張(輪郭を取り戻す)
        for _ in range(erosion + 1 if erosion else 0):
            kept_mask = self._dilate(kept_mask) & mask
        if erosion == 0:
            pass
        drop = mask & ~kept_mask if erosion else (~keep[labels] & mask)
        arr[drop, 3] = 0

        ctx.note(
            self.name,
            components=count,
            kept=int(keep[1:].sum()),
            removed_px=int(drop.sum()),
            largest_px=largest,
            bridge_erosion=erosion,
        )
        ctx.image = Image.fromarray(arr, "RGBA")
        return ctx

    @staticmethod
    def _erode(mask: np.ndarray, n: int) -> np.ndarray:
        """4近傍の侵食を n 回。"""
        out = mask.copy()
        for _ in range(n):
            shrunk = out.copy()
            shrunk[1:, :] &= out[:-1, :]
            shrunk[:-1, :] &= out[1:, :]
            shrunk[:, 1:] &= out[:, :-1]
            shrunk[:, :-1] &= out[:, 1:]
            out = shrunk
        return out

    @staticmethod
    def _dilate(mask: np.ndarray) -> np.ndarray:
        """8近傍の膨張を1回。"""
        out = mask.copy()
        out[1:, :] |= mask[:-1, :]
        out[:-1, :] |= mask[1:, :]
        out[:, 1:] |= mask[:, :-1]
        out[:, :-1] |= mask[:, 1:]
        out[1:, 1:] |= mask[:-1, :-1]
        out[1:, :-1] |= mask[:-1, 1:]
        out[:-1, 1:] |= mask[1:, :-1]
        out[:-1, :-1] |= mask[1:, 1:]
        return out

    @staticmethod
    def _label(mask: np.ndarray) -> tuple[np.ndarray, int]:
        """8近傍の連結成分ラベリング(反復フラッドフィル、依存なし)。

        Returns:
            (ラベル配列, 成分数)。ラベル0は背景。
        """
        h, w = mask.shape
        labels = np.zeros((h, w), dtype=np.int32)
        current = 0
        stack: list[tuple[int, int]] = []
        for sy in range(h):
            for sx in range(w):
                if not mask[sy, sx] or labels[sy, sx]:
                    continue
                current += 1
                labels[sy, sx] = current
                stack.append((sy, sx))
                while stack:
                    y, x = stack.pop()
                    y0, y1 = max(0, y - 1), min(h, y + 2)
                    x0, x1 = max(0, x - 1), min(w, x + 2)
                    for ny in range(y0, y1):
                        for nx in range(x0, x1):
                            if mask[ny, nx] and not labels[ny, nx]:
                                labels[ny, nx] = current
                                stack.append((ny, nx))
        return labels, current
