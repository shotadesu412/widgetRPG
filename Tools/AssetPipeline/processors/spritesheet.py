"""SpriteSheet Generator。

処理済みの同サイズ PNG 群を1枚のシートに並べ、フレーム座標の JSON を
同時生成する。CLI の `sheet` サブコマンドから使用する(パイプライン内
Processor としては使わないため process は未対応)。
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from models.context import AssetContext
from processors.base import Processor, register


@register
class SpriteSheet(Processor):
    """スプライトシート生成(CLI 専用)。"""

    name = "spritesheet"

    def process(self, ctx: AssetContext) -> AssetContext:
        raise NotImplementedError("spritesheet は CLI の `sheet` サブコマンドから使用してください。")


def generate_sheet(files: list[Path], out_png: Path, columns: int = 4) -> dict:
    """PNG 群からシートと JSON メタデータを生成する。

    すべて同サイズ(パイプライン出力のキャンバスサイズ)であることを前提とする。

    Returns:
        生成したメタデータ(JSON と同内容)。
    """
    if not files:
        raise ValueError("入力 PNG がありません")

    images = [Image.open(f).convert("RGBA") for f in files]
    cell_w, cell_h = images[0].size
    for f, im in zip(files, images):
        if im.size != (cell_w, cell_h):
            raise ValueError(f"サイズ不一致: {f.name} は {im.size}(期待 {cell_w}x{cell_h})")

    cols = min(columns, len(images))
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (0, 0, 0, 0))

    frames: dict[str, dict] = {}
    for i, (f, im) in enumerate(zip(files, images)):
        x, y = (i % cols) * cell_w, (i // cols) * cell_h
        sheet.paste(im, (x, y))
        frames[f.stem] = {"x": x, "y": y, "w": cell_w, "h": cell_h}

    out_png.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_png)
    meta = {
        "image": out_png.name,
        "cell": {"w": cell_w, "h": cell_h},
        "columns": cols,
        "frames": frames,
    }
    out_png.with_suffix(".json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return meta
