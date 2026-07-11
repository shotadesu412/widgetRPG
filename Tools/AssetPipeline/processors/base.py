"""Processor 基盤。

各 Processor は「AssetContext を受け取り AssetContext を返す」純粋な変換として
実装する。責務は1つに絞り、判断値はすべて PipelineConfig から取る。
"""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod

from models.config import PipelineConfig
from models.context import AssetContext

logger = logging.getLogger("pipeline")

#: name -> Processor クラス のレジストリ
PROCESSORS: dict[str, type["Processor"]] = {}


def register(cls: type["Processor"]) -> type["Processor"]:
    """Processor をレジストリに登録するデコレータ。"""
    if not cls.name or cls.name == "base":
        raise ValueError(f"{cls.__name__} に一意な name を定義してください")
    if cls.name in PROCESSORS:
        raise ValueError(f"Processor 名が重複しています: {cls.name}")
    PROCESSORS[cls.name] = cls
    return cls


class Processor(ABC):
    """すべての Processor の基底クラス。"""

    #: プリセットから参照する一意な名前
    name: str = "base"

    def __init__(self, config: PipelineConfig) -> None:
        self.config = config

    @abstractmethod
    def process(self, ctx: AssetContext) -> AssetContext:
        """画像を変換して返す。副作用は ctx.meta への記録のみ。"""

    def __call__(self, ctx: AssetContext) -> AssetContext:
        logger.debug("→ %s", self.name)
        return self.process(ctx)


def build_pipeline(names: list[str], config: PipelineConfig) -> list[Processor]:
    """プリセットの Processor 名リストからパイプラインを構築する。"""
    pipeline: list[Processor] = []
    for name in names:
        if name not in PROCESSORS:
            raise KeyError(
                f"未登録の Processor: {name}(登録済み: {sorted(PROCESSORS)})"
            )
        pipeline.append(PROCESSORS[name](config))
    return pipeline
