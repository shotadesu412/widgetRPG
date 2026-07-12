"""パイプライン設定。

すべての調整値は config.json から変更する。プリセット(presets/*.json)の
"overrides" でカテゴリごとに上書きできる。コード内に調整値を直書きしない。
"""

from __future__ import annotations

import json
from dataclasses import dataclass, fields, replace
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class PipelineConfig:
    """パイプライン全体の設定値。

    Ground System(ゲーム全体の共通ルール):
        Canvas 128x128 / Ground Y=112 / Pivot=Bottom Center / Safe Area 96x96
    """

    canvas_width: int = 128
    canvas_height: int = 128
    ground_y: int = 112
    safe_area: int = 96
    palette_size: int = 32
    pixel_size: int = 2
    transparent_background: bool = True
    bg_mode: str = "global"
    bg_tolerance: int = 42
    keep_main_component: bool = True
    min_component_ratio: float = 0.1
    bridge_erosion: int = 0
    trim: bool = True
    nearest_resize: bool = True
    upscale_to_safe_area: bool = False
    remove_antialias: bool = True
    alpha_threshold: int = 128
    outline: bool = True
    outline_color: str = "#202020"
    outline_thickness: int = 1
    noise_remove: bool = True
    generate_preview: bool = True
    preview_scale: int = 4
    palette_file: str | None = None
    export_xcassets: str | None = None
    style: str = "dark_fantasy"

    @classmethod
    def load(cls, path: Path) -> "PipelineConfig":
        """config.json を読み込む。存在しなければ既定値を返す。"""
        if not path.exists():
            return cls()
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls._from_dict(data)

    @classmethod
    def _from_dict(cls, data: dict[str, Any]) -> "PipelineConfig":
        known = {f.name for f in fields(cls)}
        unknown = set(data) - known
        if unknown:
            raise ValueError(f"config に未知のキーがあります: {sorted(unknown)}")
        return cls(**data)

    def with_overrides(self, overrides: dict[str, Any]) -> "PipelineConfig":
        """プリセットの overrides を適用した新しい設定を返す。"""
        known = {f.name for f in fields(self)}
        unknown = set(overrides) - known
        if unknown:
            raise ValueError(f"overrides に未知のキーがあります: {sorted(unknown)}")
        return replace(self, **overrides)

    def validate(self) -> None:
        """明らかに不正な設定を早期に検出する。"""
        if self.pixel_size not in (1, 2, 3, 4):
            raise ValueError("pixel_size は 1/2/3/4 のいずれか")
        if self.palette_size not in (16, 32, 64, 128):
            raise ValueError("palette_size は 16/32/64/128 のいずれか")
        if not (0 < self.safe_area <= min(self.canvas_width, self.canvas_height)):
            raise ValueError("safe_area は canvas 以下の正の値")
        if not (0 < self.ground_y <= self.canvas_height):
            raise ValueError("ground_y は canvas_height 以下の正の値")
        if self.bg_mode not in ("global", "floodfill"):
            raise ValueError("bg_mode は global か floodfill")
        if not (0.0 <= self.min_component_ratio <= 1.0):
            raise ValueError("min_component_ratio は 0〜1")
        if not self.outline_color.startswith("#") or len(self.outline_color) != 7:
            raise ValueError("outline_color は #RRGGBB 形式")
