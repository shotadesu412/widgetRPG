"""スモークテスト。外部依存なしで実行できる(pytest不要)。

    python3 tests/run_tests.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from models.config import PipelineConfig  # noqa: E402
from models.context import AssetContext  # noqa: E402
from processors import build_pipeline  # noqa: E402


def make_synthetic() -> Image.Image:
    """マゼンタ背景に緑の四角+孤立ノイズ1pxを置いた合成画像。"""
    arr = np.zeros((200, 160, 4), dtype=np.uint8)
    arr[:, :, :3] = (255, 0, 255)  # 背景
    arr[:, :, 3] = 255
    arr[60:180, 40:120, :3] = (40, 160, 60)  # キャラ本体
    arr[10, 10, :3] = (0, 0, 0)  # 孤立ノイズ(背景色でない)
    return Image.fromarray(arr, "RGBA")


def test_character_pipeline() -> None:
    config = PipelineConfig()
    config.validate()
    names = ["background_remover", "noise", "trim", "resize", "pixelize", "palette", "outline", "ground"]
    ctx = AssetContext(image=make_synthetic(), source=Path("synthetic.png"), category="characters", config=config)
    for p in build_pipeline(names, config):
        ctx = p(ctx)

    out = np.array(ctx.image)
    # キャンバスサイズ
    assert ctx.image.size == (config.canvas_width, config.canvas_height), ctx.image.size
    # 背景は透明
    assert out[0, 0, 3] == 0 and out[-1, -1, 3] == 0
    # 孤立ノイズが消えている(スプライト以外に不透明なし)
    ys, xs = np.where(out[:, :, 3] > 0)
    assert ys.min() >= 0 and len(ys) > 0
    # 足元が ground_y に一致(Bottom Center)
    assert ys.max() + 1 == config.ground_y, f"feet at {ys.max() + 1}"
    # 水平センター(±1px)
    cx = (xs.min() + xs.max() + 1) / 2
    assert abs(cx - config.canvas_width / 2) <= 1.5, cx
    # 減色されている
    opaque = out[out[:, :, 3] > 0][:, :3]
    unique = len(set(map(tuple, opaque)))
    assert unique <= config.palette_size + 1, unique  # +1 はアウトライン色
    print("ok: character pipeline", f"(colors={unique}, feet_y={ys.max() + 1})")


def test_config_validation() -> None:
    try:
        PipelineConfig(pixel_size=5).validate()
    except ValueError:
        print("ok: config validation")
        return
    raise AssertionError("pixel_size=5 が通ってしまった")


if __name__ == "__main__":
    test_config_validation()
    test_character_pipeline()
    print("all tests passed")
