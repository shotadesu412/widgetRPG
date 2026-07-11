"""色の変換・距離計算。"""

from __future__ import annotations

import numpy as np


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    """"#RRGGBB" を (r, g, b) に変換する。"""
    value = value.lstrip("#")
    if len(value) != 6:
        raise ValueError(f"不正なカラーコード: #{value}")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    """(r, g, b) を "#RRGGBB" に変換する。"""
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def color_distance(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """RGB のユークリッド距離。a: (...,3), b: (3,) or (...,3)。"""
    return np.sqrt(np.sum((a.astype(np.float32) - b.astype(np.float32)) ** 2, axis=-1))


def map_to_palette(rgb: np.ndarray, palette: np.ndarray, chunk: int = 65536) -> np.ndarray:
    """各ピクセルを最近傍パレット色に置き換える。

    Args:
        rgb: (N, 3) uint8 のピクセル列。
        palette: (K, 3) uint8 のパレット。
        chunk: メモリを抑えるための分割処理サイズ。
    Returns:
        (N, 3) uint8。パレット色のみで構成される。
    """
    out = np.empty_like(rgb)
    pal = palette.astype(np.float32)
    for start in range(0, len(rgb), chunk):
        block = rgb[start : start + chunk].astype(np.float32)  # (C,3)
        # (C,1,3)-(1,K,3) → (C,K) の距離
        dist = np.sum((block[:, None, :] - pal[None, :, :]) ** 2, axis=-1)
        out[start : start + chunk] = palette[np.argmin(dist, axis=1)]
    return out
