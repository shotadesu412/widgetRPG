"""Processor 間で受け渡す処理コンテキスト。"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from PIL import Image

from models.config import PipelineConfig


@dataclass
class AssetContext:
    """1枚の画像に対する処理の状態。

    Processor は image を読み書きし、判断材料や結果を meta に記録する。
    meta は最終的にログとサイドカーJSON(デバッグ用)に出力できる。
    """

    image: Image.Image
    source: Path
    category: str
    config: PipelineConfig
    meta: dict[str, Any] = field(default_factory=dict)

    @property
    def stem(self) -> str:
        """出力ファイル名の基礎となる名前。"""
        return self.source.stem

    def note(self, processor: str, **info: Any) -> None:
        """Processor の実行記録を meta に残す。"""
        self.meta.setdefault(processor, {}).update(info)
