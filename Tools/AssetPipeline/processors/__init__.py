"""画像処理 Processor 群。

このパッケージ内のモジュールを自動で読み込む。新しい機能は
「processors/ に1ファイル追加して @register を付ける」だけで
プリセットから名前で呼び出せるようになる(ここへの追記は不要)。
"""

from __future__ import annotations

import importlib
import pkgutil

from processors.base import PROCESSORS, Processor, build_pipeline, register

# パッケージ内の全モジュールを import して @register を発火させる
for _mod in pkgutil.iter_modules(__path__):
    if _mod.name != "base":
        importlib.import_module(f"{__name__}.{_mod.name}")

__all__ = ["PROCESSORS", "Processor", "build_pipeline", "register"]
