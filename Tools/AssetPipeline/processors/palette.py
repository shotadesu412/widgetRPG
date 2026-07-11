"""パレット統一 Processor。

色数を 16/32/64/128 に減色する(Median Cut)。config.palette_file に
共通パレット(JSONの hex 配列)を指定すると、ゲーム全体で同じパレットに
マッピングできる。透明ピクセルはパレット計算から除外する。
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register
from utils.color import hex_to_rgb, map_to_palette, rgb_to_hex


@register
class Palette(Processor):
    """減色(Median Cut)または共通パレットへのマッピング。"""

    name = "palette"

    def process(self, ctx: AssetContext) -> AssetContext:
        img = ctx.image.convert("RGBA")
        arr = np.array(img)
        alpha = arr[:, :, 3]
        opaque = alpha > 0
        if not opaque.any():
            return ctx

        palette = self._load_common_palette()
        if palette is None:
            palette = self._median_cut_palette(arr[opaque][:, :3], self.config.palette_size)
            source = "median_cut"
        else:
            source = str(self.config.palette_file)

        pixels = arr[:, :, :3].reshape(-1, 3)
        mapped = map_to_palette(pixels, palette)
        arr[:, :, :3] = mapped.reshape(arr.shape[0], arr.shape[1], 3)
        # 透明部分の色は黒に統一(見えないがファイルを安定させる)
        arr[~opaque, 0:3] = 0

        ctx.note(
            self.name,
            colors=len(palette),
            source=source,
            palette=[rgb_to_hex(tuple(c)) for c in palette[:8]] + (["..."] if len(palette) > 8 else []),
        )
        ctx.image = Image.fromarray(arr, "RGBA")
        return ctx

    def _load_common_palette(self) -> np.ndarray | None:
        """共通パレット(hex配列のJSON)を読み込む。未指定なら None。"""
        if not self.config.palette_file:
            return None
        path = Path(self.config.palette_file)
        if not path.is_absolute():
            path = Path(__file__).resolve().parent.parent / path
        if not path.exists():
            raise FileNotFoundError(f"共通パレットが見つかりません: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))
        colors = data["colors"] if isinstance(data, dict) else data
        return np.array([hex_to_rgb(c) for c in colors], dtype=np.uint8)

    @staticmethod
    def _median_cut_palette(opaque_rgb: np.ndarray, size: int) -> np.ndarray:
        """不透明ピクセルのみから Median Cut でパレットを作る。"""
        strip = Image.fromarray(opaque_rgb.reshape(1, -1, 3), "RGB")
        quantized = strip.quantize(colors=size, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        raw = quantized.getpalette()[: size * 3]
        palette = np.array(raw, dtype=np.uint8).reshape(-1, 3)
        # 実際に使われた色だけに絞る
        used = sorted(set(np.asarray(quantized).ravel().tolist()))
        return palette[used]
