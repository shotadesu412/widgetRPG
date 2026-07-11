"""スタイルプロファイル。

既存のゲームアセット群を解析し「ゲーム全体のアートスタイル」を数値化する。
将来的には、新規AI生成画像をこのプロファイルへ自動で寄せるための基準になる。

現在解析する項目:
    - 共通パレット(全アセットの不透明ピクセルから Median Cut)
    - 明暗バランス(輝度の平均・標準偏差)
    - 彩度の平均
    - コントラスト(輝度の分散に基づく)
    - ドット密度(隣接ピクセルの色変化率 ≒ 1ドットの粗さ)
    - アウトライン傾向(輪郭部の最頻色と暗さ)

拡張予定: 光源方向の推定、影の傾向、カテゴリ別プロファイル。
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from PIL import Image

from utils.color import rgb_to_hex


@dataclass
class StyleProfile:
    """アートスタイルの解析結果。"""

    name: str
    source_count: int
    palette: list[str]
    brightness_mean: float
    brightness_std: float
    saturation_mean: float
    contrast: float
    dot_density: float
    outline_color: str
    outline_darkness: float

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(asdict(self), ensure_ascii=False, indent=2), encoding="utf-8"
        )

    @classmethod
    def analyze(cls, files: list[Path], name: str, palette_size: int = 32) -> "StyleProfile":
        """PNG 群からスタイルプロファイルを作る。"""
        if not files:
            raise ValueError("解析対象の PNG がありません")

        all_opaque: list[np.ndarray] = []
        brightness: list[np.ndarray] = []
        saturation: list[np.ndarray] = []
        edge_colors: list[np.ndarray] = []
        density: list[float] = []

        for f in files:
            arr = np.array(Image.open(f).convert("RGBA"))
            mask = arr[:, :, 3] > 0
            if not mask.any():
                continue
            rgb = arr[:, :, :3].astype(np.float32)
            opaque_rgb = rgb[mask]
            all_opaque.append(opaque_rgb.astype(np.uint8))

            luma = opaque_rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
            brightness.append(luma)
            mx = opaque_rgb.max(axis=1)
            mn = opaque_rgb.min(axis=1)
            saturation.append(np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0))

            # ドット密度: 水平方向の隣接色変化率(不透明領域内)
            same_row = mask[:, 1:] & mask[:, :-1]
            if same_row.any():
                diff = np.abs(rgb[:, 1:] - rgb[:, :-1]).sum(axis=2) > 24
                density.append(float(diff[same_row].mean()))

            # 輪郭部(不透明かつ透明に隣接)の色
            edge = mask & ~(
                np.roll(mask, 1, 0) & np.roll(mask, -1, 0)
                & np.roll(mask, 1, 1) & np.roll(mask, -1, 1)
            )
            if edge.any():
                edge_colors.append(rgb[edge].astype(np.uint8))

        merged = np.concatenate(all_opaque)
        strip = Image.fromarray(merged.reshape(1, -1, 3), "RGB")
        quantized = strip.quantize(
            colors=palette_size, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
        )
        raw = quantized.getpalette()[: palette_size * 3]
        used = sorted(set(np.asarray(quantized).ravel().tolist()))
        palette = np.array(raw, dtype=np.uint8).reshape(-1, 3)[used]

        luma_all = np.concatenate(brightness)
        edges = np.concatenate(edge_colors) if edge_colors else merged
        edge_luma = edges.astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        dark_edges = edges[edge_luma < np.percentile(edge_luma, 25)]
        outline = tuple(np.median(dark_edges, axis=0).astype(int)) if len(dark_edges) else (32, 32, 32)

        return cls(
            name=name,
            source_count=len(files),
            palette=[rgb_to_hex(tuple(c)) for c in palette],
            brightness_mean=round(float(luma_all.mean()), 2),
            brightness_std=round(float(luma_all.std()), 2),
            saturation_mean=round(float(np.concatenate(saturation).mean()), 4),
            contrast=round(float(luma_all.std() / 255.0), 4),
            dot_density=round(float(np.mean(density)) if density else 0.0, 4),
            outline_color=rgb_to_hex((int(outline[0]), int(outline[1]), int(outline[2]))),
            outline_darkness=round(float(edge_luma.mean() / 255.0), 4),
        )
